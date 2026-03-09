/**
 * Sticky banner displayed when an admin is impersonating a user.
 * Reads from sessionStorage and shows a countdown timer.
 */

import { useState, useEffect, useCallback } from "react";
import { Button, Typography } from "antd";
import { UserSwitchOutlined, CloseCircleOutlined } from "@ant-design/icons";

const STORAGE_KEY = "mg_impersonation";

interface ImpersonationData {
  access_token: string;
  user_email: string;
  user_name: string;
  expires_at: number; // epoch ms
}

function getImpersonation(): ImpersonationData | null {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as ImpersonationData;
    if (Date.now() >= parsed.expires_at) {
      sessionStorage.removeItem(STORAGE_KEY);
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function setImpersonation(data: {
  access_token: string;
  user_email: string;
  user_name: string;
  expires_in: number;
}): void {
  const impersonation: ImpersonationData = {
    access_token: data.access_token,
    user_email: data.user_email,
    user_name: data.user_name,
    expires_at: Date.now() + data.expires_in * 1000,
  };
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(impersonation));
  // Dispatch storage event so banner picks it up
  window.dispatchEvent(new Event("impersonation-change"));
}

export function clearImpersonation(): void {
  sessionStorage.removeItem(STORAGE_KEY);
  window.dispatchEvent(new Event("impersonation-change"));
}

function formatCountdown(ms: number): string {
  if (ms <= 0) return "0:00";
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

export default function ImpersonationBanner() {
  const [impersonation, setImpState] = useState<ImpersonationData | null>(getImpersonation);
  const [remaining, setRemaining] = useState(0);

  const refresh = useCallback(() => {
    const data = getImpersonation();
    setImpState(data);
    if (data) {
      setRemaining(data.expires_at - Date.now());
    }
  }, []);

  useEffect(() => {
    refresh();
    window.addEventListener("impersonation-change", refresh);
    return () => window.removeEventListener("impersonation-change", refresh);
  }, [refresh]);

  useEffect(() => {
    if (!impersonation) return;
    const interval = setInterval(() => {
      const ms = impersonation.expires_at - Date.now();
      if (ms <= 0) {
        clearImpersonation();
        setImpState(null);
      } else {
        setRemaining(ms);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [impersonation]);

  if (!impersonation) return null;

  return (
    <div
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        right: 0,
        zIndex: 1000,
        background: "rgba(239, 68, 68, 0.10)",
        borderBottom: "2px solid #EF4444",
        padding: "8px 24px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 16,
      }}
    >
      <UserSwitchOutlined style={{ color: "#EF4444", fontSize: 16 }} />
      <Typography.Text strong style={{ color: "#EF4444" }}>
        Impersonating: {impersonation.user_email}
        {impersonation.user_name ? ` (${impersonation.user_name})` : ""}
      </Typography.Text>
      <Typography.Text type="secondary" style={{ fontSize: 13 }}>
        Expires in: {formatCountdown(remaining)}
      </Typography.Text>
      <Button
        size="small"
        danger
        icon={<CloseCircleOutlined />}
        onClick={() => {
          clearImpersonation();
          setImpState(null);
        }}
      >
        End Session
      </Button>
    </div>
  );
}
