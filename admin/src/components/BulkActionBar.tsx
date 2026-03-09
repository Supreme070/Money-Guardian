/**
 * Floating action bar shown when table rows are selected.
 * Provides bulk operations like status change and notifications.
 */

import { useState } from "react";
import { Button, Space, Modal, Form, Input, Select, message, Typography } from "antd";
import { CloseOutlined } from "@ant-design/icons";
import { createBulkUserStatus, createBulkTierOverride, createBulkNotification } from "@/lib/api";

interface BulkActionBarProps {
  selectedIds: string[];
  entityType: "user" | "tenant";
  onClear: () => void;
  onOperationCreated?: () => void;
}

export default function BulkActionBar({
  selectedIds,
  entityType,
  onClear,
  onOperationCreated,
}: BulkActionBarProps) {
  const [statusModalOpen, setStatusModalOpen] = useState(false);
  const [notifyModalOpen, setNotifyModalOpen] = useState(false);
  const [tierModalOpen, setTierModalOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [statusForm] = Form.useForm();
  const [notifyForm] = Form.useForm();
  const [tierForm] = Form.useForm();

  if (selectedIds.length === 0) return null;

  const handleStatusChange = async () => {
    try {
      const values = await statusForm.validateFields();
      setLoading(true);
      if (entityType === "user") {
        await createBulkUserStatus({
          user_ids: selectedIds,
          new_status: values.new_status as string,
          reason: values.reason as string,
        });
      }
      message.success("Bulk status change started");
      setStatusModalOpen(false);
      statusForm.resetFields();
      onClear();
      onOperationCreated?.();
    } catch {
      message.error("Failed to start bulk operation");
    } finally {
      setLoading(false);
    }
  };

  const handleTierOverride = async () => {
    try {
      const values = await tierForm.validateFields();
      setLoading(true);
      await createBulkTierOverride({
        tenant_ids: selectedIds,
        new_tier: values.new_tier as string,
        reason: values.reason as string,
      });
      message.success("Bulk tier override started");
      setTierModalOpen(false);
      tierForm.resetFields();
      onClear();
      onOperationCreated?.();
    } catch {
      message.error("Failed to start bulk operation");
    } finally {
      setLoading(false);
    }
  };

  const handleNotification = async () => {
    try {
      const values = await notifyForm.validateFields();
      setLoading(true);
      await createBulkNotification({
        user_ids: selectedIds,
        notification_type: values.notification_type as string,
        title: values.title as string,
        body: values.body as string,
      });
      message.success("Bulk notification started");
      setNotifyModalOpen(false);
      notifyForm.resetFields();
      onClear();
      onOperationCreated?.();
    } catch {
      message.error("Failed to start bulk operation");
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <div
        style={{
          position: "fixed",
          bottom: 24,
          left: "50%",
          transform: "translateX(-50%)",
          background: "#15294A",
          color: "#fff",
          borderRadius: 8,
          padding: "12px 24px",
          display: "flex",
          alignItems: "center",
          gap: 16,
          zIndex: 1000,
          boxShadow: "0 4px 20px rgba(0,0,0,0.25)",
        }}
      >
        <Typography.Text style={{ color: "#fff", fontWeight: 600 }}>
          {selectedIds.length} selected
        </Typography.Text>
        <Space>
          {entityType === "user" && (
            <>
              <Button size="small" onClick={() => setStatusModalOpen(true)}>
                Change Status
              </Button>
              <Button size="small" onClick={() => setNotifyModalOpen(true)}>
                Send Notification
              </Button>
            </>
          )}
          {entityType === "tenant" && (
            <Button size="small" onClick={() => setTierModalOpen(true)}>
              Override Tier
            </Button>
          )}
        </Space>
        <Button
          type="text"
          size="small"
          icon={<CloseOutlined />}
          onClick={onClear}
          style={{ color: "#6D7F99" }}
        />
      </div>

      {/* Status Change Modal */}
      <Modal
        title="Bulk Status Change"
        open={statusModalOpen}
        onOk={handleStatusChange}
        onCancel={() => setStatusModalOpen(false)}
        confirmLoading={loading}
      >
        <Form form={statusForm} layout="vertical">
          <Form.Item name="new_status" label="New Status" rules={[{ required: true }]}>
            <Select
              options={[
                { value: "active", label: "Active" },
                { value: "inactive", label: "Inactive" },
              ]}
            />
          </Form.Item>
          <Form.Item name="reason" label="Reason" rules={[{ required: true }]}>
            <Input.TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>

      {/* Tier Override Modal */}
      <Modal
        title="Bulk Tier Override"
        open={tierModalOpen}
        onOk={handleTierOverride}
        onCancel={() => setTierModalOpen(false)}
        confirmLoading={loading}
      >
        <Form form={tierForm} layout="vertical">
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
            <Input.TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>

      {/* Notification Modal */}
      <Modal
        title="Bulk Notification"
        open={notifyModalOpen}
        onOk={handleNotification}
        onCancel={() => setNotifyModalOpen(false)}
        confirmLoading={loading}
      >
        <Form form={notifyForm} layout="vertical">
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
