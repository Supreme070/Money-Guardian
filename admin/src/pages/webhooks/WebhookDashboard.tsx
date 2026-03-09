/**
 * Webhook dashboard — stats overview and event log.
 */

import { useState } from "react";
import {
  Typography,
  Table,
  Tag,
  Card,
  Row,
  Col,
  Statistic,
  Select,
  Space,
  Button,
  Tooltip,
} from "antd";
import {
  EyeOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  ClockCircleOutlined,
} from "@ant-design/icons";
import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchWebhookEvents, fetchWebhookStats } from "@/lib/api";
import type { WebhookEvent } from "@/lib/types";
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

const STATUS_ICONS: Record<string, React.ReactNode> = {
  received: <ClockCircleOutlined />,
  processed: <CheckCircleOutlined />,
  failed: <CloseCircleOutlined />,
  ignored: <ClockCircleOutlined />,
};

export default function WebhookDashboardPage() {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const [providerFilter, setProviderFilter] = useState<string | undefined>();
  const [statusFilter, setStatusFilter] = useState<string | undefined>();

  const { data: stats } = useQuery({
    queryKey: ["webhook-stats"],
    queryFn: fetchWebhookStats,
    staleTime: 30_000,
  });

  const { data: events, isLoading } = useQuery({
    queryKey: ["webhook-events", page, providerFilter, statusFilter],
    queryFn: () =>
      fetchWebhookEvents({
        provider: providerFilter,
        status: statusFilter,
        page,
        page_size: 20,
      }),
    staleTime: 10_000,
  });

  const successRate =
    stats && stats.total_events > 0
      ? (((stats.by_status["processed"] ?? 0) / stats.total_events) * 100).toFixed(1)
      : "0";

  const providerEntries = Object.entries(stats?.by_provider ?? {});

  const columns = [
    {
      title: "Time",
      dataIndex: "created_at",
      key: "created_at",
      width: 160,
      render: (v: string) => dayjs(v).format("MMM D, h:mm:ss A"),
    },
    {
      title: "Provider",
      dataIndex: "provider",
      key: "provider",
      width: 100,
      render: (v: string) => (
        <Tag color={PROVIDER_COLORS[v] ?? "default"}>{v}</Tag>
      ),
    },
    {
      title: "Event Type",
      dataIndex: "event_type",
      key: "event_type",
      width: 200,
      ellipsis: true,
    },
    {
      title: "Event ID",
      dataIndex: "event_id",
      key: "event_id",
      width: 160,
      render: (v: string) => (
        <Tooltip title={v}>
          <Typography.Text code style={{ fontSize: 11 }}>
            {v.length > 20 ? `${v.slice(0, 20)}...` : v}
          </Typography.Text>
        </Tooltip>
      ),
    },
    {
      title: "Status",
      dataIndex: "status",
      key: "status",
      width: 110,
      render: (status: WebhookEvent["status"]) => (
        <Tag color={STATUS_COLORS[status]} icon={STATUS_ICONS[status]}>
          {status}
        </Tag>
      ),
    },
    {
      title: "Time (ms)",
      dataIndex: "processing_time_ms",
      key: "processing_time_ms",
      width: 100,
      render: (v: number | null) => (v !== null ? `${v}ms` : "-"),
    },
    {
      title: "Actions",
      key: "actions",
      width: 80,
      render: (_: unknown, record: WebhookEvent) => (
        <Button
          size="small"
          icon={<EyeOutlined />}
          onClick={() => navigate(`/webhooks/${record.id}`)}
        />
      ),
    },
  ];

  return (
    <div>
      <Typography.Title level={3}>Webhook Dashboard</Typography.Title>

      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Total Events"
              value={stats?.total_events ?? 0}
              valueStyle={{ color: "#15294A" }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Success Rate"
              value={successRate}
              suffix="%"
              valueStyle={{ color: "#22C55E" }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Avg Processing Time"
              value={stats?.avg_processing_time_ms ?? 0}
              suffix="ms"
              precision={0}
              valueStyle={{ color: "#375EFD" }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Typography.Text type="secondary" style={{ display: "block", marginBottom: 8 }}>
              By Provider
            </Typography.Text>
            {providerEntries.length > 0 ? (
              <Space wrap>
                {providerEntries.map(([provider, count]) => (
                  <Tag key={provider} color={PROVIDER_COLORS[provider] ?? "default"}>
                    {provider}: {count}
                  </Tag>
                ))}
              </Space>
            ) : (
              <Typography.Text type="secondary">No data</Typography.Text>
            )}
          </Card>
        </Col>
      </Row>

      <Card style={{ marginBottom: 16 }}>
        <Space wrap>
          <Select
            placeholder="Provider"
            allowClear
            onChange={(v) => {
              setProviderFilter(v);
              setPage(1);
            }}
            style={{ width: 140 }}
            options={[
              { value: "stripe", label: "Stripe" },
              { value: "plaid", label: "Plaid" },
              { value: "ses", label: "SES" },
              { value: "gmail", label: "Gmail" },
              { value: "outlook", label: "Outlook" },
            ]}
          />
          <Select
            placeholder="Status"
            allowClear
            onChange={(v) => {
              setStatusFilter(v);
              setPage(1);
            }}
            style={{ width: 140 }}
            options={[
              { value: "received", label: "Received" },
              { value: "processed", label: "Processed" },
              { value: "failed", label: "Failed" },
              { value: "ignored", label: "Ignored" },
            ]}
          />
        </Space>
      </Card>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={events?.events}
        loading={isLoading}
        pagination={{
          current: page,
          pageSize: 20,
          total: events?.total_count ?? 0,
          onChange: setPage,
          showSizeChanger: false,
        }}
        scroll={{ x: 1000 }}
      />
    </div>
  );
}
