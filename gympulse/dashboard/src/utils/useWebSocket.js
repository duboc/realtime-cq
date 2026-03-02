import { useState, useEffect, useRef, useCallback } from 'react';

const INITIAL_RETRY_MS = 1000;
const MAX_RETRY_MS = 30000;
const POLL_INTERVAL_MS = 3000;

export function useWebSocket(sessionId, onMessage) {
  const [connected, setConnected] = useState(false);
  const wsRef = useRef(null);
  const retryMs = useRef(INITIAL_RETRY_MS);
  const pollRef = useRef(null);

  const connect = useCallback(() => {
    if (!sessionId) return;

    const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const url = `${proto}//${window.location.host}/ws/session/${sessionId}`;

    try {
      const ws = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        setConnected(true);
        retryMs.current = INITIAL_RETRY_MS;
        // Stop polling fallback if active
        if (pollRef.current) {
          clearInterval(pollRef.current);
          pollRef.current = null;
        }
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          onMessage(data);
        } catch { /* ignore parse errors */ }
      };

      ws.onclose = () => {
        setConnected(false);
        // Reconnect with exponential backoff
        const delay = retryMs.current;
        retryMs.current = Math.min(retryMs.current * 2, MAX_RETRY_MS);
        setTimeout(connect, delay);
        // Start polling fallback
        startPolling();
      };

      ws.onerror = () => {
        ws.close();
      };
    } catch {
      // WebSocket not available, use polling
      startPolling();
    }
  }, [sessionId, onMessage]);

  const startPolling = useCallback(() => {
    if (pollRef.current || !sessionId) return;

    pollRef.current = setInterval(async () => {
      try {
        const res = await fetch(`/api/session/${sessionId}/live`);
        if (res.ok) {
          const data = await res.json();
          if (data && data.hr) {
            setConnected(true);
            onMessage(data);
          }
        }
      } catch {
        setConnected(false);
      }
    }, POLL_INTERVAL_MS);
  }, [sessionId, onMessage]);

  useEffect(() => {
    connect();

    return () => {
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      if (pollRef.current) {
        clearInterval(pollRef.current);
        pollRef.current = null;
      }
    };
  }, [connect]);

  return { connected };
}
