import React from 'react';
import { formatTime } from '../utils/formatters';

const phaseColors = {
  WARMUP: { bg: 'rgba(33, 150, 243, 0.15)', color: '#2196f3' },
  WORKING: { bg: 'rgba(102, 187, 106, 0.15)', color: '#66bb6a' },
  FATIGUED: { bg: 'rgba(239, 83, 80, 0.15)', color: '#ef5350' },
};

export default function SessionHeader({ connected, elapsedMs, setCount, workoutPhase }) {
  const phase = phaseColors[workoutPhase] || phaseColors.WARMUP;

  return (
    <header className="session-header">
      <h1>GymPulse</h1>
      <div className="header-right">
        {workoutPhase && (
          <span className="phase-badge" style={{ background: phase.bg, color: phase.color }}>
            {workoutPhase}
          </span>
        )}
        <span className="set-count">{setCount} sets</span>
        <div className={`status ${connected ? 'connected' : 'disconnected'}`}>
          <span className="status-dot" />
          {connected ? 'Live' : 'Offline'}
        </div>
        <div className="elapsed">{formatTime(elapsedMs)}</div>
      </div>
    </header>
  );
}
