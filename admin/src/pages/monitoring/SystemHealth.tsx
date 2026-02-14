import { Card, Typography, Row, Col, Tag, Statistic, Spin } from "antd";
import { CheckCircleOutlined, CloseCircleOutlined } from "@ant-design/icons";
import { useQuery } from "@tanstack/react-query";
import { fetchSystemHealth } from "@/lib/api";

export default function SystemHealthPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["system-health"],
    queryFn: fetchSystemHealth,
    refetchInterval: 30000, // Refresh every 30s
  });

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const overallColor =
    data?.overall_status === "healthy"
      ? "#22C55E"
      : data?.overall_status === "degraded"
        ? "#FBBD5C"
        : "#EF4444";

  return (
    <>
      <Typography.Title level={4}>System Health</Typography.Title>

      <Card style={{ marginBottom: 16 }}>
        <Statistic
          title="Overall Status"
          value={data?.overall_status?.toUpperCase() || "UNKNOWN"}
          valueStyle={{ color: overallColor, fontSize: 28 }}
        />
      </Card>

      <Row gutter={[16, 16]}>
        {data?.services.map((svc) => (
          <Col xs={24} sm={12} lg={8} key={svc.name}>
            <Card>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <Typography.Text strong style={{ fontSize: 16 }}>
                  {svc.name}
                </Typography.Text>
                <Tag
                  icon={svc.status === "healthy" ? <CheckCircleOutlined /> : <CloseCircleOutlined />}
                  color={svc.status === "healthy" ? "success" : "error"}
                >
                  {svc.status}
                </Tag>
              </div>
              {svc.latency_ms !== null && (
                <Typography.Text type="secondary" style={{ display: "block", marginTop: 8 }}>
                  Latency: {svc.latency_ms.toFixed(1)} ms
                </Typography.Text>
              )}
              {svc.error && (
                <Typography.Text type="danger" style={{ display: "block", marginTop: 8, fontSize: 12 }}>
                  {svc.error}
                </Typography.Text>
              )}
            </Card>
          </Col>
        ))}
      </Row>
    </>
  );
}
