/**
 * Rollout percentage slider (0-100) with marks and percentage display.
 */

import { Slider, Typography } from "antd";

interface RolloutSliderProps {
  value: number;
  onChange: (value: number) => void;
  disabled?: boolean;
}

const marks: Record<number, string> = {
  0: "0%",
  25: "25%",
  50: "50%",
  75: "75%",
  100: "100%",
};

export default function RolloutSlider({ value, onChange, disabled }: RolloutSliderProps) {
  return (
    <div>
      <Slider
        min={0}
        max={100}
        marks={marks}
        value={value}
        onChange={onChange}
        disabled={disabled}
        tooltip={{ formatter: (v) => `${v}%` }}
      />
      <Typography.Text type="secondary" style={{ fontSize: 12 }}>
        Rollout: {value}% of eligible users
      </Typography.Text>
    </div>
  );
}
