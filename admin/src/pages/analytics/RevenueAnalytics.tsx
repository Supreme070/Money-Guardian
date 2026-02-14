import { Card, Typography, Row, Col, Statistic, Table, Tag } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchRevenueAnalytics } from "@/lib/api";

export default function RevenueAnalyticsPage() {
  const { data } = useQuery({
    queryKey: ["revenue-analytics"],
    queryFn: fetchRevenueAnalytics,
  });

  const tierData = data
    ? Object.entries(data.tier_breakdown).map(([tier, count]) => ({
        tier,
        count,
      }))
    : [];

  return (
    <>
      <Typography.Title level={4}>Revenue Analytics</Typography.Title>

      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic
              title="Total Paid Users"
              value={data?.total_paid_users || 0}
              valueStyle={{ color: "#FBBD5C" }}
            />
          </Card>
        </Col>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic
              title="Churn (30d)"
              value={data?.churn_count_30d || 0}
              valueStyle={{ color: data?.churn_count_30d ? "#EF4444" : undefined }}
            />
          </Card>
        </Col>
      </Row>

      <Card title="Tier Breakdown">
        <Table
          dataSource={tierData}
          rowKey="tier"
          size="small"
          pagination={false}
          columns={[
            {
              title: "Tier",
              dataIndex: "tier",
              render: (t: string) => (
                <Tag color={t === "pro" ? "gold" : t === "enterprise" ? "blue" : "default"}>
                  {t}
                </Tag>
              ),
            },
            {
              title: "Users",
              dataIndex: "count",
              width: 100,
              align: "right",
            },
          ]}
        />
      </Card>
    </>
  );
}
