/**
 * Customer health detail page — radar chart of factors, score history, snapshots.
 */

import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import {
  Typography,
  Card,
  Row,
  Col,
  Tag,
  Table,
  Spin,
  Button,
  Space,
} from "antd";
import { ArrowLeftOutlined } from "@ant-design/icons";
import {
  ResponsiveContainer,
  RadarChart,
  Radar,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from "recharts";
import { fetchUserHealthHistory } from "@/lib/api";
import type { HealthScore } from "@/lib/types";
import HealthScoreBadge from "@/components/HealthScoreBadge";
import dayjs from "dayjs";

const RISK_TAG_COLORS: Record<string, string> = {
  healthy: "#22C55E",
  at_risk: "#FBBD5C",
  churning: "#EF4444",
};

export default function CustomerHealthDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();

  const { data: history, isLoading } = useQuery({
    queryKey: ["health-history", userId],
    queryFn: () => fetchUserHealthHistory(userId!),
    enabled: !!userId,
  });

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const latest = history && history.length > 0 ? history[history.length - 1] : null;

  // Build radar data from latest factors
  const radarData = latest
    ? Object.entries(latest.factors).map(([key, value]) => ({
        factor: key.replace(/_/g, " "),
        value,
        fullMark: 100,
      }))
    : [];

  // Build line chart data from history (last 90 days)
  const lineData = (history || [])
    .slice(-90)
    .map((s) => ({
      date: dayjs(s.snapshot_date).format("MMM D"),
      score: s.score,
    }));

  const snapshotColumns = [
    {
      title: "Date",
      dataIndex: "snapshot_date",
      key: "snapshot_date",
      render: (v: string) => dayjs(v).format("MMM D, YYYY"),
    },
    {
      title: "Score",
      dataIndex: "score",
      key: "score",
      width: 80,
      render: (score: number, record: HealthScore) => (
        <HealthScoreBadge score={score} risk_level={record.risk_level} />
      ),
    },
    {
      title: "Risk Level",
      dataIndex: "risk_level",
      key: "risk_level",
      width: 120,
      render: (level: string) => (
        <Tag
          color={RISK_TAG_COLORS[level] || "default"}
          style={{
            color: level === "at_risk" ? "#1D2635" : "#fff",
            fontWeight: 600,
          }}
        >
          {level.replace("_", " ").toUpperCase()}
        </Tag>
      ),
    },
    {
      title: "Factors",
      key: "factors",
      render: (_: unknown, record: HealthScore) => (
        <Typography.Text
          ellipsis={{ tooltip: JSON.stringify(record.factors, null, 2) }}
          style={{ maxWidth: 300, display: "inline-block", fontSize: 12 }}
        >
          {JSON.stringify(record.factors)}
        </Typography.Text>
      ),
    },
  ];

  return (
    <div>
      <Space style={{ marginBottom: 16 }}>
        <Button
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate("/analytics/health")}
        >
          Back
        </Button>
      </Space>

      <Typography.Title level={4} style={{ marginBottom: 16 }}>
        Health Detail:{" "}
        <Typography.Text code style={{ fontSize: 16 }}>
          {userId?.slice(0, 12)}...
        </Typography.Text>
      </Typography.Title>

      {/* Current score */}
      {latest && (
        <Card style={{ marginBottom: 16 }}>
          <Space size="large" align="center">
            <HealthScoreBadge score={latest.score} risk_level={latest.risk_level} />
            <div>
              <Typography.Text strong style={{ fontSize: 18 }}>
                Score: {latest.score}
              </Typography.Text>
              <br />
              <Tag
                color={RISK_TAG_COLORS[latest.risk_level] || "default"}
                style={{
                  color: latest.risk_level === "at_risk" ? "#1D2635" : "#fff",
                  fontWeight: 600,
                  marginTop: 4,
                }}
              >
                {latest.risk_level.replace("_", " ").toUpperCase()}
              </Tag>
            </div>
          </Space>
        </Card>
      )}

      <Row gutter={[16, 16]}>
        {/* Radar chart */}
        <Col xs={24} lg={12}>
          <Card title="Factor Breakdown">
            {radarData.length > 0 ? (
              <ResponsiveContainer width="100%" height={320}>
                <RadarChart data={radarData}>
                  <PolarGrid />
                  <PolarAngleAxis dataKey="factor" tick={{ fontSize: 12 }} />
                  <PolarRadiusAxis angle={30} domain={[0, 100]} tick={{ fontSize: 10 }} />
                  <Radar
                    name="Score"
                    dataKey="value"
                    stroke="#375EFD"
                    fill="#375EFD"
                    fillOpacity={0.25}
                  />
                </RadarChart>
              </ResponsiveContainer>
            ) : (
              <Typography.Text type="secondary">No factor data</Typography.Text>
            )}
          </Card>
        </Col>

        {/* Line chart */}
        <Col xs={24} lg={12}>
          <Card title="Score Over Time (Last 90 Days)">
            {lineData.length > 0 ? (
              <ResponsiveContainer width="100%" height={320}>
                <LineChart data={lineData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis domain={[0, 100]} />
                  <Tooltip />
                  <Line
                    type="monotone"
                    dataKey="score"
                    stroke="#375EFD"
                    strokeWidth={2}
                    dot={{ fill: "#375EFD", r: 3 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <Typography.Text type="secondary">No history data</Typography.Text>
            )}
          </Card>
        </Col>
      </Row>

      {/* Snapshots table */}
      <Card title="Recent Snapshots" style={{ marginTop: 16 }}>
        <Table
          rowKey={(record) => `${record.user_id}-${record.snapshot_date}`}
          columns={snapshotColumns}
          dataSource={history}
          size="small"
          pagination={{ pageSize: 10 }}
        />
      </Card>
    </div>
  );
}
