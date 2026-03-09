/**
 * Retention curve chart — shows user retention over time (days).
 */

import { Typography, Card, Spin } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchRetentionData } from "@/lib/api";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ReferenceDot,
} from "recharts";
import type { RetentionPoint } from "@/lib/types";

interface CustomLabelProps {
  x?: number;
  y?: number;
  value?: number;
  user_count?: number;
}

function CustomLabel({ x, y, value, user_count }: CustomLabelProps) {
  if (x === undefined || y === undefined) return null;
  return (
    <g>
      <text
        x={x}
        y={y - 14}
        textAnchor="middle"
        fill="#375EFD"
        fontSize={11}
        fontWeight={600}
      >
        {value?.toFixed(1)}%
      </text>
      <text
        x={x}
        y={y - 2}
        textAnchor="middle"
        fill="#797878"
        fontSize={9}
      >
        {user_count} users
      </text>
    </g>
  );
}

export default function RetentionCurvesPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["retention-curves"],
    queryFn: fetchRetentionData,
    staleTime: 60_000,
  });

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const chartData = (data || []).map((point) => ({
    day: `Day ${point.day}`,
    dayNum: point.day,
    retention: point.retention_rate,
    users: point.user_count,
  }));

  return (
    <div>
      <Typography.Title level={4}>Retention Curves</Typography.Title>

      <Card>
        {chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height={420}>
            <AreaChart data={chartData} margin={{ top: 30, right: 30, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis
                domain={[0, 100]}
                tickFormatter={(v: number) => `${v}%`}
                tick={{ fontSize: 12 }}
              />
              <Tooltip
                formatter={(value: number) => [`${value.toFixed(1)}%`, "Retention"]}
              />
              <Area
                type="monotone"
                dataKey="retention"
                stroke="#375EFD"
                fill="#375EFD"
                fillOpacity={0.12}
                strokeWidth={2}
              />
              {(data || []).map((point: RetentionPoint) => (
                <ReferenceDot
                  key={point.day}
                  x={`Day ${point.day}`}
                  y={point.retention_rate}
                  r={5}
                  fill="#375EFD"
                  stroke="#fff"
                  strokeWidth={2}
                  label={
                    <CustomLabel
                      value={point.retention_rate}
                      user_count={point.user_count}
                    />
                  }
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <Typography.Text type="secondary">No retention data available</Typography.Text>
        )}
      </Card>
    </div>
  );
}
