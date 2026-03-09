/**
 * Reusable badge showing a user's health score with risk-level coloring.
 */

interface HealthScoreBadgeProps {
  score: number;
  risk_level: "healthy" | "at_risk" | "churning";
}

const RISK_COLORS: Record<string, string> = {
  healthy: "#22C55E",
  at_risk: "#FBBD5C",
  churning: "#EF4444",
};

export default function HealthScoreBadge({ score, risk_level }: HealthScoreBadgeProps) {
  const color = RISK_COLORS[risk_level] || "#6D7F99";

  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        width: 36,
        height: 36,
        borderRadius: "50%",
        border: `2px solid ${color}`,
        backgroundColor: `${color}18`,
        color,
        fontWeight: 700,
        fontSize: 13,
      }}
      title={`${risk_level.replace("_", " ")} (${score})`}
    >
      {score}
    </div>
  );
}
