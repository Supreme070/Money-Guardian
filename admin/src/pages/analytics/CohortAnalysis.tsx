/**
 * Cohort retention heatmap — rows are signup months, columns are month offsets.
 */

import { useMemo } from "react";
import { Typography, Card, Spin } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchCohortData } from "@/lib/api";
import type { CohortData } from "@/lib/types";

function getCellColor(rate: number): string {
  // Green gradient: higher retention = deeper green
  const alpha = Math.max(0.08, rate / 100);
  return `rgba(34, 197, 94, ${alpha})`;
}

function getTextColor(rate: number): string {
  return rate > 60 ? "#fff" : "#1D2635";
}

export default function CohortAnalysisPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["cohort-analysis"],
    queryFn: fetchCohortData,
    staleTime: 60_000,
  });

  // Group by cohort_month
  const { cohorts, maxOffset } = useMemo(() => {
    if (!data || data.length === 0) return { cohorts: new Map<string, CohortData[]>(), maxOffset: 0 };

    const map = new Map<string, CohortData[]>();
    let max = 0;

    for (const point of data) {
      const existing = map.get(point.cohort_month) || [];
      existing.push(point);
      map.set(point.cohort_month, existing);
      if (point.month_offset > max) max = point.month_offset;
    }

    return { cohorts: map, maxOffset: max };
  }, [data]);

  const sortedCohortKeys = useMemo(
    () => Array.from(cohorts.keys()).sort(),
    [cohorts],
  );

  const offsets = useMemo(
    () => Array.from({ length: maxOffset + 1 }, (_, i) => i),
    [maxOffset],
  );

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  return (
    <div>
      <Typography.Title level={4}>Cohort Analysis</Typography.Title>

      <Card>
        {sortedCohortKeys.length > 0 ? (
          <div style={{ overflowX: "auto" }}>
            <table
              style={{
                borderCollapse: "collapse",
                width: "100%",
                minWidth: 600,
                fontSize: 13,
              }}
            >
              <thead>
                <tr>
                  <th
                    style={{
                      padding: "8px 12px",
                      textAlign: "left",
                      borderBottom: "2px solid #e5e5e5",
                      whiteSpace: "nowrap",
                      background: "#fafafa",
                      color: "#1D2635",
                      fontWeight: 600,
                    }}
                  >
                    Cohort
                  </th>
                  {offsets.map((offset) => (
                    <th
                      key={offset}
                      style={{
                        padding: "8px 10px",
                        textAlign: "center",
                        borderBottom: "2px solid #e5e5e5",
                        whiteSpace: "nowrap",
                        background: "#fafafa",
                        color: "#1D2635",
                        fontWeight: 600,
                        minWidth: 60,
                      }}
                    >
                      M{offset}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {sortedCohortKeys.map((cohortMonth) => {
                  const points = cohorts.get(cohortMonth) || [];
                  const pointMap = new Map(points.map((p) => [p.month_offset, p]));

                  return (
                    <tr key={cohortMonth}>
                      <td
                        style={{
                          padding: "8px 12px",
                          borderBottom: "1px solid #f0f0f0",
                          fontWeight: 500,
                          whiteSpace: "nowrap",
                          color: "#1D2635",
                        }}
                      >
                        {cohortMonth}
                      </td>
                      {offsets.map((offset) => {
                        const point = pointMap.get(offset);
                        if (!point) {
                          return (
                            <td
                              key={offset}
                              style={{
                                padding: "8px 10px",
                                borderBottom: "1px solid #f0f0f0",
                                textAlign: "center",
                                color: "#B9B9B9",
                              }}
                            >
                              --
                            </td>
                          );
                        }
                        return (
                          <td
                            key={offset}
                            style={{
                              padding: "8px 10px",
                              borderBottom: "1px solid #f0f0f0",
                              textAlign: "center",
                              backgroundColor: getCellColor(point.retention_rate),
                              color: getTextColor(point.retention_rate),
                              fontWeight: 600,
                              borderRadius: 2,
                            }}
                            title={`${point.user_count} users`}
                          >
                            {point.retention_rate.toFixed(1)}%
                          </td>
                        );
                      })}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <Typography.Text type="secondary">No cohort data available</Typography.Text>
        )}
      </Card>
    </div>
  );
}
