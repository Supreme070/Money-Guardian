/**
 * Send notification page — compose and send push/email notifications to users.
 */

import { useState } from "react";
import {
  Button,
  Card,
  Col,
  Form,
  Input,
  message,
  Radio,
  Row,
  Select,
  Typography,
} from "antd";
import { SendOutlined } from "@ant-design/icons";
import { useMutation } from "@tanstack/react-query";
import { useSearchParams } from "react-router-dom";
import { sendNotification } from "@/lib/api";
import NotificationPreview from "@/components/NotificationPreview";

type NotificationType = "push" | "email" | "both";
type TargetType = "user" | "tier" | "all";

interface SendNotificationFormValues {
  notification_type: NotificationType;
  target_type: TargetType;
  target_ids_text: string;
  target_tier: string;
  title: string;
  body: string;
}

export default function SendNotificationPage() {
  const [searchParams] = useSearchParams();
  const prefilledUserId = searchParams.get("userId");

  const [form] = Form.useForm<SendNotificationFormValues>();
  const [previewType, setPreviewType] = useState<NotificationType>("push");
  const [previewTitle, setPreviewTitle] = useState("");
  const [previewBody, setPreviewBody] = useState("");

  const targetType = Form.useWatch("target_type", form);

  const mutation = useMutation({
    mutationFn: (values: SendNotificationFormValues) => {
      const payload: {
        notification_type: string;
        target_type: string;
        target_ids?: string[];
        target_tier?: string;
        title: string;
        body: string;
      } = {
        notification_type: values.notification_type,
        target_type: values.target_type,
        title: values.title,
        body: values.body,
      };

      if (values.target_type === "user" && values.target_ids_text) {
        payload.target_ids = values.target_ids_text
          .split(",")
          .map((id) => id.trim())
          .filter(Boolean);
      }
      if (values.target_type === "tier") {
        payload.target_tier = values.target_tier;
      }

      return sendNotification(payload);
    },
    onSuccess: (data) => {
      message.success(`Notification sent! ${data.sent_count} recipients.`);
      form.resetFields();
      setPreviewTitle("");
      setPreviewBody("");
    },
    onError: () => message.error("Failed to send notification"),
  });

  return (
    <div>
      <Typography.Title level={3}>Send Notification</Typography.Title>

      <Row gutter={24}>
        <Col xs={24} lg={14}>
          <Card>
            <Form
              form={form}
              layout="vertical"
              initialValues={{
                notification_type: "push",
                target_type: prefilledUserId ? "user" : "all",
                target_ids_text: prefilledUserId || "",
                target_tier: "free",
              }}
              onFinish={(values) => mutation.mutate(values)}
            >
              <Form.Item
                name="notification_type"
                label="Notification Type"
                rules={[{ required: true }]}
              >
                <Radio.Group
                  onChange={(e) => setPreviewType(e.target.value as NotificationType)}
                >
                  <Radio.Button value="push">Push</Radio.Button>
                  <Radio.Button value="email">Email</Radio.Button>
                  <Radio.Button value="both">Both</Radio.Button>
                </Radio.Group>
              </Form.Item>

              <Form.Item
                name="target_type"
                label="Target"
                rules={[{ required: true }]}
              >
                <Radio.Group>
                  <Radio.Button value="user">Specific Users</Radio.Button>
                  <Radio.Button value="tier">By Tier</Radio.Button>
                  <Radio.Button value="all">All Users</Radio.Button>
                </Radio.Group>
              </Form.Item>

              {targetType === "user" && (
                <Form.Item
                  name="target_ids_text"
                  label="User IDs"
                  rules={[{ required: true, message: "At least one user ID is required" }]}
                  help="Comma-separated user IDs"
                >
                  <Input.TextArea
                    rows={2}
                    placeholder="e.g. abc-123, def-456, ghi-789"
                  />
                </Form.Item>
              )}

              {targetType === "tier" && (
                <Form.Item
                  name="target_tier"
                  label="Tier"
                  rules={[{ required: true }]}
                >
                  <Select
                    options={[
                      { value: "free", label: "Free" },
                      { value: "pro", label: "Pro" },
                      { value: "enterprise", label: "Enterprise" },
                    ]}
                  />
                </Form.Item>
              )}

              <Form.Item
                name="title"
                label="Title"
                rules={[{ required: true, message: "Title is required" }]}
              >
                <Input
                  placeholder="Notification title"
                  maxLength={120}
                  showCount
                  onChange={(e) => setPreviewTitle(e.target.value)}
                />
              </Form.Item>

              <Form.Item
                name="body"
                label="Body"
                rules={[{ required: true, message: "Body is required" }]}
              >
                <Input.TextArea
                  rows={4}
                  placeholder="Notification body text..."
                  maxLength={1000}
                  showCount
                  onChange={(e) => setPreviewBody(e.target.value)}
                />
              </Form.Item>

              <Form.Item>
                <Button
                  type="primary"
                  htmlType="submit"
                  icon={<SendOutlined />}
                  loading={mutation.isPending}
                  size="large"
                  style={{ background: "#375EFD" }}
                >
                  Send Notification
                </Button>
              </Form.Item>
            </Form>
          </Card>
        </Col>

        <Col xs={24} lg={10}>
          <Typography.Text
            type="secondary"
            style={{ display: "block", marginBottom: 12 }}
          >
            Preview
          </Typography.Text>
          <NotificationPreview
            title={previewTitle}
            body={previewBody}
            type={previewType}
          />
        </Col>
      </Row>
    </div>
  );
}
