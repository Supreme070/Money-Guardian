import { Card, Typography, Table, Tag, Badge } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchCeleryStatus } from "@/lib/api";
import { useSSE } from "@/lib/sse";

export default function CeleryTasksPage() {
  const { data } = useQuery({
    queryKey: ["celery-status"],
    queryFn: fetchCeleryStatus,
  });

  const { events, connected } = useSSE("/api/v1/admin/sse/monitoring");

  // Extract worker/queue info from SSE events if available
  const latestMonitoring = events.length > 0 ? events[events.length - 1] : null;
  const workerCount = latestMonitoring?.data?.worker_count as number | undefined;
  const queueSize = latestMonitoring?.data?.queue_size as number | undefined;

  return (
    <>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
        <Typography.Title level={4} style={{ margin: 0 }}>Celery Scheduled Tasks</Typography.Title>
        <Badge
          status={connected ? "success" : "default"}
          text={connected ? "Live" : "Polling"}
          style={{ fontSize: 13 }}
        />
      </div>

      {connected && (workerCount !== undefined || queueSize !== undefined) && (
        <div style={{ display: "flex", gap: 16, marginBottom: 16 }}>
          {workerCount !== undefined && (
            <Card size="small">
              <Typography.Text type="secondary" style={{ display: "block", fontSize: 12 }}>
                Active Workers
              </Typography.Text>
              <Typography.Text strong style={{ fontSize: 24, color: "#375EFD" }}>
                {workerCount}
              </Typography.Text>
            </Card>
          )}
          {queueSize !== undefined && (
            <Card size="small">
              <Typography.Text type="secondary" style={{ display: "block", fontSize: 12 }}>
                Queue Size
              </Typography.Text>
              <Typography.Text strong style={{ fontSize: 24, color: queueSize > 100 ? "#EF4444" : "#22C55E" }}>
                {queueSize}
              </Typography.Text>
            </Card>
          )}
        </div>
      )}

      <Card>
        <Table
          dataSource={data?.scheduled_tasks}
          rowKey="name"
          size="small"
          pagination={false}
          columns={[
            {
              title: "Task Name",
              dataIndex: "name",
              render: (name: string) => (
                <Typography.Text code>{name}</Typography.Text>
              ),
            },
            {
              title: "Schedule",
              dataIndex: "schedule",
              width: 150,
              render: (s: string) => <Tag color="blue">{s}</Tag>,
            },
            {
              title: "Description",
              dataIndex: "description",
              ellipsis: true,
            },
          ]}
        />
      </Card>
    </>
  );
}
