/**
 * Admin user management page (super_admin only).
 */

import { useState } from "react";
import {
  Typography,
  Table,
  Tag,
  Button,
  Modal,
  Form,
  Input,
  Select,
  Space,
  message,
} from "antd";
import { PlusOutlined, UserOutlined } from "@ant-design/icons";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchAdminUsers, createAdminUser, updateAdminUser } from "@/lib/api";
import type { AdminProfile, AdminRole } from "@/lib/types";

const ROLE_COLORS: Record<AdminRole, string> = {
  super_admin: "red",
  admin: "blue",
  support: "green",
  viewer: "default",
};

export default function AdminUsersPage() {
  const queryClient = useQueryClient();
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [createForm] = Form.useForm();

  const { data, isLoading } = useQuery({
    queryKey: ["admin-users"],
    queryFn: fetchAdminUsers,
    staleTime: 30_000,
  });

  const createMutation = useMutation({
    mutationFn: createAdminUser,
    onSuccess: () => {
      message.success("Admin user created");
      setCreateModalOpen(false);
      createForm.resetFields();
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
    },
    onError: () => message.error("Failed to create admin user"),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, is_active }: { id: string; is_active: boolean }) =>
      updateAdminUser(id, { is_active }),
    onSuccess: () => {
      message.success("Admin user updated");
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
    },
    onError: () => message.error("Failed to update admin user"),
  });

  const columns = [
    {
      title: "Name",
      dataIndex: "full_name",
      key: "full_name",
    },
    {
      title: "Email",
      dataIndex: "email",
      key: "email",
    },
    {
      title: "Role",
      dataIndex: "role",
      key: "role",
      render: (role: AdminRole) => (
        <Tag color={ROLE_COLORS[role]}>{role.replace("_", " ").toUpperCase()}</Tag>
      ),
    },
    {
      title: "MFA",
      dataIndex: "mfa_enabled",
      key: "mfa_enabled",
      render: (v: boolean) => (
        <Tag color={v ? "green" : "orange"}>{v ? "Enabled" : "Disabled"}</Tag>
      ),
    },
    {
      title: "Status",
      dataIndex: "is_active",
      key: "is_active",
      render: (v: boolean) => (
        <Tag color={v ? "green" : "red"}>{v ? "Active" : "Inactive"}</Tag>
      ),
    },
    {
      title: "Last Login",
      dataIndex: "last_login_at",
      key: "last_login_at",
      render: (v: string | null) => (v ? new Date(v).toLocaleString() : "Never"),
    },
    {
      title: "Actions",
      key: "actions",
      render: (_: unknown, record: AdminProfile) => (
        <Button
          size="small"
          danger={record.is_active}
          onClick={() =>
            toggleMutation.mutate({
              id: record.id,
              is_active: !record.is_active,
            })
          }
        >
          {record.is_active ? "Deactivate" : "Activate"}
        </Button>
      ),
    },
  ];

  return (
    <div>
      <Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
        <Typography.Title level={3} style={{ margin: 0 }}>
          Admin Users
        </Typography.Title>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={() => setCreateModalOpen(true)}
          style={{ background: "#375EFD" }}
        >
          Create Admin
        </Button>
      </Space>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={data?.admin_users}
        loading={isLoading}
        pagination={false}
      />

      <Modal
        title="Create Admin User"
        open={createModalOpen}
        onCancel={() => setCreateModalOpen(false)}
        footer={null}
      >
        <Form
          form={createForm}
          layout="vertical"
          onFinish={(values) => createMutation.mutate(values)}
        >
          <Form.Item
            name="email"
            label="Email"
            rules={[{ required: true, type: "email" }]}
          >
            <Input prefix={<UserOutlined />} placeholder="admin@moneyguardian.co" />
          </Form.Item>
          <Form.Item
            name="full_name"
            label="Full Name"
            rules={[{ required: true }]}
          >
            <Input placeholder="Full Name" />
          </Form.Item>
          <Form.Item
            name="password"
            label="Password"
            rules={[{ required: true, min: 12, message: "Minimum 12 characters" }]}
          >
            <Input.Password placeholder="Minimum 12 characters" />
          </Form.Item>
          <Form.Item
            name="role"
            label="Role"
            rules={[{ required: true }]}
          >
            <Select
              options={[
                { value: "super_admin", label: "Super Admin" },
                { value: "admin", label: "Admin" },
                { value: "support", label: "Support" },
                { value: "viewer", label: "Viewer" },
              ]}
            />
          </Form.Item>
          <Form.Item>
            <Button
              type="primary"
              htmlType="submit"
              loading={createMutation.isPending}
              block
              style={{ background: "#375EFD" }}
            >
              Create
            </Button>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
}
