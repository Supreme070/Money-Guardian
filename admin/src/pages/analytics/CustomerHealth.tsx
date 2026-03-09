/**
 * Customer health scores table with risk-level filtering and score range.
 */

import { useState } from "react";
import { Typography, Table, Tag, Select, Space, Card, Slider } from "antd";
import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchHealthScores } from "@/lib/api";
import type { HealthScore } from "@/lib/types";
import HealthScoreBadge from "@/components/HealthScoreBadge";
import dayjs from "dayjs";

const RISK_TAG_COLORS: Record<string, string> = {
  healthy: "#22C55E",
  at_risk: "#FBBD5C",
  churning: "#EF4444",
};

export default function CustomerHealthPage() {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const [riskFilter, setRiskFilter] = useState<string | undefined>();
  const [scoreRange, setScoreRange] = useState<[number, number]>([0, 100]);

  const { data, isLoading } = useQuery({
    queryKey: ["health-scores", page, riskFilter, scoreRange],
    queryFn: () =>
      fetchHealthScores({
        page,
        page_size: 20,
        risk_level: riskFilter,
        min_score: scoreRange[0],
        max_score: scoreRange[1],
      }),
    staleTime: 15_000,
  });

  const columns = [
    {
      title: "User ID",
      dataIndex: "user_id",
      key: "user_id",
      width: 140,
      render: (v: string) => (
        <Typography.Text
          code
          style={{ fontSize: 11, cursor: "pointer" }}
          onClick={() => navigate(`/analytics/health/${v}`)}
        >
          {v.slice(0, 12)}...
        </Typography.Text>
      ),
    },
    {
      title: "Score",
      dataIndex: "score",
      key: "score",
      width: 80,
      align: "center" as const,
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
      title: "Login Recency",
      key: "login_recency",
      width: 120,
      render: (_: unknown, record: HealthScore) => {
        const val = record.factors.login_recency;
        return val !== undefined ? `${val}` : "--";
      },
    },
    {
      title: "Connections",
      key: "connections",
      width: 110,
      render: (_: unknown, record: HealthScore) => {
        const val = record.factors.connections;
        return val !== undefined ? `${val}` : "--";
      },
    },
    {
      title: "Date",
      dataIndex: "snapshot_date",
      key: "snapshot_date",
      width: 120,
      render: (v: string) => dayjs(v).format("MMM D, YYYY"),
    },
  ];

  return (
    <div>
      <Typography.Title level={4}>Customer Health</Typography.Title>

      <Card style={{ marginBottom: 16 }}>
        <Space wrap style={{ width: "100%" }}>
          <Select
            placeholder="Risk Level"
            allowClear
            style={{ width: 160 }}
            value={riskFilter}
            onChange={(v) => {
              setRiskFilter(v);
              setPage(1);
            }}
            options={[
              { value: "healthy", label: "Healthy" },
              { value: "at_risk", label: "At Risk" },
              { value: "churning", label: "Churning" },
            ]}
          />
          <div style={{ width: 260 }}>
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              Score Range: {scoreRange[0]} - {scoreRange[1]}
            </Typography.Text>
            <Slider
              range
              min={0}
              max={100}
              value={scoreRange}
              onChange={(v) => {
                setScoreRange(v as [number, number]);
                setPage(1);
              }}
            />
          </div>
        </Space>
      </Card>

      <Table
        rowKey={(record) => `${record.user_id}-${record.snapshot_date}`}
        columns={columns}
        dataSource={data?.scores}
        loading={isLoading}
        onRow={(record) => ({
          style: { cursor: "pointer" },
          onClick: () => navigate(`/analytics/health/${record.user_id}`),
        })}
        pagination={{
          current: page,
          pageSize: 20,
          total: data?.total_count || 0,
          onChange: setPage,
          showSizeChanger: false,
          showTotal: (total) => `${total} scores`,
        }}
      />
    </div>
  );
}
