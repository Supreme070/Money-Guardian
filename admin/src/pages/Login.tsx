import { useState } from "react";
import { Card, Form, Input, Button, Typography, message, Space } from "antd";
import { LockOutlined, AppstoreOutlined } from "@ant-design/icons";
import { useAuth } from "@/lib/auth";

export default function LoginPage() {
  const { login } = useAuth();
  const [loading, setLoading] = useState(false);

  const onFinish = async (values: { key: string }) => {
    setLoading(true);
    const success = await login(values.key);
    setLoading(false);
    if (!success) {
      message.error("Invalid admin key");
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "#15294A",
      }}
    >
      <Card style={{ width: 400 }}>
        <Space
          direction="vertical"
          size="large"
          style={{ width: "100%", textAlign: "center" }}
        >
          <div>
            <AppstoreOutlined
              style={{ fontSize: 40, color: "#375EFD", marginBottom: 8 }}
            />
            <Typography.Title level={3} style={{ margin: 0 }}>
              Money Guardian
            </Typography.Title>
            <Typography.Text type="secondary">Admin Portal</Typography.Text>
          </div>

          <Form onFinish={onFinish} layout="vertical" requiredMark={false}>
            <Form.Item
              name="key"
              rules={[
                { required: true, message: "Enter your admin API key" },
              ]}
            >
              <Input.Password
                prefix={<LockOutlined />}
                placeholder="Admin API Key"
                size="large"
              />
            </Form.Item>
            <Form.Item>
              <Button
                type="primary"
                htmlType="submit"
                loading={loading}
                block
                size="large"
                style={{ background: "#375EFD" }}
              >
                Sign In
              </Button>
            </Form.Item>
          </Form>
        </Space>
      </Card>
    </div>
  );
}
