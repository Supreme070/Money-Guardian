/**
 * Real-time activity feed card showing SSE events.
 */

import { useEffect, useRef } from "react";
import { Card, Typography, Badge, Empty } from "antd";
import {
  UserAddOutlined,
  LoginOutlined,
  CreditCardOutlined,
  BankOutlined,
  MailOutlined,
  WarningOutlined,
  CheckCircleOutlined,
} from "@ant-design/icons";
import type { SSEDashboardEvent } from "@/lib/types";
import dayjs from "dayjs";

const EVENT_ICONS: Record<string, React.ReactNode> = {
  signup: <UserAddOutlined style={{ color: "#375EFD" }} />,
  login: <LoginOutlined style={{ color: "#22C55E" }} />,
  subscription: <CreditCardOutlined style={{ color: "#FBBD5C" }} />,
  bank_connection: <BankOutlined style={{ color: "#15294A" }} />,
  email_connection: <MailOutlined style={{ color: "#375EFD" }} />,
  alert: <WarningOutlined style={{ color: "#EF4444" }} />,
  payment: <CheckCircleOutlined style={{ color: "#22C55E" }} />,
};

function getEventIcon(type: string): React.ReactNode {
  return EVENT_ICONS[type] ?? <CheckCircleOutlined style={{ color: "#6D7F99" }} />;
}

function getEventDescription(event: SSEDashboardEvent): string {
  const d = event.data;
  switch (event.type) {
    case "signup":
      return `New user signed up: ${String(d.email ?? "unknown")}`;
    case "login":
      return `User logged in: ${String(d.email ?? "unknown")}`;
    case "subscription":
      return `Subscription ${String(d.action ?? "updated")}: ${String(d.name ?? "")}`;
    case "bank_connection":
      return `Bank connected: ${String(d.institution ?? "unknown")}`;
    case "email_connection":
      return `Email connected: ${String(d.email ?? "unknown")}`;
    case "alert":
      return `Alert: ${String(d.title ?? d.message ?? "New alert")}`;
    case "payment":
      return `Payment: ${String(d.description ?? "processed")}`;
    default:
      return `${event.type}: ${JSON.stringify(d)}`;
  }
}

interface LiveActivityFeedProps {
  events: SSEDashboardEvent[];
  connected: boolean;
}

export default function LiveActivityFeed({ events, connected }: LiveActivityFeedProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const displayEvents = events.slice(-20);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [displayEvents.length]);

  return (
    <Card
      title={
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span>Live Activity</span>
          <Badge status={connected ? "success" : "error"} text={connected ? "Connected" : "Disconnected"} />
        </div>
      }
      bodyStyle={{ padding: 0 }}
      style={{ height: "100%" }}
    >
      <div
        ref={scrollRef}
        style={{
          maxHeight: 400,
          overflowY: "auto",
          padding: "8px 16px",
        }}
      >
        {displayEvents.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="No events yet"
            style={{ margin: "24px 0" }}
          />
        ) : (
          displayEvents.map((event, i) => (
            <div
              key={`${event.timestamp}-${i}`}
              style={{
                display: "flex",
                alignItems: "flex-start",
                gap: 10,
                padding: "8px 0",
                borderBottom: i < displayEvents.length - 1 ? "1px solid #f0f0f0" : undefined,
              }}
            >
              <div style={{ fontSize: 16, marginTop: 2 }}>{getEventIcon(event.type)}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <Typography.Text ellipsis style={{ display: "block", fontSize: 13 }}>
                  {getEventDescription(event)}
                </Typography.Text>
                <Typography.Text type="secondary" style={{ fontSize: 11 }}>
                  {dayjs(event.timestamp).format("HH:mm:ss")}
                </Typography.Text>
              </div>
            </div>
          ))
        )}
      </div>
    </Card>
  );
}
