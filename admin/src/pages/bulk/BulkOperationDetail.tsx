/**
 * Bulk Operation detail page with real-time progress polling.
 */

import {
  Card,
  Typography,
  Tag,
  Button,
  Descriptions,
  Space,
  Spin,
  message,
} from "antd";
import { StopOutlined, DownloadOutlined, ArrowLeftOutlined } from "@ant-design/icons";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchBulkOperation, cancelBulkOperation } from "@/lib/api";
import ProgressBar from "@/components/ProgressBar";
import dayjs from "dayjs";

const STATUS_COLORS: Record<string, string> = {
  pending: "default",
  running: "blue",
  completed: "green",
  failed: "red",
  cancelled: "orange",
};

export default function BulkOperationDetailPage() {
  const { operationId } = useParams<{ operationId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["bulk-operation", operationId],
    queryFn: () => fetchBulkOperation(operationId!),
    enabled: !!operationId,
    refetchInterval: (query) => {
      const op = query.state.data;
      if (op && (op.status === "running" || op.status === "pending")) {
        return 3000;
      }
      return false;
    },
  });

  const cancelMutation = useMutation({
    mutationFn: () => cancelBulkOperation(operationId!),
    onSuccess: () => {
      message.success("Operation cancelled");
      void queryClient.invalidateQueries({ queryKey: ["bulk-operation", operationId] });
    },
    onError: () => {
      message.error("Failed to cancel operation");
    },
  });

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  if (!data) {
    return <Typography.Text type="danger">Operation not found</Typography.Text>;
  }

  const isActive = data.status === "pending" || data.status === "running";

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate("/bulk-operations")}
        >
          Back
        </Button>
      </Space>

      <Typography.Title level={4} style={{ marginBottom: 24 }}>
        Bulk Operation Detail
      </Typography.Title>

      <Card style={{ marginBottom: 16 }}>
        <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
          <Descriptions.Item label="ID">
            <Typography.Text copyable>{data.id}</Typography.Text>
          </Descriptions.Item>
          <Descriptions.Item label="Type">
            <Typography.Text code>{data.operation_type}</Typography.Text>
          </Descriptions.Item>
          <Descriptions.Item label="Status">
            <Tag color={STATUS_COLORS[data.status] || "default"}>
              {data.status.toUpperCase()}
            </Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Target Count">{data.target_count}</Descriptions.Item>
          <Descriptions.Item label="Processed">{data.processed_count}</Descriptions.Item>
          <Descriptions.Item label="Failed">
            {data.failed_count > 0 ? (
              <Typography.Text type="danger">{data.failed_count}</Typography.Text>
            ) : (
              0
            )}
          </Descriptions.Item>
          <Descriptions.Item label="Created">
            {dayjs(data.created_at).format("MMM D, YYYY HH:mm:ss")}
          </Descriptions.Item>
          <Descriptions.Item label="Started">
            {data.started_at ? dayjs(data.started_at).format("MMM D, YYYY HH:mm:ss") : "—"}
          </Descriptions.Item>
          <Descriptions.Item label="Completed" span={2}>
            {data.completed_at ? dayjs(data.completed_at).format("MMM D, YYYY HH:mm:ss") : "—"}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      <Card title="Progress" style={{ marginBottom: 16 }}>
        <ProgressBar
          processed={data.processed_count}
          failed={data.failed_count}
          total={data.target_count}
        />
      </Card>

      {data.error_message && (
        <Card
          title="Error"
          style={{ marginBottom: 16, borderColor: "#EF4444" }}
          headStyle={{ color: "#EF4444" }}
        >
          <Typography.Text type="danger">{data.error_message}</Typography.Text>
        </Card>
      )}

      <Card title="Parameters" style={{ marginBottom: 16 }}>
        <pre
          style={{
            background: "#f5f5f5",
            padding: 16,
            borderRadius: 6,
            overflow: "auto",
            maxHeight: 300,
            fontSize: 13,
            margin: 0,
          }}
        >
          {JSON.stringify(data.parameters, null, 2)}
        </pre>
      </Card>

      <Space>
        {isActive && (
          <Button
            danger
            icon={<StopOutlined />}
            loading={cancelMutation.isPending}
            onClick={() => cancelMutation.mutate()}
          >
            Cancel Operation
          </Button>
        )}
        {data.result_url && (
          <Button
            icon={<DownloadOutlined />}
            href={data.result_url}
            target="_blank"
          >
            Download Results
          </Button>
        )}
      </Space>
    </>
  );
}
