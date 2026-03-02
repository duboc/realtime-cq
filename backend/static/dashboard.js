// --- Polling with cursor-based incremental fetch ---
let cursor = null;
let initialLoadDone = false;
const MAX_POINTS = 100; // ~5 min at 3s intervals
const POLL_INTERVAL = 3000;

// --- HR Zone tracking ---
let lastDataTimestamp = null;
let zoneSeconds = [0, 0, 0, 0, 0]; // Z1..Z5
let currentZone = 0;
// Defaults — updated from first payload with mhr/rhr
let maxHR = 200;
let restHR = 60;
let zonesConfigured = false;

// --- Accelerometer history ---
const ACCEL_HISTORY = 60;
const accelHistory = { x: [], y: [], z: [] };

async function fetchData() {
    try {
        let url = '/api/history?limit=200';
        if (cursor) {
            url += '&after=' + encodeURIComponent(cursor);
        }

        const resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);

        const result = await resp.json();
        setConnectionStatus(true);

        if (result.cursor) {
            cursor = result.cursor;
        }

        if (result.data.length > 0) {
            const batch = !initialLoadDone;
            result.data.forEach((d) => processData(d, batch));
            if (batch) {
                hrChart.update('none');
                hrvChart.update('none');
            }
            initialLoadDone = true;
        }
    } catch (err) {
        setConnectionStatus(false);
    }
}

function startPolling() {
    fetchData();
    setInterval(fetchData, POLL_INTERVAL);
}

function setConnectionStatus(connected) {
    const el = document.getElementById('connection-status');
    if (connected) {
        el.innerHTML = '<span class="status-dot"></span> Live';
        el.className = 'status connected';
    } else {
        el.innerHTML = '<span class="status-dot"></span> Offline';
        el.className = 'status disconnected';
    }
}

// --- Chart.js setup ---
const chartDefaults = {
    responsive: true,
    maintainAspectRatio: false,
    animation: false,
    layout: { padding: 0 },
    scales: {
        x: { display: false },
        y: {
            ticks: { color: '#3e4859', font: { size: 10 } },
            grid: { color: '#1a1f2a' },
            border: { display: false },
        },
    },
    plugins: { legend: { display: false } },
    elements: {
        point: { radius: 0 },
        line: { borderWidth: 2 },
    },
};

// Heart Rate Chart
const hrCtx = document.getElementById('hr-chart').getContext('2d');
const hrChart = new Chart(hrCtx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [{
            data: [],
            borderColor: '#ef5350',
            backgroundColor: 'rgba(239,83,80,0.06)',
            fill: true,
            tension: 0.35,
        }],
    },
    options: {
        ...chartDefaults,
        scales: {
            ...chartDefaults.scales,
            y: {
                ...chartDefaults.scales.y,
                min: 40,
                max: 220,
                ticks: { ...chartDefaults.scales.y.ticks, stepSize: 40 },
            },
        },
    },
});

// HRV Chart
const hrvCtx = document.getElementById('hrv-chart').getContext('2d');
const hrvChart = new Chart(hrvCtx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [{
            data: [],
            borderColor: '#66bb6a',
            backgroundColor: 'rgba(102,187,106,0.06)',
            fill: true,
            tension: 0.35,
        }],
    },
    options: {
        ...chartDefaults,
        scales: {
            ...chartDefaults.scales,
            y: {
                ...chartDefaults.scales.y,
                min: 0,
            },
        },
    },
});

// --- Fatigue Gauge ---
function drawFatigueGauge(value) {
    const canvas = document.getElementById('fatigue-gauge');
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;
    const cx = w / 2;
    const cy = h - 6;
    const radius = Math.min(cx - 14, h - 20);

    ctx.clearRect(0, 0, w, h);

    // Background arc
    ctx.beginPath();
    ctx.arc(cx, cy, radius, Math.PI, 0);
    ctx.lineWidth = 16;
    ctx.strokeStyle = '#1a1f2a';
    ctx.stroke();

    // Value arc
    const pct = Math.min(Math.max(value, 0), 100) / 100;
    const endAngle = Math.PI + pct * Math.PI;

    let color;
    if (value < 25) color = '#66bb6a';
    else if (value < 50) color = '#fdd835';
    else if (value < 70) color = '#ffa726';
    else if (value < 85) color = '#ef5350';
    else color = '#e040fb';

    ctx.beginPath();
    ctx.arc(cx, cy, radius, Math.PI, endAngle);
    ctx.lineWidth = 16;
    ctx.lineCap = 'round';
    ctx.strokeStyle = color;
    ctx.stroke();

    const label = document.getElementById('fatigue-value');
    label.textContent = Math.round(value) + '%';
    label.style.color = color;
}

drawFatigueGauge(0);

// --- Leaflet Map ---
const map = L.map('map', { zoomControl: false, attributionControl: false }).setView([0, 0], 2);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
}).addTo(map);

const trackLine = L.polyline([], { color: '#4fc3f7', weight: 3, opacity: 0.8 }).addTo(map);
let mapInitialized = false;

setTimeout(() => map.invalidateSize(), 200);

// --- Accelerometer canvas ---
function drawAccelChart() {
    const canvas = document.getElementById('accel-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * (window.devicePixelRatio || 1);
    canvas.height = rect.height * (window.devicePixelRatio || 1);
    ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
    const w = rect.width;
    const h = rect.height;

    ctx.clearRect(0, 0, w, h);

    // Background
    ctx.fillStyle = '#1a1f2a';
    ctx.fillRect(0, 0, w, h);

    // Zero line
    const midY = h / 2;
    ctx.strokeStyle = '#2a3040';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, midY);
    ctx.lineTo(w, midY);
    ctx.stroke();

    const colors = { x: '#ef5350', y: '#66bb6a', z: '#42a5f5' };
    const maxVal = 2000; // milli-g range for scaling

    for (const axis of ['x', 'y', 'z']) {
        const data = accelHistory[axis];
        if (data.length < 2) continue;

        ctx.strokeStyle = colors[axis];
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < data.length; i++) {
            const px = (i / (ACCEL_HISTORY - 1)) * w;
            const py = midY - (data[i] / maxVal) * (midY * 0.9);
            if (i === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
        }
        ctx.stroke();
    }
}

function pushAccelData(ax, ay, az) {
    accelHistory.x.push(ax);
    accelHistory.y.push(ay);
    accelHistory.z.push(az);
    if (accelHistory.x.length > ACCEL_HISTORY) {
        accelHistory.x.shift();
        accelHistory.y.shift();
        accelHistory.z.shift();
    }
}

// --- HR Zone calculation (Karvonen method) ---
function getHRZone(hr) {
    const hrr = maxHR - restHR;
    const pct = (hr - restHR) / hrr;
    if (pct < 0.5) return 1;
    if (pct < 0.6) return 2;
    if (pct < 0.7) return 3;
    if (pct < 0.8) return 4;
    return 5;
}

function getZoneBounds(zone) {
    const hrr = maxHR - restHR;
    const thresholds = [0, 0.5, 0.6, 0.7, 0.8, 1.0];
    const lo = Math.round(restHR + thresholds[zone - 1] * hrr);
    const hi = Math.round(restHR + thresholds[zone] * hrr);
    return [lo, hi];
}

const zoneNames = ['', 'Zone 1 — Recovery', 'Zone 2 — Aerobic', 'Zone 3 — Tempo', 'Zone 4 — Threshold', 'Zone 5 — Max'];
const zoneColors = ['', '#2196f3', '#4caf50', '#ff9800', '#f44336', '#9c27b0'];

function updateZoneDisplay(hr) {
    const zone = getHRZone(hr);
    currentZone = zone;

    document.getElementById('zone-label').textContent = zoneNames[zone];
    document.getElementById('zone-label').style.color = zoneColors[zone];
    const bounds = getZoneBounds(zone);
    document.getElementById('zone-range').textContent = bounds[0] + '\u2013' + bounds[1] + ' bpm';

    document.querySelectorAll('.zone-row').forEach(row => {
        const z = parseInt(row.dataset.zone);
        row.classList.toggle('active', z === zone);
    });
}

function accumulateZoneTime(hr, elapsedMs) {
    if (lastDataTimestamp !== null && elapsedMs > lastDataTimestamp) {
        const deltaSec = (elapsedMs - lastDataTimestamp) / 1000;
        if (deltaSec > 0 && deltaSec < 30) {
            const zone = getHRZone(hr);
            zoneSeconds[zone - 1] += deltaSec;
            renderZoneBars();
        }
    }
    lastDataTimestamp = elapsedMs;
}

function renderZoneBars() {
    const maxSec = Math.max(...zoneSeconds, 1);
    for (let z = 1; z <= 5; z++) {
        const fill = document.querySelector('.z' + z + '-fill');
        const pct = (zoneSeconds[z - 1] / maxSec) * 100;
        fill.style.width = pct + '%';
        document.getElementById('zone-time-' + z).textContent = formatTime(zoneSeconds[z - 1] * 1000);
    }
}

// --- Value change animation ---
function flashValue(elementId) {
    const el = document.getElementById(elementId);
    if (!el) return;
    el.classList.remove('value-flash');
    void el.offsetWidth;
    el.classList.add('value-flash');
}

function glowCard(cardClass) {
    const el = document.querySelector('.' + cardClass);
    if (!el) return;
    el.classList.add('glow');
    setTimeout(() => el.classList.remove('glow'), 1500);
}

// --- Process incoming data ---
function processData(d, batch) {
    const label = d.et != null ? formatTime(d.et) : '';

    // Configure zones from first payload with mhr/rhr
    if (!zonesConfigured && d.mhr != null && d.rhr != null) {
        maxHR = d.mhr;
        restHR = d.rhr;
        zonesConfigured = true;
    }

    // Heart Rate
    if (d.hr != null) {
        pushPoint(hrChart, label, d.hr);
        if (!batch) hrChart.update('none');
        document.getElementById('hr-value').textContent = Math.round(d.hr);
        updateZoneDisplay(d.hr);
        if (d.et != null) accumulateZoneTime(d.hr, d.et);
        if (!batch) {
            flashValue('hr-value');
            glowCard('card-hr');
        }
    }

    // HRV
    if (d.hrv != null) {
        pushPoint(hrvChart, label, d.hrv);
        if (!batch) hrvChart.update('none');
        document.getElementById('hrv-value').textContent = d.hrv.toFixed(1);
        if (!batch) {
            flashValue('hrv-value');
            glowCard('card-hrv');
        }
    }

    // Fatigue
    if (d.fat != null) {
        drawFatigueGauge(d.fat);
        if (!batch) glowCard('card-fatigue');
    }

    // Speed — sensor (m/s -> km/h)
    if (d.spd != null) {
        document.getElementById('speed-value').textContent = (d.spd * 3.6).toFixed(1);
        if (!batch) {
            flashValue('speed-value');
            glowCard('card-speed');
        }
    }

    // GPS Speed (m/s -> km/h)
    if (d.gspd != null) {
        document.getElementById('gps-speed-value').textContent = (d.gspd * 3.6).toFixed(1);
    }

    // Accelerometer
    if (d.ax != null && d.ay != null && d.az != null) {
        pushAccelData(d.ax, d.ay, d.az);
        drawAccelChart();
        document.getElementById('accel-x').textContent = Math.round(d.ax);
        document.getElementById('accel-y').textContent = Math.round(d.ay);
        document.getElementById('accel-z').textContent = Math.round(d.az);
        const mag = Math.sqrt(d.ax * d.ax + d.ay * d.ay + d.az * d.az);
        document.getElementById('accel-mag').textContent = Math.round(mag);
        if (!batch) glowCard('card-accel');
    }

    // GPS
    if (d.lat != null && d.lon != null && d.lat !== 0 && d.lon !== 0) {
        const latlng = [d.lat, d.lon];
        trackLine.addLatLng(latlng);
        if (!mapInitialized) {
            map.setView(latlng, 16);
            mapInitialized = true;
        } else if (!batch) {
            map.panTo(latlng);
        }
    }

    // Stats
    if (d.dist != null) {
        document.getElementById('stat-distance').textContent = (d.dist / 1000).toFixed(2);
    }
    if (d.cal != null) {
        document.getElementById('stat-calories').textContent = Math.round(d.cal);
    }
    if (d.cad != null) {
        document.getElementById('stat-cadence').textContent = Math.round(d.cad);
    }
    if (d.alt != null) {
        document.getElementById('stat-altitude').textContent = Math.round(d.alt);
    }
    if (d.hri != null) {
        document.getElementById('stat-hri').textContent = d.hri > 0 ? Math.round(d.hri) : '--';
    }
    if (d.mhr != null) {
        document.getElementById('stat-mhr').textContent = Math.round(d.mhr);
    }
    if (d.rhr != null) {
        document.getElementById('stat-rhr').textContent = Math.round(d.rhr);
    }
    if (d.ts != null) {
        document.getElementById('stat-ts').textContent = Math.round(d.ts);
    }

    // Elapsed time in header
    if (d.et != null) {
        document.getElementById('elapsed-time').textContent = formatTime(d.et) + ' ET';
    }
}

function pushPoint(chart, label, value) {
    chart.data.labels.push(label);
    chart.data.datasets[0].data.push(value);
    if (chart.data.labels.length > MAX_POINTS) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
}

function formatTime(ms) {
    const totalSec = Math.floor(ms / 1000);
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    return m + ':' + s.toString().padStart(2, '0');
}

// --- Start ---
startPolling();
