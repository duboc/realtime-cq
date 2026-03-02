import React, { useState, useEffect, useCallback } from 'react';
import { useWebSocket } from './utils/useWebSocket';
import SessionHeader from './components/SessionHeader';
import HeartRateDisplay from './components/HeartRateDisplay';
import RecoveryMeter from './components/RecoveryMeter';
import FatigueGauge from './components/FatigueGauge';
import SetLog from './components/SetLog';
import HRTimeline from './components/HRTimeline';
import OvertrainingAlert from './components/OvertrainingAlert';
import SessionPicker from './components/SessionPicker';

export default function App() {
  const [sessionId, setSessionId] = useState(null);
  const [history, setHistory] = useState([]);
  const [sets, setSets] = useState([]);
  const [latest, setLatest] = useState(null);

  const onMessage = useCallback((data) => {
    setLatest(data);
    setHistory((prev) => {
      const next = [...prev, data];
      return next.length > 200 ? next.slice(-200) : next;
    });
  }, []);

  const { connected } = useWebSocket(sessionId, onMessage);

  // Fetch sets periodically
  useEffect(() => {
    if (!sessionId) return;
    const fetchSets = async () => {
      try {
        const res = await fetch(`/api/session/${sessionId}/sets`);
        if (res.ok) {
          const data = await res.json();
          setSets(data.sets || []);
        }
      } catch { /* ignore */ }
    };
    fetchSets();
    const interval = setInterval(fetchSets, 5000);
    return () => clearInterval(interval);
  }, [sessionId]);

  // Reset history on session change
  useEffect(() => {
    setHistory([]);
    setSets([]);
    setLatest(null);
  }, [sessionId]);

  const fat = latest?.fat ?? 0;
  const showOvertraining = fat > 90;

  return (
    <div className="app">
      <SessionHeader
        connected={connected}
        elapsedMs={latest?.et ?? 0}
        setCount={latest?.sets ?? 0}
      />

      <main className="grid">
        <div className="grid-area area-hr">
          <HeartRateDisplay
            hr={latest?.hr ?? 0}
            avgHR={latest?.avgHR ?? 0}
            maxHR={latest?.maxHR ?? 0}
            mhr={latest?.mhr ?? 190}
            rhr={latest?.rhr ?? 60}
          />
        </div>

        <div className="grid-area area-recovery">
          <RecoveryMeter
            pct={latest?.rec ?? 0}
            status={latest?.rs ?? 'GO'}
          />
        </div>

        <div className="grid-area area-fatigue">
          <FatigueGauge
            score={fat}
            zone={latest?.fz ?? 'FRESH'}
            recommendation={latest?.recommendation ?? ''}
          />
        </div>

        <div className="grid-area area-setlog">
          <SetLog sets={sets} />
        </div>

        <div className="grid-area area-timeline">
          <HRTimeline history={history} sets={sets} />
        </div>
      </main>

      <SessionPicker
        currentSession={sessionId}
        onSelect={setSessionId}
      />

      {showOvertraining && <OvertrainingAlert score={fat} />}
    </div>
  );
}
