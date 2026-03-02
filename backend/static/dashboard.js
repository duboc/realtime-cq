// --- Polling with cursor-based incremental fetch ---
let cursor = null;
let initialLoadDone = false;
const MAX_POINTS = 100; // ~5 min at 3s intervals
const POLL_INTERVAL = 3000;

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
        el.textContent = 'Live';
        el.className = 'status connected';
    } else {
        el.textContent = 'Offline';
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
        x: {
            display: false,
        },
        y: {
            ticks: { color: '#555', font: { size: 10 } },
            grid: { color: '#1e1e1e' },
            border: { display: false },
        },
    },
    plugins: {
        legend: { display: false },
    },
    elements: {
        point: { radius: 0 },
        line: { borderWidth: 1.5 },
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
            backgroundColor: 'rgba(239,83,80,0.08)',
            fill: true,
            tension: 0.3,
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
            backgroundColor: 'rgba(102,187,106,0.08)',
            fill: true,
            tension: 0.3,
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
    ctx.strokeStyle = '#222';
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

    // Update label
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

const trackLine = L.polyline([], { color: '#4fc3f7', weight: 3 }).addTo(map);
let mapInitialized = false;

setTimeout(() => map.invalidateSize(), 200);

// --- Process incoming data ---
function processData(d, batch) {
    const label = d.et != null ? formatTime(d.et) : '';

    // Heart Rate
    if (d.hr != null) {
        pushPoint(hrChart, label, d.hr);
        if (!batch) hrChart.update('none');
        document.getElementById('hr-value').textContent = Math.round(d.hr);
    }

    // HRV
    if (d.hrv != null) {
        pushPoint(hrvChart, label, d.hrv);
        if (!batch) hrvChart.update('none');
        document.getElementById('hrv-value').textContent = d.hrv.toFixed(1);
    }

    // Fatigue
    if (d.fat != null) {
        drawFatigueGauge(d.fat);
    }

    // Speed (m/s -> km/h)
    if (d.spd != null) {
        document.getElementById('speed-value').textContent = (d.spd * 3.6).toFixed(1);
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
    if (d.et != null) {
        document.getElementById('stat-elapsed').textContent = formatTime(d.et);
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
