import React, { useState, useEffect } from 'react';

export default function SessionPicker({ currentSession, onSelect }) {
  const [sessions, setSessions] = useState([]);

  useEffect(() => {
    const fetchSessions = async () => {
      try {
        const res = await fetch('/api/sessions');
        if (res.ok) {
          const data = await res.json();
          const list = data.sessions || [];
          setSessions(list);
          // Auto-select first session if none selected
          if (!currentSession && list.length > 0) {
            onSelect(list[0].session_id);
          }
        }
      } catch { /* ignore */ }
    };

    fetchSessions();
    const interval = setInterval(fetchSessions, 5000);
    return () => clearInterval(interval);
  }, [currentSession, onSelect]);

  if (sessions.length <= 1) return null;

  return (
    <div className="session-picker">
      <select
        value={currentSession || ''}
        onChange={(e) => onSelect(e.target.value)}
      >
        {sessions.map((s) => (
          <option key={s.session_id} value={s.session_id}>
            {s.session_id} ({s.sets} sets, {s.fatigue}% fatigue)
          </option>
        ))}
      </select>
    </div>
  );
}
