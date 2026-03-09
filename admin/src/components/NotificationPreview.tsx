/**
 * Visual preview of a notification as it would appear to the user.
 */

import { Card, Typography } from "antd";
import { BellOutlined, MailOutlined } from "@ant-design/icons";

interface NotificationPreviewProps {
  title: string;
  body: string;
  type: "push" | "email" | "both";
}

export default function NotificationPreview({ title, body, type }: NotificationPreviewProps) {
  const showPush = type === "push" || type === "both";
  const showEmail = type === "email" || type === "both";

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {showPush && (
        <Card
          size="small"
          title={
            <span style={{ fontSize: 13, color: "#6D7F99" }}>
              <BellOutlined style={{ marginRight: 6 }} />
              Push Notification Preview
            </span>
          }
          style={{ borderRadius: 12, boxShadow: "0 2px 8px rgba(0,0,0,0.08)" }}
        >
          <div
            style={{
              background: "#F1F1F3",
              borderRadius: 10,
              padding: "12px 14px",
              display: "flex",
              gap: 10,
              alignItems: "flex-start",
            }}
          >
            <div
              style={{
                width: 36,
                height: 36,
                borderRadius: 8,
                background: "#15294A",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
              }}
            >
              <Typography.Text style={{ color: "#fff", fontSize: 14, fontWeight: 700 }}>
                MG
              </Typography.Text>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <Typography.Text strong style={{ fontSize: 13, display: "block" }}>
                {title || "Notification Title"}
              </Typography.Text>
              <Typography.Text
                type="secondary"
                style={{ fontSize: 12, display: "block", marginTop: 2 }}
                ellipsis
              >
                {body || "Notification body text will appear here..."}
              </Typography.Text>
              <Typography.Text type="secondary" style={{ fontSize: 11, marginTop: 4, display: "block" }}>
                now
              </Typography.Text>
            </div>
          </div>
        </Card>
      )}

      {showEmail && (
        <Card
          size="small"
          title={
            <span style={{ fontSize: 13, color: "#6D7F99" }}>
              <MailOutlined style={{ marginRight: 6 }} />
              Email Preview
            </span>
          }
          style={{ borderRadius: 12, boxShadow: "0 2px 8px rgba(0,0,0,0.08)" }}
        >
          <div style={{ border: "1px solid #F1F1F3", borderRadius: 8, overflow: "hidden" }}>
            <div
              style={{
                background: "#15294A",
                padding: "16px 20px",
                textAlign: "center",
              }}
            >
              <Typography.Text style={{ color: "#fff", fontSize: 16, fontWeight: 700 }}>
                Money Guardian
              </Typography.Text>
            </div>
            <div style={{ padding: "20px" }}>
              <Typography.Title level={5} style={{ marginTop: 0 }}>
                {title || "Email Subject"}
              </Typography.Title>
              <Typography.Paragraph
                type="secondary"
                style={{ whiteSpace: "pre-wrap", marginBottom: 0 }}
              >
                {body || "Email body content will appear here..."}
              </Typography.Paragraph>
            </div>
            <div
              style={{
                borderTop: "1px solid #F1F1F3",
                padding: "12px 20px",
                textAlign: "center",
              }}
            >
              <Typography.Text type="secondary" style={{ fontSize: 11 }}>
                Money Guardian - moneyguardian.co
              </Typography.Text>
            </div>
          </div>
        </Card>
      )}
    </div>
  );
}
