import React, { useRef, useEffect } from 'react';
import { getRecoveryColor } from '../utils/formatters';

export default function SetLog({ sets }) {
  const listRef = useRef(null);

  useEffect(() => {
    if (listRef.current) {
      listRef.current.scrollTop = listRef.current.scrollHeight;
    }
  }, [sets.length]);

  return (
    <>
      <div className="card-title">Set Log</div>
      <div className="setlog-container">
        <div className="setlog-list" ref={listRef}>
          {sets.length === 0 && (
            <div style={{ color: '#5a6478', fontSize: '0.8rem', textAlign: 'center', marginTop: 20 }}>
              No sets recorded yet
            </div>
          )}
          {sets.map((s, i) => {
            const recPct = s.recovery_after ?? 0;
            const recColor = getRecoveryColor(recPct);
            return (
              <div key={i} className="set-row">
                <span className="set-number">#{s.set_number}</span>
                <span className="set-reps">{s.rep_count} reps</span>
                <span className="set-hr">{Math.round(s.peak_hr)} bpm</span>
                <div className="recovery-mini-bar">
                  <div
                    className="recovery-mini-fill"
                    style={{
                      width: `${Math.min(recPct, 100)}%`,
                      background: recColor,
                    }}
                  />
                </div>
                <span className="recovery-mini-pct">{Math.round(recPct)}%</span>
              </div>
            );
          })}
        </div>
      </div>
    </>
  );
}
