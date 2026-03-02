export function formatTime(ms) {
  const totalSec = Math.floor(ms / 1000);
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function getHRZone(hr, maxHR = 190, restHR = 60) {
  const hrr = maxHR - restHR;
  if (hrr <= 0) return 1;
  const pct = (hr - restHR) / hrr;
  if (pct < 0.5) return 1;
  if (pct < 0.6) return 2;
  if (pct < 0.7) return 3;
  if (pct < 0.8) return 4;
  return 5;
}

export function getZoneColor(zone) {
  const colors = {
    1: '#2196f3',
    2: '#4caf50',
    3: '#ff9800',
    4: '#f44336',
    5: '#9c27b0',
  };
  return colors[zone] || '#5a6478';
}

export function getFatigueColor(score) {
  if (score < 25) return '#66bb6a';
  if (score < 50) return '#fdd835';
  if (score < 70) return '#ffa726';
  if (score < 85) return '#ef5350';
  return '#e040fb';
}

export function getFatigueLabel(zone) {
  const labels = {
    FRESH: 'Fresh',
    MODERATE: 'Moderate',
    TIRED: 'Tired',
    EXHAUSTED: 'Exhausted',
    CRITICAL: 'Critical',
  };
  return labels[zone] || zone;
}

export function getRecoveryColor(pct) {
  if (pct >= 85) return '#66bb6a';
  if (pct >= 60) return '#ffa726';
  return '#ef5350';
}
