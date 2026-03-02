import React from 'react';
import { formatTime } from '../utils/formatters';

export default function SessionHeader({ connected, elapsedMs, setCount }) {
  return (
    <header className="session-header">
      <h1>GymPulse</h1>
      <div className="header-right">
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
