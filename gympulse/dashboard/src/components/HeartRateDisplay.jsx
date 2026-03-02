import React from 'react';
import { getHRZone, getZoneColor } from '../utils/formatters';

export default function HeartRateDisplay({ hr, avgHR, maxHR, mhr, rhr }) {
  const zone = getHRZone(hr, mhr, rhr);
  const color = getZoneColor(zone);

  return (
    <>
      <div className="card-title">Heart Rate</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
        <span className="hero-value" style={{ color }}>
          {hr > 0 ? Math.round(hr) : '--'}
        </span>
        <span className="hero-unit">bpm</span>
      </div>

      {/* 5-segment zone bar */}
      <div className="zone-bar">
        {[1, 2, 3, 4, 5].map((z) => (
          <div
            key={z}
            className={`segment seg-${z} ${z <= zone ? 'active' : ''}`}
          />
        ))}
      </div>

      <div className="hr-stats">
        <div className="hr-stat">
          <span className="hr-stat-label">Avg</span>
          <span className="hr-stat-value">{avgHR > 0 ? Math.round(avgHR) : '--'}</span>
        </div>
        <div className="hr-stat">
          <span className="hr-stat-label">Max</span>
          <span className="hr-stat-value">{maxHR > 0 ? Math.round(maxHR) : '--'}</span>
        </div>
        <div className="hr-stat">
          <span className="hr-stat-label">Zone</span>
          <span className="hr-stat-value" style={{ color }}>Z{zone}</span>
        </div>
      </div>
    </>
  );
}
