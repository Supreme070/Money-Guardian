import { Card, Col, Row, Statistic, Typography, Table, Spin } from "antd";
import {
  UserOutlined,
  RiseOutlined,
  DollarOutlined,
  BankOutlined,
  MailOutlined,
  AppstoreOutlined,
} from "@ant-design/icons";
import { useQuery } from "@tanstack/react-query";
import { fetchAnalyticsOverview, fetchSignupAnalytics, fetchUsers } from "@/lib/api";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from "recharts";
import dayjs from "dayjs";
import { useSSE } from "@/lib/sse";
import LiveActivityFeed from "@/components/LiveActivityFeed";

export default function DashboardPage() {
  const { data: overview, isLoading: overviewLoading } = useQuery({
    queryKey: ["analytics-overview"],
    queryFn: fetchAnalyticsOverview,
  });

  const { data: signups } = useQuery({
    queryKey: ["analytics-signups", "daily", 14],
    queryFn: () => fetchSignupAnalytics({ period: "daily", days: 14 }),
  });

  const { data: recentUsers } = useQuery({
    queryKey: ["users-recent"],
    queryFn: () => fetchUsers({ page: 1, page_size: 5 }),
  });

  const { events, connected } = useSSE("/api/v1/admin/sse/dashboard");

  if (overviewLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const stats = overview;

  const chartData = signups?.data_points.map((dp) => ({
    date: dayjs(dp.date).format("MMM D"),
    signups: dp.count,
  }));

  return (
    <>
      <Typography.Title level={4} style={{ marginBottom: 24 }}>
        Dashboard
      </Typography.Title>

      <Row gutter={[16, 16]}>
        <Col xs={24} sm={12} lg={4}>
          <Card>
            <Statistic
              title="Total Users"
              value={stats?.total_users}
              prefix={<UserOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={4}>
          <Card>
            <Statistic
              title="Active (30d)"
              value={stats?.active_users_30d}
              prefix={<RiseOutlined />}
              valueStyle={{ color: "#22C55E" }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={4}>
          <Card>
            <Statistic
              title="New (7d)"
              value={stats?.new_signups_7d}
              prefix={<UserOutlined />}
              valueStyle={{ color: "#375EFD" }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={4}>
          <Card>
            <Statistic
              title="Subscriptions"
              value={stats?.total_subscriptions}
              prefix={<AppstoreOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={4}>
          <Card>
            <Statistic
              title="Bank Connections"
              value={stats?.total_bank_connections}
              prefix={<BankOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={4}>
          <Card>
            <Statistic
              title="Monthly Value"
              value={stats?.monthly_tracked_value}
              prefix={<DollarOutlined />}
              precision={2}
              valueStyle={{ color: "#FBBD5C" }}
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Conversion Rate"
              value={stats?.conversion_rate}
              suffix="%"
              precision={1}
              valueStyle={{ color: "#375EFD" }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic title="Pro Users" value={stats?.pro_users} valueStyle={{ color: "#FBBD5C" }} />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic title="Enterprise Users" value={stats?.enterprise_users} />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Email Connections"
              value={stats?.total_email_connections}
              prefix={<MailOutlined />}
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} lg={16}>
          <Row gutter={[16, 16]}>
            <Col span={24}>
              <Card title="Signups (Last 14 Days)">
                {chartData && chartData.length > 0 ? (
                  <ResponsiveContainer width="100%" height={260}>
                    <AreaChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="date" />
                      <YAxis allowDecimals={false} />
                      <Tooltip />
                      <Area
                        type="monotone"
                        dataKey="signups"
                        stroke="#375EFD"
                        fill="#375EFD"
                        fillOpacity={0.15}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                ) : (
                  <Typography.Text type="secondary">No signup data yet</Typography.Text>
                )}
              </Card>
            </Col>
            <Col span={24}>
              <Card title="Recent Signups">
                <Table
                  dataSource={recentUsers?.users}
                  rowKey="id"
                  pagination={false}
                  size="small"
                  columns={[
                    {
                      title: "Email",
                      dataIndex: "email",
                      ellipsis: true,
                    },
                    {
                      title: "Tier",
                      dataIndex: "tier",
                      width: 80,
                      render: (tier: string) => (
                        <span
                          style={{
                            color: tier === "pro" ? "#FBBD5C" : tier === "enterprise" ? "#375EFD" : undefined,
                            fontWeight: tier !== "free" ? 600 : undefined,
                          }}
                        >
                          {tier}
                        </span>
                      ),
                    },
                    {
                      title: "Joined",
                      dataIndex: "created_at",
                      width: 100,
                      render: (v: string) => dayjs(v).format("MMM D"),
                    },
                  ]}
                />
              </Card>
            </Col>
          </Row>
        </Col>

        <Col xs={24} lg={8}>
          <LiveActivityFeed events={events} connected={connected} />
        </Col>
      </Row>
    </>
  );
}
