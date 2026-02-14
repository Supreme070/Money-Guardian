import { useState } from "react";
import { Table, Typography, Tag, Select, Space } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchErrorLog } from "@/lib/api";
import dayjs from "dayjs";

export default function ErrorLogPage() {
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [entityType, setEntityType] = useState<string | undefined>();

  const { data, isLoading } = useQuery({
    queryKey: ["error-log", page, pageSize, entityType],
    queryFn: () => fetchErrorLog({ page, page_size: pageSize, entity_type: entityType }),
  });

  return (
    <>
      <Typography.Title level={4}>Error Log</Typography.Title>

      <Space style={{ marginBottom: 16 }}>
        <Select
          placeholder="Entity Type"
          allowClear
          style={{ width: 180 }}
          value={entityType}
          onChange={(v) => {
            setEntityType(v);
            setPage(1);
          }}
          options={[
            { value: "bank_connection", label: "Bank Connections" },
            { value: "email_connection", label: "Email Connections" },
          ]}
        />
      </Space>

      <Table
        dataSource={data?.errors}
        rowKey="id"
        loading={isLoading}
        size="small"
        pagination={{
          current: page,
          pageSize,
          total: data?.pagination.total_count,
          showSizeChanger: true,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
        columns={[
          {
            title: "Type",
            dataIndex: "entity_type",
            width: 140,
            render: (t: string) => (
              <Tag color={t === "bank_connection" ? "blue" : "purple"}>
                {t === "bank_connection" ? "Bank" : "Email"}
              </Tag>
            ),
          },
          {
            title: "Provider",
            dataIndex: "provider",
            width: 80,
          },
          {
            title: "Institution / Email",
            dataIndex: "institution_or_email",
            ellipsis: true,
          },
          {
            title: "Status",
            dataIndex: "status",
            width: 110,
            render: (s: string) => (
              <Tag color={s === "error" ? "red" : "orange"}>{s}</Tag>
            ),
          },
          {
            title: "Error",
            dataIndex: "error_message",
            ellipsis: true,
            render: (v: string | null) => v || "—",
          },
          {
            title: "Last Attempt",
            dataIndex: "last_attempt_at",
            width: 130,
            render: (v: string | null) =>
              v ? dayjs(v).format("MMM D, h:mm A") : "—",
          },
        ]}
      />
    </>
  );
}
