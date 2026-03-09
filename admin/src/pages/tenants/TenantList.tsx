import { useState } from "react";
import { Table, Select, Tag, Typography, Space, Button } from "antd";
import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchTenants } from "@/lib/api";
import type { AdminTenantListItem } from "@/lib/types";
import BulkActionBar from "@/components/BulkActionBar";
import dayjs from "dayjs";

export default function TenantListPage() {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [tierFilter, setTierFilter] = useState<string | undefined>();
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const [selectedRowKeys, setSelectedRowKeys] = useState<string[]>([]);

  const { data, isLoading } = useQuery({
    queryKey: ["tenants", page, pageSize, tierFilter, statusFilter],
    queryFn: () =>
      fetchTenants({
        page,
        page_size: pageSize,
        tier: tierFilter,
        status: statusFilter,
      }),
  });

  const columns = [
    {
      title: "Name",
      dataIndex: "name",
      ellipsis: true,
      render: (name: string, record: AdminTenantListItem) => (
        <Button type="link" onClick={() => navigate(`/tenants/${record.id}`)} style={{ padding: 0 }}>
          {name}
        </Button>
      ),
    },
    {
      title: "Tier",
      dataIndex: "tier",
      width: 100,
      render: (tier: string) => (
        <Tag color={tier === "pro" ? "gold" : tier === "enterprise" ? "blue" : "default"}>
          {tier}
        </Tag>
      ),
    },
    {
      title: "Status",
      dataIndex: "status",
      width: 100,
      render: (status: string) => (
        <Tag color={status === "active" ? "green" : status === "suspended" ? "orange" : "red"}>
          {status}
        </Tag>
      ),
    },
    { title: "Users", dataIndex: "user_count", width: 80, align: "center" as const },
    { title: "Subscriptions", dataIndex: "subscription_count", width: 110, align: "center" as const },
    {
      title: "Created",
      dataIndex: "created_at",
      width: 120,
      render: (v: string) => dayjs(v).format("MMM D, YYYY"),
    },
  ];

  return (
    <>
      <Typography.Title level={4}>Tenants</Typography.Title>

      <Space style={{ marginBottom: 16 }} wrap>
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
            { value: "active", label: "Active" },
            { value: "suspended", label: "Suspended" },
            { value: "deleted", label: "Deleted" },
          ]}
        />
      </Space>

      <Table
        dataSource={data?.tenants}
        columns={columns}
        rowKey="id"
        loading={isLoading}
        rowSelection={{
          selectedRowKeys,
          onChange: (keys) => setSelectedRowKeys(keys as string[]),
        }}
        pagination={{
          current: page,
          pageSize,
          total: data?.pagination.total_count,
          showSizeChanger: true,
          showTotal: (total) => `${total} tenants`,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
      />

      <BulkActionBar
        selectedIds={selectedRowKeys}
        entityType="tenant"
        onClear={() => setSelectedRowKeys([])}
      />
    </>
  );
}
