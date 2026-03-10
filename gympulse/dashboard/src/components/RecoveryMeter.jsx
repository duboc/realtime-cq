import React, { useEffect, useRef } from 'react';
import { getRecoveryColor } from '../utils/formatters';
import { playRecoveryReady } from '../utils/audio';

export default function RecoveryMeter({ pct, status, restTimer, state }) {
  const prevPct = useRef(0);

  useEffect(() => {
    if (prevPct.current < 85 && pct >= 85) {
      playRecoveryReady();
    }
    prevPct.current = pct;
  }, [pct]);

  const color = getRecoveryColor(pct);
  const radius = 70;
  const circumference = 2 * Math.PI * radius;
  const progress = Math.min(pct, 100) / 100;
  const offset = circumference * (1 - progress);

  const statusClass = status === 'GO' ? 'go' : status === 'ALMOST' ? 'almost' : 'not-ready';
  const isResting = state === 'RESTING' && restTimer > 0;

  return (
    <>
      <div className="card-title">Recovery Readiness</div>
      <div className="recovery-container">
        <svg className="recovery-svg" viewBox="0 0 180 180">
          {/* Background circle */}
          <circle
            cx="90" cy="90" r={radius}
            fill="none"
            stroke="#1a1f2a"
            strokeWidth="10"
          />
          {/* Progress circle */}
          <circle
            cx="90" cy="90" r={radius}
            fill="none"
            stroke={color}
            strokeWidth="10"
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            transform="rotate(-90 90 90)"
            style={{ transition: 'stroke-dashoffset 0.6s ease, stroke 0.3s ease' }}
          />
          {/* Center text */}
          {isResting ? (
            <>
              <text
                x="90" y="78" textAnchor="middle"
                fill={color}
                style={{ fontSize: '2rem', fontWeight: 700, fontFamily: 'JetBrains Mono, monospace' }}
              >
                {Math.round(pct)}%
              </text>
              <text
                x="90" y="108" textAnchor="middle"
                fill="#8892a4"
                style={{ fontSize: '1.1rem', fontWeight: 600, fontFamily: 'JetBrains Mono, monospace' }}
              >
                {Math.round(restTimer)}s
              </text>
            </>
          ) : (
            <>
              <text
                x="90" y="85" textAnchor="middle"
                fill={color}
                style={{ fontSize: '2rem', fontWeight: 700, fontFamily: 'JetBrains Mono, monospace' }}
              >
                {Math.round(pct)}%
              </text>
              <text
                x="90" y="110" textAnchor="middle"
                fill="#5a6478"
                style={{ fontSize: '0.7rem', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '1px' }}
              >
                readiness
              </text>
            </>
          )}
        </svg>
        <div className={`recovery-status ${statusClass}`}>
          {status === 'GO' ? 'GO' : status === 'ALMOST' ? 'Almost Ready' : 'Not Ready'}
        </div>
      </div>
    </>
  );
}
