/**
 * Simple button that triggers a data export and shows status.
 */

import { useState } from "react";
import { Button, message } from "antd";
import { DownloadOutlined } from "@ant-design/icons";
import { requestExport, getExportDownloadUrl } from "@/lib/api";

interface ExportButtonProps {
  exportType: string;
  label: string;
}

export default function ExportButton({ exportType, label }: ExportButtonProps) {
  const [loading, setLoading] = useState(false);

  const handleExport = async () => {
    setLoading(true);
    try {
      const result = await requestExport({ export_type: exportType, format: "csv" });
      const url = getExportDownloadUrl(result.export_id);
      window.open(url, "_blank");
      message.success("Export started");
    } catch {
      message.error("Failed to start export");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Button
      icon={<DownloadOutlined />}
      loading={loading}
      onClick={handleExport}
    >
      {label}
    </Button>
  );
}
