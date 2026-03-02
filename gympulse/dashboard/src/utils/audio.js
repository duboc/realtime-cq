const AudioCtx = window.AudioContext || window.webkitAudioContext;
let ctx = null;

function getCtx() {
  if (!ctx) {
    try { ctx = new AudioCtx(); } catch { return null; }
  }
  return ctx;
}

function playTone(freq, duration, type = 'sine') {
  const c = getCtx();
  if (!c) return;
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0.15, c.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, c.currentTime + duration);
  osc.connect(gain);
  gain.connect(c.destination);
  osc.start();
  osc.stop(c.currentTime + duration);
}

let lastRecoveryAlert = 0;

export function playRecoveryReady() {
  const now = Date.now();
  if (now - lastRecoveryAlert < 10000) return; // throttle 10s
  lastRecoveryAlert = now;
  playTone(880, 0.15);
  setTimeout(() => playTone(1100, 0.2), 180);
}

let lastOvertrainingAlert = 0;

export function playOvertraining() {
  const now = Date.now();
  if (now - lastOvertrainingAlert < 30000) return; // throttle 30s
  lastOvertrainingAlert = now;
  playTone(220, 0.3, 'sawtooth');
  setTimeout(() => playTone(180, 0.4, 'sawtooth'), 350);
}
