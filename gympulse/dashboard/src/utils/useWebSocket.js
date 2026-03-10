import { useState, useEffect, useRef, useCallback } from 'react';

const POLL_INTERVAL_MS = 2000;

export function useWebSocket(sessionId, onMessage) {
  const [connected, setConnected] = useState(false);
  const pollRef = useRef(null);

  const startPolling = useCallback(() => {
    if (!sessionId) return;

    // Clear any existing interval
    if (pollRef.current) {
      clearInterval(pollRef.current);
    }

    const poll = async () => {
      try {
        const res = await fetch(`/api/session/${sessionId}/live`);
        if (res.ok) {
          const data = await res.json();
          if (data && data.hr) {
            setConnected(true);
            onMessage(data);
          }
        } else {
          setConnected(false);
        }
      } catch {
        setConnected(false);
      }
    };

    // Immediate first poll
    poll();
    pollRef.current = setInterval(poll, POLL_INTERVAL_MS);
  }, [sessionId, onMessage]);

  useEffect(() => {
    startPolling();

    return () => {
      if (pollRef.current) {
        clearInterval(pollRef.current);
        pollRef.current = null;
      }
    };
  }, [startPolling]);

  return { connected };
}
