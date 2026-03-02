import React from 'react';
import { getFatigueColor, getFatigueLabel } from '../utils/formatters';

export default function FatigueGauge({ score, zone, recommendation }) {
  const color = getFatigueColor(score);
  const pct = Math.min(Math.max(score, 0), 100) / 100;

  // SVG semi-circle gauge
  const cx = 110, cy = 115;
  const radius = 90;
  const startAngle = Math.PI;
  const endAngle = startAngle + pct * Math.PI;

  // Arc path
  const startX = cx + radius * Math.cos(startAngle);
  const startY = cy + radius * Math.sin(startAngle);
  const endX = cx + radius * Math.cos(endAngle);
  const endY = cy + radius * Math.sin(endAngle);
  const largeArc = pct > 0.5 ? 1 : 0;

  const bgEndX = cx + radius * Math.cos(0);
  const bgEndY = cy + radius * Math.sin(0);

  return (
    <>
      <div className="card-title">Fatigue</div>
      <div className="fatigue-container">
        <svg className="fatigue-svg" viewBox="0 0 220 130">
          {/* Background arc */}
          <path
            d={`M ${startX} ${startY} A ${radius} ${radius} 0 1 1 ${bgEndX} ${bgEndY}`}
            fill="none"
            stroke="#1a1f2a"
            strokeWidth="14"
            strokeLinecap="round"
          />
          {/* Value arc */}
          {pct > 0.01 && (
            <path
              d={`M ${startX} ${startY} A ${radius} ${radius} 0 ${largeArc} 1 ${endX} ${endY}`}
              fill="none"
              stroke={color}
              strokeWidth="14"
              strokeLinecap="round"
              style={{ transition: 'stroke 0.3s ease' }}
            />
          )}
        </svg>
        <div className="fatigue-value" style={{ color }}>
          {Math.round(score)}%
        </div>
        <div className="fatigue-zone" style={{ color }}>
          {getFatigueLabel(zone)}
        </div>
        {recommendation && (
          <div className="fatigue-recommendation">{recommendation}</div>
        )}
      </div>
    </>
  );
}
