/**
 * Billing management page for a specific tenant.
 * Shows Stripe customer info, subscription details, and invoice history.
 */

import { useState } from "react";
import {
  Button,
  Card,
  Col,
  Descriptions,
  Form,
  Input,
  InputNumber,
  Modal,
  Radio,
  Row,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import {
  ArrowLeftOutlined,
  CreditCardOutlined,
  DollarOutlined,
  StopOutlined,
} from "@ant-design/icons";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchTenantBilling, cancelSubscription, grantCredit } from "@/lib/api";
import RefundModal from "@/components/RefundModal";
import dayjs from "dayjs";

const SUB_STATUS_COLORS: Record<string, string> = {
  active: "green",
  trialing: "blue",
  past_due: "orange",
  canceled: "red",
  unpaid: "red",
  incomplete: "default",
};

const INVOICE_STATUS_COLORS: Record<string, string> = {
  paid: "green",
  open: "blue",
  void: "default",
  uncollectible: "red",
  draft: "default",
};

export default function BillingManagementPage() {
  const { tenantId } = useParams<{ tenantId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [cancelModalOpen, setCancelModalOpen] = useState(false);
  const [cancelAtEnd, setCancelAtEnd] = useState(true);
  const [cancelReason, setCancelReason] = useState("");

  const [creditModalOpen, setCreditModalOpen] = useState(false);
  const [creditForm] = Form.useForm<{ amount_cents: number; description: string }>();

  const [refundTarget, setRefundTarget] = useState<{
    paymentIntentId: string;
    maxAmount: number;
    currency: string;
  } | null>(null);

  const { data: billing, isLoading } = useQuery({
    queryKey: ["tenant-billing", tenantId],
    queryFn: () => fetchTenantBilling(tenantId!),
    enabled: !!tenantId,
  });

  const cancelMutation = useMutation({
    mutationFn: () => {
      if (!billing?.subscription) throw new Error("No subscription");
      return cancelSubscription(billing.subscription.subscription_id, {
        at_period_end: cancelAtEnd,
        reason: cancelReason,
      });
    },
    onSuccess: () => {
      message.success("Subscription cancelled");
      queryClient.invalidateQueries({ queryKey: ["tenant-billing", tenantId] });
      setCancelModalOpen(false);
      setCancelReason("");
    },
    onError: () => message.error("Failed to cancel subscription"),
  });

  const creditMutation = useMutation({
    mutationFn: (values: { amount_cents: number; description: string }) => {
      if (!billing?.customer) throw new Error("No customer");
      return grantCredit(billing.customer.customer_id, values);
    },
    onSuccess: () => {
      message.success("Credit granted");
      queryClient.invalidateQueries({ queryKey: ["tenant-billing", tenantId] });
      setCreditModalOpen(false);
      creditForm.resetFields();
    },
    onError: () => message.error("Failed to grant credit"),
  });

  if (isLoading) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const invoiceColumns = [
    {
      title: "Date",
      dataIndex: "created",
      key: "created",
      width: 160,
      render: (v: number) => dayjs.unix(v).format("MMM D, YYYY h:mm A"),
    },
    {
      title: "Amount Due",
      dataIndex: "amount_due",
      key: "amount_due",
      width: 120,
      render: (v: number, record: { currency: string }) =>
        `${record.currency.toUpperCase()} ${(v / 100).toFixed(2)}`,
    },
    {
      title: "Amount Paid",
      dataIndex: "amount_paid",
      key: "amount_paid",
      width: 120,
      render: (v: number, record: { currency: string }) =>
        `${record.currency.toUpperCase()} ${(v / 100).toFixed(2)}`,
    },
    {
      title: "Status",
      dataIndex: "status",
      key: "status",
      width: 100,
      render: (v: string) => (
        <Tag color={INVOICE_STATUS_COLORS[v] || "default"}>{v.toUpperCase()}</Tag>
      ),
    },
    {
      title: "Actions",
      key: "actions",
      width: 160,
      render: (_: unknown, record: { invoice_id: string; amount_paid: number; currency: string; status: string; hosted_invoice_url: string | null }) => (
        <Space>
          {record.hosted_invoice_url && (
            <Button
              size="small"
              type="link"
              href={record.hosted_invoice_url}
              target="_blank"
            >
              View
            </Button>
          )}
          {record.status === "paid" && record.amount_paid > 0 && (
            <Button
              size="small"
              danger
              onClick={() =>
                setRefundTarget({
                  paymentIntentId: record.invoice_id,
                  maxAmount: record.amount_paid,
                  currency: record.currency,
                })
              }
            >
              Refund
            </Button>
          )}
        </Space>
      ),
    },
  ];

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)}>
          Back
        </Button>
        <Typography.Title level={3} style={{ margin: 0 }}>
          Billing Management
        </Typography.Title>
      </Space>

      <Typography.Text type="secondary" style={{ display: "block", marginBottom: 16 }}>
        Tenant: <Typography.Text copyable style={{ fontSize: 12 }}>{tenantId}</Typography.Text>
      </Typography.Text>

      <Row gutter={[16, 16]}>
        {/* Customer Info */}
        <Col xs={24} lg={12}>
          <Card
            title={
              <span>
                <CreditCardOutlined style={{ marginRight: 8 }} />
                Customer
              </span>
            }
          >
            {billing?.customer ? (
              <Descriptions column={1} size="small" bordered>
                <Descriptions.Item label="Customer ID">
                  <Typography.Text copyable style={{ fontSize: 12 }}>
                    {billing.customer.customer_id}
                  </Typography.Text>
                </Descriptions.Item>
                <Descriptions.Item label="Email">
                  {billing.customer.email}
                </Descriptions.Item>
                <Descriptions.Item label="Name">
                  {billing.customer.name || "—"}
                </Descriptions.Item>
                <Descriptions.Item label="Created">
                  {dayjs.unix(billing.customer.created).format("MMM D, YYYY")}
                </Descriptions.Item>
                <Descriptions.Item label="Payment Method">
                  {billing.customer.default_payment_method || "None"}
                </Descriptions.Item>
              </Descriptions>
            ) : (
              <Typography.Text type="secondary">No Stripe customer found</Typography.Text>
            )}
            {billing?.customer && (
              <Button
                icon={<DollarOutlined />}
                style={{ marginTop: 12 }}
                onClick={() => setCreditModalOpen(true)}
              >
                Grant Credit
              </Button>
            )}
          </Card>
        </Col>

        {/* Subscription */}
        <Col xs={24} lg={12}>
          <Card
            title={
              <span>
                <DollarOutlined style={{ marginRight: 8 }} />
                Subscription
              </span>
            }
          >
            {billing?.subscription ? (
              <>
                <Descriptions column={1} size="small" bordered>
                  <Descriptions.Item label="Subscription ID">
                    <Typography.Text copyable style={{ fontSize: 12 }}>
                      {billing.subscription.subscription_id}
                    </Typography.Text>
                  </Descriptions.Item>
                  <Descriptions.Item label="Status">
                    <Tag color={SUB_STATUS_COLORS[billing.subscription.status] || "default"}>
                      {billing.subscription.status.toUpperCase()}
                    </Tag>
                    {billing.subscription.cancel_at_period_end && (
                      <Tag color="orange" style={{ marginLeft: 4 }}>Cancels at period end</Tag>
                    )}
                  </Descriptions.Item>
                  <Descriptions.Item label="Amount">
                    {(billing.subscription.plan_amount / 100).toFixed(2)}{" "}
                    / {billing.subscription.plan_interval}
                  </Descriptions.Item>
                  <Descriptions.Item label="Current Period">
                    {dayjs.unix(billing.subscription.current_period_start).format("MMM D")}
                    {" - "}
                    {dayjs.unix(billing.subscription.current_period_end).format("MMM D, YYYY")}
                  </Descriptions.Item>
                </Descriptions>
                {billing.subscription.status === "active" && !billing.subscription.cancel_at_period_end && (
                  <Button
                    danger
                    icon={<StopOutlined />}
                    style={{ marginTop: 12 }}
                    onClick={() => setCancelModalOpen(true)}
                  >
                    Cancel Subscription
                  </Button>
                )}
              </>
            ) : (
              <Typography.Text type="secondary">No active subscription</Typography.Text>
            )}
          </Card>
        </Col>
      </Row>

      {/* Invoices */}
      <Card title="Invoices" style={{ marginTop: 16 }}>
        <Table
          rowKey="invoice_id"
          columns={invoiceColumns}
          dataSource={billing?.invoices || []}
          pagination={{ pageSize: 10 }}
          size="small"
          scroll={{ x: 700 }}
        />
      </Card>

      {/* Cancel Subscription Modal */}
      <Modal
        title="Cancel Subscription"
        open={cancelModalOpen}
        onCancel={() => setCancelModalOpen(false)}
        onOk={() => cancelMutation.mutate()}
        okText="Cancel Subscription"
        okButtonProps={{
          danger: true,
          disabled: cancelReason.length < 3,
          loading: cancelMutation.isPending,
        }}
      >
        <Space direction="vertical" style={{ width: "100%" }}>
          <Typography.Paragraph>
            How should the cancellation be handled?
          </Typography.Paragraph>
          <Radio.Group value={cancelAtEnd} onChange={(e) => setCancelAtEnd(e.target.value)}>
            <Radio value={true}>Cancel at end of billing period</Radio>
            <Radio value={false}>Cancel immediately</Radio>
          </Radio.Group>
          <Input.TextArea
            placeholder="Reason for cancellation (min 3 characters)"
            value={cancelReason}
            onChange={(e) => setCancelReason(e.target.value)}
            rows={3}
          />
        </Space>
      </Modal>

      {/* Grant Credit Modal */}
      <Modal
        title="Grant Credit"
        open={creditModalOpen}
        onCancel={() => setCreditModalOpen(false)}
        onOk={() => creditForm.validateFields().then((v) => creditMutation.mutate(v))}
        okButtonProps={{ loading: creditMutation.isPending }}
        okText="Grant Credit"
      >
        <Form form={creditForm} layout="vertical">
          <Form.Item
            name="amount_cents"
            label="Amount (cents)"
            rules={[{ required: true, type: "number", min: 1, message: "Amount is required" }]}
          >
            <InputNumber style={{ width: "100%" }} min={1} placeholder="e.g. 500 = $5.00" />
          </Form.Item>
          <Form.Item
            name="description"
            label="Description"
            rules={[{ required: true, min: 3, message: "Description is required" }]}
          >
            <Input.TextArea rows={2} placeholder="Reason for credit..." />
          </Form.Item>
        </Form>
      </Modal>

      {/* Refund Modal */}
      {refundTarget && (
        <RefundModal
          open={!!refundTarget}
          onClose={() => setRefundTarget(null)}
          paymentIntentId={refundTarget.paymentIntentId}
          maxAmount={refundTarget.maxAmount}
          currency={refundTarget.currency}
        />
      )}
    </>
  );
}
