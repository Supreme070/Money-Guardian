import { Card, Typography, Row, Col, Statistic, Table, Tag, Progress } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchConnectionAnalytics } from "@/lib/api";
import type { ProviderStat } from "@/lib/types";

export default function ConnectionAnalyticsPage() {
  const { data } = useQuery({
    queryKey: ["connection-analytics"],
    queryFn: fetchConnectionAnalytics,
  });

  const providerColumns = [
    { title: "Provider", dataIndex: "provider", render: (v: string) => <Tag>{v}</Tag> },
    { title: "Total", dataIndex: "total", width: 70, align: "right" as const },
    {
      title: "Connected",
      dataIndex: "connected",
      width: 90,
      align: "right" as const,
      render: (v: number) => <span style={{ color: "#22C55E" }}>{v}</span>,
    },
    {
      title: "Error",
      dataIndex: "error",
      width: 70,
      align: "right" as const,
      render: (v: number) => (v > 0 ? <span style={{ color: "#EF4444" }}>{v}</span> : v),
    },
    {
      title: "Reauth",
      dataIndex: "requires_reauth",
      width: 80,
      align: "right" as const,
      render: (v: number) => (v > 0 ? <span style={{ color: "#F97316" }}>{v}</span> : v),
    },
    {
      title: "Success Rate",
      key: "rate",
      width: 120,
      render: (_: unknown, record: ProviderStat) => {
        const rate = record.total > 0 ? (record.connected / record.total) * 100 : 0;
        return <Progress percent={Math.round(rate)} size="small" />;
      },
    },
  ];

  return (
    <>
      <Typography.Title level={4}>Connection Analytics</Typography.Title>

      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic
              title="Bank Success Rate"
              value={data?.bank_success_rate || 0}
              suffix="%"
              precision={1}
              valueStyle={{ color: "#22C55E" }}
            />
          </Card>
        </Col>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic
              title="Email Success Rate"
              value={data?.email_success_rate || 0}
              suffix="%"
              precision={1}
              valueStyle={{ color: "#22C55E" }}
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={12}>
          <Card title="Bank Connection Providers">
            <Table
              dataSource={data?.bank_providers}
              columns={providerColumns}
              rowKey="provider"
              size="small"
              pagination={false}
            />
          </Card>
        </Col>
        <Col xs={24} lg={12}>
          <Card title="Email Connection Providers">
            <Table
              dataSource={data?.email_providers}
              columns={providerColumns}
              rowKey="provider"
              size="small"
              pagination={false}
            />
          </Card>
        </Col>
      </Row>
    </>
  );
}
