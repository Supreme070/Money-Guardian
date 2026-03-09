/**
 * MFA setup page — generate TOTP secret and verify.
 */

import { useState } from "react";
import { Card, Typography, Button, Input, Form, Alert, Space, Steps, message } from "antd";
import { SafetyCertificateOutlined, CheckCircleOutlined } from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { adminSetupMfa, adminConfirmMfa } from "@/lib/api";

export default function MfaSetupPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState(0);
  const [secret, setSecret] = useState("");
  const [qrUri, setQrUri] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleGenerate() {
    setLoading(true);
    setError(null);
    try {
      const result = await adminSetupMfa();
      setSecret(result.secret);
      setQrUri(result.qr_uri);
      setStep(1);
    } catch {
      setError("Failed to generate MFA secret");
    } finally {
      setLoading(false);
    }
  }

  async function handleVerify(values: { code: string }) {
    setLoading(true);
    setError(null);
    try {
      await adminConfirmMfa(values.code);
      setStep(2);
      message.success("MFA enabled successfully");
    } catch {
      setError("Invalid verification code. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 500, margin: "0 auto" }}>
      <Typography.Title level={3}>Setup Two-Factor Authentication</Typography.Title>

      <Steps
        current={step}
        items={[
          { title: "Generate" },
          { title: "Verify" },
          { title: "Done" },
        ]}
        style={{ marginBottom: 24 }}
      />

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

      {step === 0 && (
        <Card>
          <Typography.Paragraph>
            Two-factor authentication adds an extra layer of security to your admin account.
            You&apos;ll need an authenticator app like Google Authenticator or Authy.
          </Typography.Paragraph>
          <Button
            type="primary"
            onClick={handleGenerate}
            loading={loading}
            icon={<SafetyCertificateOutlined />}
            style={{ background: "#375EFD" }}
          >
            Generate Secret
          </Button>
        </Card>
      )}

      {step === 1 && (
        <Card>
          <Space direction="vertical" style={{ width: "100%" }}>
            <Typography.Paragraph>
              Scan this QR code with your authenticator app, or manually enter the secret:
            </Typography.Paragraph>

            <div style={{ textAlign: "center", padding: 16 }}>
              <img
                src={`https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(qrUri)}`}
                alt="MFA QR Code"
                width={200}
                height={200}
              />
            </div>

            <Typography.Text code copyable style={{ display: "block", textAlign: "center" }}>
              {secret}
            </Typography.Text>

            <Form layout="vertical" onFinish={handleVerify} style={{ marginTop: 16 }}>
              <Form.Item
                name="code"
                label="Verification Code"
                rules={[{ required: true, len: 6, message: "Enter 6-digit code" }]}
              >
                <Input
                  placeholder="000000"
                  maxLength={6}
                  size="large"
                  style={{ letterSpacing: 8, textAlign: "center", fontSize: 20 }}
                />
              </Form.Item>
              <Button
                type="primary"
                htmlType="submit"
                loading={loading}
                block
                style={{ background: "#375EFD" }}
              >
                Verify & Enable MFA
              </Button>
            </Form>
          </Space>
        </Card>
      )}

      {step === 2 && (
        <Card>
          <div style={{ textAlign: "center" }}>
            <CheckCircleOutlined style={{ fontSize: 48, color: "#22C55E", marginBottom: 16 }} />
            <Typography.Title level={4}>MFA Enabled</Typography.Title>
            <Typography.Paragraph>
              Your account is now protected with two-factor authentication.
            </Typography.Paragraph>
            <Button type="primary" onClick={() => navigate("/")} style={{ background: "#375EFD" }}>
              Go to Dashboard
            </Button>
          </div>
        </Card>
      )}
    </div>
  );
}
