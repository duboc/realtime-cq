import React from 'react';

export default function WorkoutSummary({ totalReps, setCount, avgSetDuration, avgRestDuration, formConsistency }) {
  return (
    <div className="workout-summary">
      <div className="summary-item">
        <span className="summary-value">{setCount}</span>
        <span className="summary-label">Sets</span>
      </div>
      <div className="summary-divider" />
      <div className="summary-item">
        <span className="summary-value">{totalReps}</span>
        <span className="summary-label">Total Reps</span>
      </div>
      <div className="summary-divider" />
      <div className="summary-item">
        <span className="summary-value">{avgSetDuration > 0 ? `${Math.round(avgSetDuration)}s` : '--'}</span>
        <span className="summary-label">Avg Set</span>
      </div>
      <div className="summary-divider" />
      <div className="summary-item">
        <span className="summary-value">{avgRestDuration > 0 ? `${Math.round(avgRestDuration)}s` : '--'}</span>
        <span className="summary-label">Avg Rest</span>
      </div>
      <div className="summary-divider" />
      <div className="summary-item">
        <span className="summary-value" style={{ color: formConsistency >= 80 ? '#66bb6a' : formConsistency >= 50 ? '#ffa726' : '#ef5350' }}>
          {formConsistency > 0 ? `${Math.round(formConsistency)}%` : '--'}
        </span>
        <span className="summary-label">Form</span>
      </div>
    </div>
  );
}
