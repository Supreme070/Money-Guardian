import { useState } from "react";
import {
  Card,
  Col,
  Descriptions,
  Row,
  Spin,
  Tag,
  Typography,
  Button,
  Modal,
  Input,
  Select,
  message,
  Space,
  Statistic,
} from "antd";
import { ArrowLeftOutlined } from "@ant-design/icons";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchTenantDetail, updateTenantStatus, overrideTenantTier } from "@/lib/api";
import dayjs from "dayjs";

export default function TenantDetailPage() {
  const { tenantId } = useParams<{ tenantId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [statusModalOpen, setStatusModalOpen] = useState(false);
  const [tierModalOpen, setTierModalOpen] = useState(false);
  const [newStatus, setNewStatus] = useState("suspended");
  const [newTier, setNewTier] = useState("pro");
  const [reason, setReason] = useState("");

  const { data: tenant, isLoading } = useQuery({
    queryKey: ["tenant-detail", tenantId],
    queryFn: () => fetchTenantDetail(tenantId!),
    enabled: !!tenantId,
  });

  const statusMutation = useMutation({
    mutationFn: () => updateTenantStatus(tenantId!, { status: newStatus, reason }),
    onSuccess: () => {
      message.success("Tenant status updated");
      queryClient.invalidateQueries({ queryKey: ["tenant-detail", tenantId] });
      setStatusModalOpen(false);
      setReason("");
    },
  });

  const tierMutation = useMutation({
    mutationFn: () => overrideTenantTier(tenantId!, { tier: newTier, reason }),
    onSuccess: () => {
      message.success("Tenant tier updated");
      queryClient.invalidateQueries({ queryKey: ["tenant-detail", tenantId] });
      setTierModalOpen(false);
      setReason("");
    },
  });

  if (isLoading || !tenant) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate("/tenants")}>
          Back
        </Button>
      </Space>

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={16}>
          <Card title="Tenant Details">
            <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
              <Descriptions.Item label="Name">{tenant.name}</Descriptions.Item>
              <Descriptions.Item label="Tier">
                <Tag
                  color={
                    tenant.tier === "pro" ? "gold" : tenant.tier === "enterprise" ? "blue" : "default"
                  }
                >
                  {tenant.tier}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Status">
                <Tag
                  color={
                    tenant.status === "active"
                      ? "green"
                      : tenant.status === "suspended"
                        ? "orange"
                        : "red"
                  }
                >
                  {tenant.status}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Stripe Customer">
                {tenant.stripe_customer_id || "—"}
              </Descriptions.Item>
              <Descriptions.Item label="Created">
                {dayjs(tenant.created_at).format("MMM D, YYYY h:mm A")}
              </Descriptions.Item>
              <Descriptions.Item label="Updated">
                {dayjs(tenant.updated_at).format("MMM D, YYYY h:mm A")}
              </Descriptions.Item>
              <Descriptions.Item label="Tenant ID">
                <Typography.Text copyable style={{ fontSize: 12 }}>
                  {tenant.id}
                </Typography.Text>
              </Descriptions.Item>
            </Descriptions>

            <Space style={{ marginTop: 16 }}>
              <Button onClick={() => setTierModalOpen(true)}>Change Tier</Button>
              <Button
                danger={tenant.status === "active"}
                onClick={() => setStatusModalOpen(true)}
              >
                {tenant.status === "active" ? "Suspend" : "Change Status"}
              </Button>
            </Space>
          </Card>
        </Col>

        <Col xs={24} lg={8}>
          <Row gutter={[16, 16]}>
            <Col span={12}>
              <Card><Statistic title="Users" value={tenant.user_count} /></Card>
            </Col>
            <Col span={12}>
              <Card><Statistic title="Subscriptions" value={tenant.subscription_count} /></Card>
            </Col>
            <Col span={12}>
              <Card><Statistic title="Bank Conn." value={tenant.bank_connection_count} /></Card>
            </Col>
            <Col span={12}>
              <Card><Statistic title="Email Conn." value={tenant.email_connection_count} /></Card>
            </Col>
          </Row>
        </Col>
      </Row>

      <Modal
        title="Change Tenant Status"
        open={statusModalOpen}
        onCancel={() => setStatusModalOpen(false)}
        onOk={() => statusMutation.mutate()}
        okButtonProps={{ disabled: reason.length < 3, loading: statusMutation.isPending }}
      >
        <Space direction="vertical" style={{ width: "100%" }}>
          <Select
            value={newStatus}
            onChange={setNewStatus}
            style={{ width: "100%" }}
            options={[
              { value: "active", label: "Active" },
              { value: "suspended", label: "Suspended" },
              { value: "deleted", label: "Deleted" },
            ]}
          />
          <Input.TextArea
            placeholder="Reason (min 3 characters)"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={3}
          />
        </Space>
      </Modal>

      <Modal
        title="Override Tenant Tier"
        open={tierModalOpen}
        onCancel={() => setTierModalOpen(false)}
        onOk={() => tierMutation.mutate()}
        okButtonProps={{ disabled: reason.length < 3, loading: tierMutation.isPending }}
      >
        <Space direction="vertical" style={{ width: "100%" }}>
          <Select
            value={newTier}
            onChange={setNewTier}
            style={{ width: "100%" }}
            options={[
              { value: "free", label: "Free" },
              { value: "pro", label: "Pro" },
              { value: "enterprise", label: "Enterprise" },
            ]}
          />
          <Input.TextArea
            placeholder="Reason (min 3 characters)"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={3}
          />
        </Space>
      </Modal>
    </>
  );
}
