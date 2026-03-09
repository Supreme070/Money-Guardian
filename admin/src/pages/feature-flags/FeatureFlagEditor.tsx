/**
 * Modal form for creating/editing feature flags.
 */

import { useEffect } from "react";
import { Modal, Form, Input, Switch, Select, message } from "antd";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createFeatureFlag, updateFeatureFlag } from "@/lib/api";
import type { FeatureFlag } from "@/lib/types";
import RolloutSlider from "@/components/RolloutSlider";

interface FeatureFlagEditorProps {
  open: boolean;
  onClose: () => void;
  flag?: FeatureFlag;
}

const KEY_PATTERN = /^[a-z0-9_]+$/;

export default function FeatureFlagEditor({ open, onClose, flag }: FeatureFlagEditorProps) {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const isEdit = !!flag;

  useEffect(() => {
    if (open) {
      if (flag) {
        form.setFieldsValue({
          key: flag.key,
          name: flag.name,
          description: flag.description || "",
          is_enabled: flag.is_enabled,
          rollout_percentage: flag.rollout_percentage,
          target_tiers: flag.target_tiers || [],
          target_user_ids: flag.target_user_ids?.join(", ") || "",
        });
      } else {
        form.resetFields();
        form.setFieldsValue({
          is_enabled: false,
          rollout_percentage: 100,
          target_tiers: [],
          target_user_ids: "",
        });
      }
    }
  }, [open, flag, form]);

  const mutation = useMutation({
    mutationFn: (values: Record<string, unknown>) => {
      const payload = {
        ...values,
        target_user_ids:
          typeof values.target_user_ids === "string" && (values.target_user_ids as string).trim()
            ? (values.target_user_ids as string).split(",").map((s: string) => s.trim()).filter(Boolean)
            : null,
        target_tiers:
          Array.isArray(values.target_tiers) && (values.target_tiers as string[]).length > 0
            ? values.target_tiers
            : null,
      };
      return isEdit
        ? updateFeatureFlag(flag!.id, payload)
        : createFeatureFlag(payload);
    },
    onSuccess: () => {
      message.success(isEdit ? "Flag updated" : "Flag created");
      queryClient.invalidateQueries({ queryKey: ["feature-flags"] });
      onClose();
    },
    onError: () => message.error(isEdit ? "Failed to update flag" : "Failed to create flag"),
  });

  return (
    <Modal
      title={isEdit ? "Edit Feature Flag" : "Create Feature Flag"}
      open={open}
      onCancel={onClose}
      onOk={() => form.submit()}
      confirmLoading={mutation.isPending}
      okText={isEdit ? "Save" : "Create"}
      okButtonProps={{ style: { background: "#375EFD" } }}
      width={560}
      destroyOnClose
    >
      <Form
        form={form}
        layout="vertical"
        onFinish={(values) => mutation.mutate(values)}
      >
        <Form.Item
          name="key"
          label="Key"
          rules={[
            { required: true, message: "Key is required" },
            {
              pattern: KEY_PATTERN,
              message: "Lowercase alphanumeric and underscores only",
            },
          ]}
        >
          <Input
            placeholder="e.g. enable_ai_scanning"
            style={{ fontFamily: "monospace" }}
            disabled={isEdit}
          />
        </Form.Item>

        <Form.Item
          name="name"
          label="Name"
          rules={[{ required: true, message: "Name is required" }]}
        >
          <Input placeholder="Human-readable name" />
        </Form.Item>

        <Form.Item name="description" label="Description">
          <Input.TextArea rows={2} placeholder="Optional description" />
        </Form.Item>

        <Form.Item name="is_enabled" label="Enabled" valuePropName="checked">
          <Switch />
        </Form.Item>

        <Form.Item name="rollout_percentage" label="Rollout Percentage">
          <RolloutSlider
            value={form.getFieldValue("rollout_percentage") ?? 100}
            onChange={(v) => form.setFieldsValue({ rollout_percentage: v })}
          />
        </Form.Item>

        <Form.Item name="target_tiers" label="Target Tiers">
          <Select
            mode="multiple"
            placeholder="All tiers (if empty)"
            options={[
              { value: "free", label: "Free" },
              { value: "pro", label: "Pro" },
              { value: "enterprise", label: "Enterprise" },
            ]}
          />
        </Form.Item>

        <Form.Item name="target_user_ids" label="Target User IDs">
          <Input.TextArea
            rows={2}
            placeholder="Comma-separated UUIDs (optional)"
          />
        </Form.Item>
      </Form>
    </Modal>
  );
}
