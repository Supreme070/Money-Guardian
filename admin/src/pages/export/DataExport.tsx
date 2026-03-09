/**
 * Data Export page with card-based export options.
 */

import { useState } from "react";
import { Card, Row, Col, Typography, Button, message, List, Tag, Space } from "antd";
import {
  TeamOutlined,
  AppstoreOutlined,
  AuditOutlined,
  DownloadOutlined,
  LoadingOutlined,
  CheckCircleOutlined,
} from "@ant-design/icons";
import { requestExport, getExportDownloadUrl } from "@/lib/api";

interface ExportOption {
  key: string;
  title: string;
  description: string;
  icon: React.ReactNode;
  exportType: string;
}

const EXPORT_OPTIONS: ExportOption[] = [
  {
    key: "users",
    title: "Users CSV",
    description: "Export all user accounts with profile data, tier, status, and signup dates.",
    icon: <TeamOutlined style={{ fontSize: 32, color: "#375EFD" }} />,
    exportType: "users",
  },
  {
    key: "subscriptions",
    title: "Subscriptions CSV",
    description: "Export all tracked subscriptions with amounts, billing cycles, and AI flags.",
    icon: <AppstoreOutlined style={{ fontSize: 32, color: "#FBBD5C" }} />,
    exportType: "subscriptions",
  },
  {
    key: "audit_log",
    title: "Audit Log CSV",
    description: "Export admin audit log with all actions, timestamps, and admin user details.",
    icon: <AuditOutlined style={{ fontSize: 32, color: "#15294A" }} />,
    exportType: "audit_log",
  },
];

interface RecentExport {
  id: string;
  type: string;
  status: "ready" | "processing";
  createdAt: string;
}

export default function DataExportPage() {
  const [loadingKey, setLoadingKey] = useState<string | null>(null);
  const [recentExports, setRecentExports] = useState<RecentExport[]>([]);

  const handleExport = async (option: ExportOption) => {
    setLoadingKey(option.key);
    try {
      const result = await requestExport({
        export_type: option.exportType,
        format: "csv",
      });
      const newExport: RecentExport = {
        id: result.export_id,
        type: option.title,
        status: "ready",
        createdAt: new Date().toISOString(),
      };
      setRecentExports((prev) => [newExport, ...prev]);

      const url = getExportDownloadUrl(result.export_id);
      window.open(url, "_blank");
      message.success(`${option.title} export started`);
    } catch {
      message.error(`Failed to export ${option.title}`);
    } finally {
      setLoadingKey(null);
    }
  };

  return (
    <>
      <Typography.Title level={4} style={{ marginBottom: 24 }}>
        <DownloadOutlined style={{ marginRight: 8, color: "#375EFD" }} />
        Data Export
      </Typography.Title>

      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        {EXPORT_OPTIONS.map((option) => (
          <Col xs={24} sm={12} lg={8} key={option.key}>
            <Card
              hoverable
              style={{ textAlign: "center", height: "100%" }}
              bodyStyle={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                padding: 32,
                height: "100%",
              }}
            >
              <div style={{ marginBottom: 16 }}>{option.icon}</div>
              <Typography.Title level={5} style={{ marginBottom: 8 }}>
                {option.title}
              </Typography.Title>
              <Typography.Text
                type="secondary"
                style={{ display: "block", marginBottom: 20, fontSize: 13 }}
              >
                {option.description}
              </Typography.Text>
              <Button
                type="primary"
                icon={loadingKey === option.key ? <LoadingOutlined /> : <DownloadOutlined />}
                loading={loadingKey === option.key}
                onClick={() => handleExport(option)}
              >
                Export
              </Button>
            </Card>
          </Col>
        ))}
      </Row>

      {recentExports.length > 0 && (
        <Card title="Recent Exports">
          <List
            dataSource={recentExports}
            renderItem={(item) => (
              <List.Item
                actions={[
                  <Button
                    key="download"
                    type="link"
                    size="small"
                    icon={<DownloadOutlined />}
                    onClick={() => {
                      const url = getExportDownloadUrl(item.id);
                      window.open(url, "_blank");
                    }}
                  >
                    Download
                  </Button>,
                ]}
              >
                <List.Item.Meta
                  title={
                    <Space>
                      <span>{item.type}</span>
                      <Tag
                        icon={<CheckCircleOutlined />}
                        color={item.status === "ready" ? "success" : "processing"}
                      >
                        {item.status}
                      </Tag>
                    </Space>
                  }
                  description={new Date(item.createdAt).toLocaleString()}
                />
              </List.Item>
            )}
          />
        </Card>
      )}
    </>
  );
}
