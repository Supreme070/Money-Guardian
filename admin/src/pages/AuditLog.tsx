/**
 * Audit log page — searchable, filterable trail of all admin actions.
 */

import { useState } from "react";
import { Typography, Table, Tag, Input, Select, Space, Card } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchAuditLog } from "@/lib/api";
import type { AuditLogEntry } from "@/lib/types";

const ACTION_COLORS: Record<string, string> = {
  "admin.login": "blue",
  "admin.logout": "default",
  "admin.mfa_enabled": "green",
  "admin_user.create": "cyan",
  "admin_user.update": "orange",
  "user.status_change": "volcano",
  "tenant.status_change": "red",
  "tenant.tier_override": "gold",
};

export default function AuditLogPage() {
  const [page, setPage] = useState(1);
  const [actionFilter, setActionFilter] = useState<string | undefined>();
  const [entityTypeFilter, setEntityTypeFilter] = useState<string | undefined>();

  const { data, isLoading } = useQuery({
    queryKey: ["audit-log", page, actionFilter, entityTypeFilter],
    queryFn: () =>
      fetchAuditLog({
        page,
        page_size: 50,
        action: actionFilter,
        entity_type: entityTypeFilter,
      }),
    staleTime: 10_000,
  });

  const columns = [
    {
      title: "Time",
      dataIndex: "created_at",
      key: "created_at",
      width: 180,
      render: (v: string) => new Date(v).toLocaleString(),
    },
    {
      title: "Admin",
      key: "admin",
      width: 200,
      render: (_: unknown, record: AuditLogEntry) =>
        record.admin_name || record.admin_email || "System",
    },
    {
      title: "Action",
      dataIndex: "action",
      key: "action",
      width: 200,
      render: (v: string) => (
        <Tag color={ACTION_COLORS[v] || "default"}>{v}</Tag>
      ),
    },
    {
      title: "Entity",
      key: "entity",
      width: 200,
      render: (_: unknown, record: AuditLogEntry) => (
        <span>
          <Tag>{record.entity_type}</Tag>
          {record.entity_id ? (
            <Typography.Text code style={{ fontSize: 11 }}>
              {record.entity_id.slice(0, 8)}...
            </Typography.Text>
          ) : null}
        </span>
      ),
    },
    {
      title: "Details",
      dataIndex: "details",
      key: "details",
      render: (v: Record<string, unknown>) => (
        <Typography.Text
          ellipsis={{ tooltip: JSON.stringify(v, null, 2) }}
          style={{ maxWidth: 300, display: "inline-block" }}
        >
          {JSON.stringify(v)}
        </Typography.Text>
      ),
    },
    {
      title: "IP",
      dataIndex: "ip_address",
      key: "ip_address",
      width: 130,
    },
  ];

  return (
    <div>
      <Typography.Title level={3}>Audit Log</Typography.Title>

      <Card style={{ marginBottom: 16 }}>
        <Space wrap>
          <Input.Search
            placeholder="Filter by action..."
            allowClear
            onSearch={(v) => { setActionFilter(v || undefined); setPage(1); }}
            style={{ width: 250 }}
          />
          <Select
            placeholder="Entity type"
            allowClear
            onChange={(v) => { setEntityTypeFilter(v); setPage(1); }}
            options={[
              { value: "user", label: "User" },
              { value: "tenant", label: "Tenant" },
              { value: "admin_user", label: "Admin User" },
            ]}
            style={{ width: 160 }}
          />
        </Space>
      </Card>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={data?.entries}
        loading={isLoading}
        pagination={{
          current: page,
          pageSize: 50,
          total: data?.total_count || 0,
          onChange: setPage,
          showSizeChanger: false,
        }}
        scroll={{ x: 1100 }}
      />
    </div>
  );
}
