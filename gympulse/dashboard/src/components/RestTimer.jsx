import React from 'react';

export default function RestTimer({ state, restTimer, recoveryETA, rec }) {
  if (state === 'ACTIVE_SET') {
    return (
      <>
        <div className="card-title">Rest Timer</div>
        <div className="rest-timer-container">
          <div className="rest-timer-active">Set in progress...</div>
        </div>
      </>
    );
  }

  if (state !== 'RESTING' || restTimer <= 0) {
    return (
      <>
        <div className="card-title">Rest Timer</div>
        <div className="rest-timer-container">
          <div className="rest-timer-idle">Waiting for rest</div>
        </div>
      </>
    );
  }

  const etaText = recoveryETA > 0 ? `~${Math.round(recoveryETA)}s to GO` : 'Ready!';
  const etaColor = rec >= 85 ? '#66bb6a' : rec >= 60 ? '#ffa726' : '#ef5350';

  return (
    <>
      <div className="card-title">Rest Timer</div>
      <div className="rest-timer-container">
        <div className="rest-timer-value">{Math.round(restTimer)}s</div>
        <div className="rest-timer-eta" style={{ color: etaColor }}>{etaText}</div>
      </div>
    </>
  );
}
