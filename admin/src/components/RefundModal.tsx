/**
 * Modal for issuing a full or partial refund on a Stripe payment.
 */

import { Form, Input, InputNumber, Modal, Typography, message } from "antd";
import { useMutation } from "@tanstack/react-query";
import { issueRefund } from "@/lib/api";

interface RefundModalProps {
  open: boolean;
  onClose: () => void;
  paymentIntentId: string;
  maxAmount: number;
  currency: string;
}

export default function RefundModal({
  open,
  onClose,
  paymentIntentId,
  maxAmount,
  currency,
}: RefundModalProps) {
  const [form] = Form.useForm<{ amount_cents: number | undefined; reason: string }>();

  const refundMutation = useMutation({
    mutationFn: (values: { amount_cents?: number; reason: string }) =>
      issueRefund({
        payment_intent_id: paymentIntentId,
        amount_cents: values.amount_cents,
        reason: values.reason,
      }),
    onSuccess: () => {
      message.success("Refund issued successfully");
      form.resetFields();
      onClose();
    },
    onError: () => message.error("Failed to issue refund"),
  });

  const handleOk = () => {
    form.validateFields().then((values) => {
      refundMutation.mutate(values);
    });
  };

  return (
    <Modal
      title="Issue Refund"
      open={open}
      onCancel={onClose}
      onOk={handleOk}
      okText="Issue Refund"
      okButtonProps={{
        danger: true,
        loading: refundMutation.isPending,
      }}
    >
      <Typography.Paragraph type="secondary">
        Payment Intent: <Typography.Text code>{paymentIntentId}</Typography.Text>
      </Typography.Paragraph>
      <Typography.Paragraph type="secondary">
        Max refundable: {currency.toUpperCase()} {(maxAmount / 100).toFixed(2)}
      </Typography.Paragraph>

      <Form form={form} layout="vertical">
        <Form.Item
          name="amount_cents"
          label="Amount (cents)"
          help="Leave empty for a full refund"
          rules={[
            {
              type: "number",
              max: maxAmount,
              message: `Cannot exceed ${maxAmount} cents`,
            },
          ]}
        >
          <InputNumber
            style={{ width: "100%" }}
            placeholder={`Full refund: ${maxAmount} cents`}
            min={1}
            max={maxAmount}
          />
        </Form.Item>
        <Form.Item
          name="reason"
          label="Reason"
          rules={[{ required: true, min: 3, message: "Reason is required (min 3 characters)" }]}
        >
          <Input.TextArea rows={3} placeholder="Reason for refund..." />
        </Form.Item>
      </Form>
    </Modal>
  );
}
