/**
 * Server-Sent Events hook for real-time dashboard updates.
 */

import { useEffect, useRef, useState, useCallback } from "react";
import type { SSEDashboardEvent } from "./types";

const MAX_EVENTS = 50;
const RECONNECT_DELAY_MS = 5000;

interface UseSSEResult {
  events: SSEDashboardEvent[];
  connected: boolean;
  error: string | null;
}

export function useSSE(endpoint: string): UseSSEResult {
  const [events, setEvents] = useState<SSEDashboardEvent[]>([]);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const sourceRef = useRef<EventSource | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const getToken = useCallback((): string | null => {
    try {
      const raw = sessionStorage.getItem("mg_admin_tokens");
      if (raw) {
        const parsed: { accessToken?: string } = JSON.parse(raw);
        return parsed.accessToken ?? null;
      }
    } catch {
      // ignore
    }
    return null;
  }, []);

  useEffect(() => {
    let disposed = false;

    function connect() {
      if (disposed) return;

      const token = getToken();
      if (!token) {
        setError("Not authenticated");
        return;
      }

      const baseUrl = import.meta.env.VITE_API_BASE_URL || "";
      const separator = endpoint.includes("?") ? "&" : "?";
      const url = `${baseUrl}${endpoint}${separator}token=${encodeURIComponent(token)}`;

      const source = new EventSource(url);
      sourceRef.current = source;

      source.onopen = () => {
        if (disposed) return;
        setConnected(true);
        setError(null);
      };

      source.onmessage = (event: MessageEvent) => {
        if (disposed) return;
        try {
          const parsed = JSON.parse(event.data as string) as SSEDashboardEvent;
          setEvents((prev) => {
            const next = [...prev, parsed];
            return next.length > MAX_EVENTS ? next.slice(-MAX_EVENTS) : next;
          });
        } catch {
          // Ignore malformed events
        }
      };

      source.onerror = () => {
        if (disposed) return;
        setConnected(false);
        setError("Connection lost. Reconnecting...");
        source.close();
        sourceRef.current = null;

        reconnectTimer.current = setTimeout(() => {
          connect();
        }, RECONNECT_DELAY_MS);
      };
    }

    connect();

    return () => {
      disposed = true;
      if (sourceRef.current) {
        sourceRef.current.close();
        sourceRef.current = null;
      }
      if (reconnectTimer.current) {
        clearTimeout(reconnectTimer.current);
        reconnectTimer.current = null;
      }
    };
  }, [endpoint, getToken]);

  return { events, connected, error };
}
