/**
 * Conversion funnel visualization — horizontal bars with decreasing widths.
 */

import { Typography, Card, Spin } from "antd";
import { useQuery } from "@tanstack/react-query";
import { fetchFunnelData } from "@/lib/api";

/**
 * Interpolates between two hex colors.
 */
function interpolateColor(color1: string, color2: string, t: number): string {
  const r1 = parseInt(color1.slice(1, 3), 16);
  const g1 = parseInt(color1.slice(3, 5), 16);
  const b1 = parseInt(color1.slice(5, 7), 16);
  const r2 = parseInt(color2.slice(1, 3), 16);
  const g2 = parseInt(color2.slice(3, 5), 16);
  const b2 = parseInt(color2.slice(5, 7), 16);

  const r = Math.round(r1 + (r2 - r1) * t);
  const g = Math.round(g1 + (g2 - g1) * t);
  const b = Math.round(b1 + (b2 - b1) * t);

  return `rgb(${r}, ${g}, ${b})`;
}

export default function ConversionFunnelPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["conversion-funnel"],
    queryFn: fetchFunnelData,
    staleTime: 60_000,
  });

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const steps = data || [];
  const firstStep = steps[0];
  const maxCount = firstStep ? firstStep.count : 1;

  return (
    <div>
      <Typography.Title level={4}>Conversion Funnel</Typography.Title>

      <Card>
        {steps.length > 0 ? (
          <div style={{ maxWidth: 700, margin: "0 auto", padding: "24px 0" }}>
            {steps.map((step, index) => {
              const widthPct = Math.max(20, (step.count / maxCount) * 100);
              const t = steps.length > 1 ? index / (steps.length - 1) : 0;
              const bgColor = interpolateColor("#375EFD", "#22C55E", t);

              return (
                <div
                  key={step.name}
                  style={{ marginBottom: 16, textAlign: "center" }}
                >
                  {/* Step label */}
                  <div
                    style={{
                      marginBottom: 6,
                      fontWeight: 600,
                      fontSize: 14,
                      color: "#1D2635",
                    }}
                  >
                    {step.name}
                  </div>

                  {/* Bar */}
                  <div
                    style={{
                      width: `${widthPct}%`,
                      margin: "0 auto",
                      background: bgColor,
                      borderRadius: 6,
                      padding: "14px 16px",
                      color: "#fff",
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      fontWeight: 500,
                      fontSize: 14,
                      transition: "width 0.4s ease",
                      minWidth: 180,
                    }}
                  >
                    <span>{step.count.toLocaleString()} users</span>
                    <span
                      style={{
                        backgroundColor: "rgba(255,255,255,0.2)",
                        padding: "2px 8px",
                        borderRadius: 4,
                        fontSize: 13,
                      }}
                    >
                      {step.conversion_rate.toFixed(1)}%
                    </span>
                  </div>

                  {/* Drop-off arrow between steps */}
                  {index < steps.length - 1 && (
                    <div
                      style={{
                        color: "#B9B9B9",
                        fontSize: 18,
                        margin: "4px 0",
                        lineHeight: 1,
                      }}
                    >
                      &#x25BC;
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        ) : (
          <Typography.Text type="secondary">No funnel data available</Typography.Text>
        )}
      </Card>
    </div>
  );
}
