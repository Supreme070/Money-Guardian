/**
 * Webhook event detail page.
 */

import {
  Card,
  Descriptions,
  Spin,
  Tag,
  Typography,
  Button,
  Space,
  Alert,
} from "antd";
import { ArrowLeftOutlined } from "@ant-design/icons";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchWebhookDetail } from "@/lib/api";
import dayjs from "dayjs";

const PROVIDER_COLORS: Record<string, string> = {
  stripe: "purple",
  plaid: "green",
  ses: "blue",
  gmail: "red",
  outlook: "geekblue",
};

const STATUS_COLORS: Record<string, string> = {
  received: "default",
  processed: "green",
  failed: "red",
  ignored: "orange",
};

export default function WebhookDetailPage() {
  const { webhookId } = useParams<{ webhookId: string }>();
  const navigate = useNavigate();

  const { data: event, isLoading } = useQuery({
    queryKey: ["webhook-detail", webhookId],
    queryFn: () => fetchWebhookDetail(webhookId!),
    enabled: !!webhookId,
  });

  if (isLoading || !event) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate("/webhooks")}>
          Back
        </Button>
      </Space>

      {event.status === "failed" && event.error_message && (
        <Alert
          type="error"
          message="Processing Failed"
          description={event.error_message}
          showIcon
          style={{ marginBottom: 16 }}
        />
      )}

      <Card
        title={
          <Space>
            <Typography.Text strong>Webhook Event</Typography.Text>
            <Tag color={STATUS_COLORS[event.status]}>{event.status.toUpperCase()}</Tag>
          </Space>
        }
      >
        <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
          <Descriptions.Item label="Provider">
            <Tag color={PROVIDER_COLORS[event.provider] ?? "default"}>
              {event.provider}
            </Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Event Type">{event.event_type}</Descriptions.Item>
          <Descriptions.Item label="Event ID" span={2}>
            <Typography.Text copyable style={{ fontSize: 12 }}>
              {event.event_id}
            </Typography.Text>
          </Descriptions.Item>
          <Descriptions.Item label="Status">
            <Tag color={STATUS_COLORS[event.status]}>{event.status}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Processing Time">
            {event.processing_time_ms !== null ? `${event.processing_time_ms}ms` : "N/A"}
          </Descriptions.Item>
          {event.payload_hash && (
            <Descriptions.Item label="Payload Hash" span={2}>
              <Typography.Text code style={{ fontSize: 11 }}>
                {event.payload_hash}
              </Typography.Text>
            </Descriptions.Item>
          )}
          <Descriptions.Item label="Received At" span={2}>
            {dayjs(event.created_at).format("MMM D, YYYY h:mm:ss A")}
          </Descriptions.Item>
          {event.error_message && (
            <Descriptions.Item label="Error" span={2}>
              <Typography.Text type="danger">{event.error_message}</Typography.Text>
            </Descriptions.Item>
          )}
        </Descriptions>
      </Card>
    </>
  );
}
