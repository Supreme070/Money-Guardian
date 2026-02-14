import { Card, Typography, Table, Tag } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchCeleryStatus } from "@/lib/api";

export default function CeleryTasksPage() {
  const { data } = useQuery({
    queryKey: ["celery-status"],
    queryFn: fetchCeleryStatus,
  });

  return (
    <>
      <Typography.Title level={4}>Celery Scheduled Tasks</Typography.Title>

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
