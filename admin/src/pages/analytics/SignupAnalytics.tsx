import { useState } from "react";
import { Card, Typography, Select, Space, Statistic, Row, Col } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchSignupAnalytics } from "@/lib/api";
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

export default function SignupAnalyticsPage() {
  const [days, setDays] = useState(30);

  const { data } = useQuery({
    queryKey: ["signup-analytics", days],
    queryFn: () => fetchSignupAnalytics({ period: "daily", days }),
  });

  const chartData = data?.data_points.map((dp) => ({
    date: dayjs(dp.date).format("MMM D"),
    signups: dp.count,
  }));

  return (
    <>
      <Space style={{ marginBottom: 16, justifyContent: "space-between", width: "100%" }}>
        <Typography.Title level={4} style={{ margin: 0 }}>
          Signups & Growth
        </Typography.Title>
        <Select
          value={days}
          onChange={setDays}
          style={{ width: 140 }}
          options={[
            { value: 7, label: "Last 7 days" },
            { value: 14, label: "Last 14 days" },
            { value: 30, label: "Last 30 days" },
            { value: 90, label: "Last 90 days" },
          ]}
        />
      </Space>

      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={8}>
          <Card>
            <Statistic title={`Total Signups (${days}d)`} value={data?.total || 0} />
          </Card>
        </Col>
      </Row>

      <Card>
        {chartData && chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height={400}>
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
          <Typography.Text type="secondary">No data available</Typography.Text>
        )}
      </Card>
    </>
  );
}
