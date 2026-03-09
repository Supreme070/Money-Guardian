/**
 * Notification history page — paginated table of all sent notifications.
 */

import { useState } from "react";
import { Typography, Table, Tag, Modal, Progress, Card } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchNotifications, fetchNotificationDetail } from "@/lib/api";
import type { AdminNotification } from "@/lib/types";

const STATUS_COLORS: Record<string, string> = {
  pending: "default",
  sending: "blue",
  sent: "green",
  failed: "red",
};

const TYPE_COLORS: Record<string, string> = {
  push: "cyan",
  email: "gold",
  both: "purple",
};

const TARGET_LABELS: Record<string, string> = {
  user: "Specific Users",
  tier: "By Tier",
  all: "All Users",
};

export default function NotificationHistoryPage() {
  const [page, setPage] = useState(1);
  const [detailId, setDetailId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["notifications", page],
    queryFn: () => fetchNotifications({ page, page_size: 25 }),
    staleTime: 10_000,
  });

  const { data: detail, isLoading: detailLoading } = useQuery({
    queryKey: ["notification-detail", detailId],
    queryFn: () => fetchNotificationDetail(detailId!),
    enabled: !!detailId,
  });

  const columns = [
    {
      title: "Time",
      dataIndex: "created_at",
      key: "created_at",
      width: 170,
      render: (v: string) => new Date(v).toLocaleString(),
    },
    {
      title: "Type",
      dataIndex: "notification_type",
      key: "notification_type",
      width: 80,
      render: (v: string) => (
        <Tag color={TYPE_COLORS[v] || "default"}>{v}</Tag>
      ),
    },
    {
      title: "Target",
      key: "target",
      width: 150,
      render: (_: unknown, record: AdminNotification) => {
        let label = TARGET_LABELS[record.target_type] || record.target_type;
        if (record.target_type === "tier" && record.target_tier) {
          label += ` (${record.target_tier})`;
        }
        if (record.target_type === "user" && record.target_ids) {
          label += ` (${record.target_ids.length})`;
        }
        return label;
      },
    },
    {
      title: "Title",
      dataIndex: "title",
      key: "title",
      ellipsis: true,
    },
    {
      title: "Delivered",
      key: "delivery",
      width: 140,
      render: (_: unknown, record: AdminNotification) => {
        const total = record.sent_count + record.failed_count;
        if (total === 0) return "—";
        const percent = Math.round((record.sent_count / total) * 100);
        return (
          <div>
            <Progress
              percent={percent}
              size="small"
              strokeColor="#22C55E"
              trailColor="#EF4444"
              format={() => `${record.sent_count}/${total}`}
            />
          </div>
        );
      },
    },
    {
      title: "Status",
      dataIndex: "status",
      key: "status",
      width: 100,
      render: (v: string) => (
        <Tag color={STATUS_COLORS[v] || "default"}>{v.toUpperCase()}</Tag>
      ),
    },
  ];

  return (
    <div>
      <Typography.Title level={3}>Notification History</Typography.Title>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={data?.notifications}
        loading={isLoading}
        pagination={{
          current: page,
          pageSize: 25,
          total: data?.total_count || 0,
          onChange: setPage,
          showSizeChanger: false,
        }}
        onRow={(record) => ({
          onClick: () => setDetailId(record.id),
          style: { cursor: "pointer" },
        })}
        scroll={{ x: 900 }}
      />

      <Modal
        title={detail?.title || "Notification Detail"}
        open={!!detailId}
        onCancel={() => setDetailId(null)}
        footer={null}
        loading={detailLoading}
      >
        {detail && (
          <div>
            <Typography.Paragraph>
              <Typography.Text strong>Type: </Typography.Text>
              <Tag color={TYPE_COLORS[detail.notification_type] || "default"}>
                {detail.notification_type}
              </Tag>
            </Typography.Paragraph>
            <Typography.Paragraph>
              <Typography.Text strong>Target: </Typography.Text>
              {TARGET_LABELS[detail.target_type] || detail.target_type}
              {detail.target_tier ? ` (${detail.target_tier})` : ""}
            </Typography.Paragraph>
            {detail.target_ids && detail.target_ids.length > 0 && (
              <Typography.Paragraph>
                <Typography.Text strong>User IDs: </Typography.Text>
                <Typography.Text code style={{ fontSize: 11, wordBreak: "break-all" }}>
                  {detail.target_ids.join(", ")}
                </Typography.Text>
              </Typography.Paragraph>
            )}
            <Typography.Paragraph>
              <Typography.Text strong>Status: </Typography.Text>
              <Tag color={STATUS_COLORS[detail.status] || "default"}>
                {detail.status.toUpperCase()}
              </Tag>
            </Typography.Paragraph>
            <Typography.Paragraph>
              <Typography.Text strong>Sent: </Typography.Text>
              {detail.sent_count} &nbsp;
              <Typography.Text strong>Failed: </Typography.Text>
              {detail.failed_count}
            </Typography.Paragraph>
            <Typography.Paragraph>
              <Typography.Text strong>Sent at: </Typography.Text>
              {new Date(detail.created_at).toLocaleString()}
            </Typography.Paragraph>
            <Card
              size="small"
              style={{
                background: "#F1F1F3",
                marginTop: 12,
              }}
            >
              <Typography.Title level={5} style={{ marginTop: 0 }}>
                {detail.title}
              </Typography.Title>
              <Typography.Paragraph style={{ whiteSpace: "pre-wrap", marginBottom: 0 }}>
                {detail.body}
              </Typography.Paragraph>
            </Card>
          </div>
        )}
      </Modal>
    </div>
  );
}
