/**
 * Bulk Operations list page with create modals.
 */

import { useState } from "react";
import {
  Table,
  Typography,
  Tag,
  Button,
  Space,
  Dropdown,
  Modal,
  Form,
  Input,
  Select,
  Progress,
  message,
} from "antd";
import {
  ThunderboltOutlined,
  StopOutlined,
  PlusOutlined,
} from "@ant-design/icons";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import {
  fetchBulkOperations,
  cancelBulkOperation,
  createBulkUserStatus,
  createBulkTierOverride,
  createBulkNotification,
} from "@/lib/api";
import type { BulkOperation } from "@/lib/types";
import dayjs from "dayjs";

const STATUS_COLORS: Record<string, string> = {
  pending: "default",
  running: "blue",
  completed: "green",
  failed: "red",
  cancelled: "orange",
};

export default function BulkOperationsPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);

  // Modal state
  const [statusModalOpen, setStatusModalOpen] = useState(false);
  const [tierModalOpen, setTierModalOpen] = useState(false);
  const [notifyModalOpen, setNotifyModalOpen] = useState(false);
  const [statusForm] = Form.useForm();
  const [tierForm] = Form.useForm();
  const [notifyForm] = Form.useForm();

  const { data, isLoading } = useQuery({
    queryKey: ["bulk-operations", page, pageSize],
    queryFn: () => fetchBulkOperations({ page, page_size: pageSize }),
    refetchInterval: 10000,
  });

  const cancelMutation = useMutation({
    mutationFn: cancelBulkOperation,
    onSuccess: () => {
      message.success("Operation cancelled");
      void queryClient.invalidateQueries({ queryKey: ["bulk-operations"] });
    },
    onError: () => {
      message.error("Failed to cancel operation");
    },
  });

  const handleCreateStatus = async () => {
    try {
      const values = await statusForm.validateFields();
      const userIds = (values.user_ids as string)
        .split(",")
        .map((s: string) => s.trim())
        .filter(Boolean);
      await createBulkUserStatus({
        user_ids: userIds,
        new_status: values.new_status as string,
        reason: values.reason as string,
      });
      message.success("Bulk user status operation created");
      setStatusModalOpen(false);
      statusForm.resetFields();
      void queryClient.invalidateQueries({ queryKey: ["bulk-operations"] });
    } catch {
      message.error("Failed to create operation");
    }
  };

  const handleCreateTier = async () => {
    try {
      const values = await tierForm.validateFields();
      const tenantIds = (values.tenant_ids as string)
        .split(",")
        .map((s: string) => s.trim())
        .filter(Boolean);
      await createBulkTierOverride({
        tenant_ids: tenantIds,
        new_tier: values.new_tier as string,
        reason: values.reason as string,
      });
      message.success("Bulk tier override operation created");
      setTierModalOpen(false);
      tierForm.resetFields();
      void queryClient.invalidateQueries({ queryKey: ["bulk-operations"] });
    } catch {
      message.error("Failed to create operation");
    }
  };

  const handleCreateNotify = async () => {
    try {
      const values = await notifyForm.validateFields();
      const userIds = (values.user_ids as string)
        .split(",")
        .map((s: string) => s.trim())
        .filter(Boolean);
      await createBulkNotification({
        user_ids: userIds,
        notification_type: values.notification_type as string,
        title: values.title as string,
        body: values.body as string,
      });
      message.success("Bulk notification operation created");
      setNotifyModalOpen(false);
      notifyForm.resetFields();
      void queryClient.invalidateQueries({ queryKey: ["bulk-operations"] });
    } catch {
      message.error("Failed to create operation");
    }
  };

  const columns = [
    {
      title: "Type",
      dataIndex: "operation_type",
      width: 160,
      render: (type: string) => (
        <Typography.Text code>{type}</Typography.Text>
      ),
    },
    {
      title: "Target",
      dataIndex: "target_count",
      width: 80,
      align: "center" as const,
    },
    {
      title: "Progress",
      key: "progress",
      width: 200,
      render: (_: unknown, record: BulkOperation) => {
        const pct = record.target_count
          ? Math.round((record.processed_count / record.target_count) * 100)
          : 0;
        return (
          <Progress
            percent={pct}
            size="small"
            status={
              record.status === "failed"
                ? "exception"
                : record.status === "completed"
                  ? "success"
                  : "active"
            }
            format={() =>
              `${record.processed_count}/${record.target_count}`
            }
          />
        );
      },
    },
    {
      title: "Failed",
      dataIndex: "failed_count",
      width: 70,
      align: "center" as const,
      render: (v: number) =>
        v > 0 ? (
          <Typography.Text type="danger">{v}</Typography.Text>
        ) : (
          <Typography.Text type="secondary">0</Typography.Text>
        ),
    },
    {
      title: "Status",
      dataIndex: "status",
      width: 100,
      render: (status: string) => (
        <Tag color={STATUS_COLORS[status] || "default"}>{status}</Tag>
      ),
    },
    {
      title: "Started",
      dataIndex: "started_at",
      width: 140,
      render: (v: string | null) =>
        v ? dayjs(v).format("MMM D, HH:mm") : "—",
    },
    {
      title: "Completed",
      dataIndex: "completed_at",
      width: 140,
      render: (v: string | null) =>
        v ? dayjs(v).format("MMM D, HH:mm") : "—",
    },
    {
      title: "Actions",
      key: "actions",
      width: 120,
      render: (_: unknown, record: BulkOperation) => (
        <Space>
          <Button
            type="link"
            size="small"
            onClick={() => navigate(`/bulk-operations/${record.id}`)}
          >
            Details
          </Button>
          {(record.status === "pending" || record.status === "running") && (
            <Button
              type="link"
              size="small"
              danger
              icon={<StopOutlined />}
              onClick={() => cancelMutation.mutate(record.id)}
            >
              Cancel
            </Button>
          )}
        </Space>
      ),
    },
  ];

  const menuItems = [
    { key: "user-status", label: "Bulk User Status" },
    { key: "tier-override", label: "Bulk Tier Override" },
    { key: "notification", label: "Bulk Notification" },
  ];

  const handleMenuClick = ({ key }: { key: string }) => {
    switch (key) {
      case "user-status":
        setStatusModalOpen(true);
        break;
      case "tier-override":
        setTierModalOpen(true);
        break;
      case "notification":
        setNotifyModalOpen(true);
        break;
    }
  };

  return (
    <>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
        <Typography.Title level={4} style={{ margin: 0 }}>
          <ThunderboltOutlined style={{ marginRight: 8, color: "#375EFD" }} />
          Bulk Operations
        </Typography.Title>
        <Dropdown menu={{ items: menuItems, onClick: handleMenuClick }}>
          <Button type="primary" icon={<PlusOutlined />}>
            New Operation
          </Button>
        </Dropdown>
      </div>

      <Table
        dataSource={data?.operations}
        columns={columns}
        rowKey="id"
        loading={isLoading}
        pagination={{
          current: page,
          pageSize,
          total: data?.total_count,
          showSizeChanger: true,
          showTotal: (total) => `${total} operations`,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
      />

      {/* Bulk User Status Modal */}
      <Modal
        title="Bulk User Status Change"
        open={statusModalOpen}
        onOk={handleCreateStatus}
        onCancel={() => setStatusModalOpen(false)}
      >
        <Form form={statusForm} layout="vertical">
          <Form.Item
            name="user_ids"
            label="User IDs (comma-separated)"
            rules={[{ required: true }]}
          >
            <Input.TextArea rows={3} placeholder="uuid1, uuid2, uuid3" />
          </Form.Item>
          <Form.Item name="new_status" label="New Status" rules={[{ required: true }]}>
            <Select
              options={[
                { value: "active", label: "Active" },
                { value: "inactive", label: "Inactive" },
              ]}
            />
          </Form.Item>
          <Form.Item name="reason" label="Reason" rules={[{ required: true }]}>
            <Input.TextArea rows={2} />
          </Form.Item>
        </Form>
      </Modal>

      {/* Bulk Tier Override Modal */}
      <Modal
        title="Bulk Tier Override"
        open={tierModalOpen}
        onOk={handleCreateTier}
        onCancel={() => setTierModalOpen(false)}
      >
        <Form form={tierForm} layout="vertical">
          <Form.Item
            name="tenant_ids"
            label="Tenant IDs (comma-separated)"
            rules={[{ required: true }]}
          >
            <Input.TextArea rows={3} placeholder="uuid1, uuid2, uuid3" />
          </Form.Item>
          <Form.Item name="new_tier" label="New Tier" rules={[{ required: true }]}>
            <Select
              options={[
                { value: "free", label: "Free" },
                { value: "pro", label: "Pro" },
                { value: "enterprise", label: "Enterprise" },
              ]}
            />
          </Form.Item>
          <Form.Item name="reason" label="Reason" rules={[{ required: true }]}>
            <Input.TextArea rows={2} />
          </Form.Item>
        </Form>
      </Modal>

      {/* Bulk Notification Modal */}
      <Modal
        title="Bulk Notification"
        open={notifyModalOpen}
        onOk={handleCreateNotify}
        onCancel={() => setNotifyModalOpen(false)}
      >
        <Form form={notifyForm} layout="vertical">
          <Form.Item
            name="user_ids"
            label="User IDs (comma-separated)"
            rules={[{ required: true }]}
          >
            <Input.TextArea rows={3} placeholder="uuid1, uuid2, uuid3" />
          </Form.Item>
          <Form.Item name="notification_type" label="Type" rules={[{ required: true }]}>
            <Select
              options={[
                { value: "push", label: "Push" },
                { value: "email", label: "Email" },
                { value: "both", label: "Both" },
              ]}
            />
          </Form.Item>
          <Form.Item name="title" label="Title" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="body" label="Body" rules={[{ required: true }]}>
            <Input.TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>
    </>
  );
}
