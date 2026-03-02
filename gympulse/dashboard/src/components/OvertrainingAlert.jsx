import React, { useEffect } from 'react';
import { playOvertraining } from '../utils/audio';

export default function OvertrainingAlert({ score }) {
  useEffect(() => {
    playOvertraining();
  }, []);

  return (
    <div className="overtraining-overlay">
      <div className="overtraining-content">
        <div className="overtraining-title">OVERTRAINING RISK</div>
        <div className="overtraining-score">{Math.round(score)}%</div>
        <div className="overtraining-msg">
          Stop workout immediately. Risk of injury and overtraining.
        </div>
      </div>
    </div>
  );
}
