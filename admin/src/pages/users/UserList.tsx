import { useState } from "react";
import { Table, Input, Select, Tag, Typography, Space, Button } from "antd";
import { SearchOutlined } from "@ant-design/icons";
import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchUsers } from "@/lib/api";
import type { AdminUserListItem } from "@/lib/types";
import dayjs from "dayjs";

const tierColors: Record<string, string> = {
  free: "default",
  pro: "gold",
  enterprise: "blue",
};

export default function UserListPage() {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [search, setSearch] = useState("");
  const [tierFilter, setTierFilter] = useState<string | undefined>();
  const [statusFilter, setStatusFilter] = useState<boolean | undefined>();

  const { data, isLoading } = useQuery({
    queryKey: ["users", page, pageSize, search, tierFilter, statusFilter],
    queryFn: () =>
      fetchUsers({
        page,
        page_size: pageSize,
        search: search || undefined,
        tier: tierFilter,
        is_active: statusFilter,
      }),
  });

  const columns = [
    {
      title: "Email",
      dataIndex: "email",
      ellipsis: true,
      render: (email: string, record: AdminUserListItem) => (
        <Button type="link" onClick={() => navigate(`/users/${record.id}`)} style={{ padding: 0 }}>
          {email}
        </Button>
      ),
    },
    {
      title: "Name",
      dataIndex: "full_name",
      ellipsis: true,
      render: (v: string | null) => v || "—",
    },
    {
      title: "Tier",
      dataIndex: "tier",
      width: 100,
      render: (tier: string) => (
        <Tag color={tierColors[tier] || "default"}>{tier}</Tag>
      ),
    },
    {
      title: "Status",
      dataIndex: "is_active",
      width: 90,
      render: (active: boolean) => (
        <Tag color={active ? "green" : "red"}>{active ? "Active" : "Inactive"}</Tag>
      ),
    },
    {
      title: "Subs",
      dataIndex: "subscription_count",
      width: 70,
      align: "center" as const,
    },
    {
      title: "Connections",
      dataIndex: "connection_count",
      width: 100,
      align: "center" as const,
    },
    {
      title: "Joined",
      dataIndex: "created_at",
      width: 110,
      render: (v: string) => dayjs(v).format("MMM D, YYYY"),
    },
  ];

  return (
    <>
      <Typography.Title level={4}>Users</Typography.Title>

      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="Search by email or name"
          prefix={<SearchOutlined />}
          allowClear
          style={{ width: 280 }}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
        <Select
          placeholder="Tier"
          allowClear
          style={{ width: 130 }}
          value={tierFilter}
          onChange={(v) => {
            setTierFilter(v);
            setPage(1);
          }}
          options={[
            { value: "free", label: "Free" },
            { value: "pro", label: "Pro" },
            { value: "enterprise", label: "Enterprise" },
          ]}
        />
        <Select
          placeholder="Status"
          allowClear
          style={{ width: 130 }}
          value={statusFilter}
          onChange={(v) => {
            setStatusFilter(v);
            setPage(1);
          }}
          options={[
            { value: true, label: "Active" },
            { value: false, label: "Inactive" },
          ]}
        />
      </Space>

      <Table
        dataSource={data?.users}
        columns={columns}
        rowKey="id"
        loading={isLoading}
        pagination={{
          current: page,
          pageSize,
          total: data?.pagination.total_count,
          showSizeChanger: true,
          showTotal: (total) => `${total} users`,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
      />
    </>
  );
}
