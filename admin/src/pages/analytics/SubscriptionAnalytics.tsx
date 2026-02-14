import { Card, Typography, Table, Row, Col, Statistic, Tag } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchSubscriptionAnalytics } from "@/lib/api";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  Legend,
} from "recharts";

const FLAG_COLORS: Record<string, string> = {
  none: "#22C55E",
  unused: "#EF4444",
  duplicate: "#F97316",
  price_increase: "#FBBD5C",
  trial_ending: "#375EFD",
  forgotten: "#6D7F99",
};

export default function SubscriptionAnalyticsPage() {
  const { data } = useQuery({
    queryKey: ["subscription-analytics"],
    queryFn: fetchSubscriptionAnalytics,
  });

  const flagData = data
    ? Object.entries(data.flag_distribution).map(([name, value]) => ({
        name,
        value,
      }))
    : [];

  const sourceData = data
    ? Object.entries(data.source_distribution).map(([name, value]) => ({
        name,
        value,
      }))
    : [];

  return (
    <>
      <Typography.Title level={4}>Subscription Analytics</Typography.Title>

      <Row gutter={[16, 16]}>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic title="Total Tracked" value={data?.total_tracked} />
          </Card>
        </Col>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic title="Avg per User" value={data?.avg_per_user} precision={1} />
          </Card>
        </Col>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic
              title="Monthly Value"
              value={data?.total_monthly_value}
              prefix="$"
              precision={2}
            />
          </Card>
        </Col>
        <Col xs={12} lg={6}>
          <Card>
            <Statistic
              title="Yearly Value"
              value={data?.total_yearly_value}
              prefix="$"
              precision={2}
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} lg={14}>
          <Card title="Top Merchants">
            {data?.top_merchants && data.top_merchants.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart
                  data={data.top_merchants.slice(0, 10)}
                  layout="vertical"
                  margin={{ left: 80 }}
                >
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis type="number" allowDecimals={false} />
                  <YAxis
                    type="category"
                    dataKey="name"
                    width={80}
                    tick={{ fontSize: 12 }}
                  />
                  <Tooltip />
                  <Bar dataKey="count" fill="#375EFD" radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <Typography.Text type="secondary">No merchants yet</Typography.Text>
            )}
          </Card>
        </Col>

        <Col xs={24} lg={10}>
          <Card title="AI Flag Distribution">
            {flagData.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={flagData}
                    cx="50%"
                    cy="50%"
                    outerRadius={100}
                    dataKey="value"
                    label={({ name, percent }) =>
                      `${name} (${(percent * 100).toFixed(0)}%)`
                    }
                    labelLine={false}
                  >
                    {flagData.map((entry) => (
                      <Cell
                        key={entry.name}
                        fill={FLAG_COLORS[entry.name] || "#6D7F99"}
                      />
                    ))}
                  </Pie>
                  <Legend />
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <Typography.Text type="secondary">No data</Typography.Text>
            )}
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} lg={12}>
          <Card title="Source Distribution">
            {sourceData.length > 0 ? (
              <Table
                dataSource={sourceData}
                rowKey="name"
                size="small"
                pagination={false}
                columns={[
                  {
                    title: "Source",
                    dataIndex: "name",
                    render: (s: string) => <Tag>{s}</Tag>,
                  },
                  { title: "Count", dataIndex: "value", width: 80, align: "right" },
                ]}
              />
            ) : (
              <Typography.Text type="secondary">No data</Typography.Text>
            )}
          </Card>
        </Col>

        <Col xs={24} lg={12}>
          <Card title="Top Merchants by Value">
            <Table
              dataSource={data?.top_merchants.slice(0, 10)}
              rowKey="name"
              size="small"
              pagination={false}
              columns={[
                { title: "Merchant", dataIndex: "name", ellipsis: true },
                { title: "Subs", dataIndex: "count", width: 60, align: "right" },
                {
                  title: "Monthly $",
                  dataIndex: "total_monthly_value",
                  width: 100,
                  align: "right",
                  render: (v: number) => `$${v.toFixed(2)}`,
                },
              ]}
            />
          </Card>
        </Col>
      </Row>
    </>
  );
}
