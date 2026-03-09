/**
 * Segmented progress bar for bulk operations.
 * Shows green (processed), red (failed), grey (remaining) segments.
 */

import { Typography } from "antd";

interface ProgressBarProps {
  processed: number;
  failed: number;
  total: number;
}

export default function ProgressBar({ processed, failed, total }: ProgressBarProps) {
  const safeTotal = total || 1;
  const processedPct = (processed / safeTotal) * 100;
  const failedPct = (failed / safeTotal) * 100;
  const completedPct = Math.round(((processed + failed) / safeTotal) * 100);

  return (
    <div>
      <div
        style={{
          display: "flex",
          height: 12,
          borderRadius: 6,
          overflow: "hidden",
          background: "#f0f0f0",
          width: "100%",
        }}
      >
        <div
          style={{
            width: `${processedPct}%`,
            background: "#22C55E",
            transition: "width 0.3s ease",
          }}
        />
        <div
          style={{
            width: `${failedPct}%`,
            background: "#EF4444",
            transition: "width 0.3s ease",
          }}
        />
      </div>
      <Typography.Text type="secondary" style={{ fontSize: 12, marginTop: 2, display: "block" }}>
        {completedPct}% ({processed} done, {failed} failed, {total - processed - failed} remaining)
      </Typography.Text>
    </div>
  );
}
