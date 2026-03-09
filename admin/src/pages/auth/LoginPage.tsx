/**
 * Admin login page with email/password and MFA support.
 */

import { useState } from "react";
import { Card, Form, Input, Button, Typography, Alert, Space } from "antd";
import { LockOutlined, MailOutlined, SafetyCertificateOutlined } from "@ant-design/icons";
import { useAdminAuth } from "@/lib/adminAuth";

export default function LoginPage() {
  const { login, verifyMfa } = useAdminAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [mfaStep, setMfaStep] = useState(false);
  const [sessionToken, setSessionToken] = useState<string>("");

  async function handleLogin(values: { email: string; password: string }) {
    setLoading(true);
    setError(null);
    try {
      const result = await login(values.email, values.password);
      if (result.requiresMfa && result.sessionToken) {
        setSessionToken(result.sessionToken);
        setMfaStep(true);
      }
    } catch {
      setError("Invalid email or password");
    } finally {
      setLoading(false);
    }
  }

  async function handleMfa(values: { code: string }) {
    setLoading(true);
    setError(null);
    try {
      await verifyMfa(sessionToken, values.code);
    } catch {
      setError("Invalid MFA code. Please try again.");
    } finally {
      setLoading(false);
    }
  }

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
      <Card
        style={{ width: 400 }}
        title={
          <Space>
            <LockOutlined style={{ color: "#375EFD" }} />
            <Typography.Text strong>
              {mfaStep ? "Verify MFA" : "Money Guardian Admin"}
            </Typography.Text>
          </Space>
        }
      >
        {error && (
          <Alert
            message={error}
            type="error"
            showIcon
            closable
            onClose={() => setError(null)}
            style={{ marginBottom: 16 }}
          />
        )}

        {!mfaStep ? (
          <Form layout="vertical" onFinish={handleLogin}>
            <Form.Item
              name="email"
              label="Email"
              rules={[{ required: true, type: "email", message: "Enter a valid email" }]}
            >
              <Input
                prefix={<MailOutlined />}
                placeholder="admin@moneyguardian.co"
                size="large"
              />
            </Form.Item>
            <Form.Item
              name="password"
              label="Password"
              rules={[{ required: true, min: 8, message: "Minimum 8 characters" }]}
            >
              <Input.Password
                prefix={<LockOutlined />}
                placeholder="Password"
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
        ) : (
          <Form layout="vertical" onFinish={handleMfa}>
            <Typography.Paragraph type="secondary" style={{ marginBottom: 16 }}>
              Enter the 6-digit code from your authenticator app.
            </Typography.Paragraph>
            <Form.Item
              name="code"
              label="MFA Code"
              rules={[{ required: true, len: 6, message: "Enter 6-digit code" }]}
            >
              <Input
                prefix={<SafetyCertificateOutlined />}
                placeholder="000000"
                size="large"
                maxLength={6}
                style={{ letterSpacing: 8, textAlign: "center", fontSize: 20 }}
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
                Verify
              </Button>
            </Form.Item>
            <Button
              type="link"
              onClick={() => { setMfaStep(false); setSessionToken(""); }}
              block
            >
              Back to login
            </Button>
          </Form>
        )}
      </Card>
    </div>
  );
}
