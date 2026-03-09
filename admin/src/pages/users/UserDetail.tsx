import { useState } from "react";
import {
  Card,
  Col,
  Descriptions,
  Row,
  Spin,
  Table,
  Tabs,
  Tag,
  Typography,
  Button,
  Modal,
  Input,
  message,
  Space,
  Statistic,
} from "antd";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchUserDetail,
  fetchUserSubscriptions,
  fetchUserAlerts,
  fetchUserConnections,
  updateUserStatus,
  impersonateUser,
  fetchUserHealthHistory,
} from "@/lib/api";
import { useAdminAuth } from "@/lib/adminAuth";
import { PERMISSIONS } from "@/lib/permissions";
import { setImpersonation } from "@/components/ImpersonationBanner";
import HealthScoreBadge from "@/components/HealthScoreBadge";
import dayjs from "dayjs";
import { ArrowLeftOutlined, UserSwitchOutlined, NotificationOutlined } from "@ant-design/icons";
import DestructiveActionGuard from "@/components/DestructiveActionGuard";

export default function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { hasPermission } = useAdminAuth();
  const [statusReason, setStatusReason] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [impersonateModalOpen, setImpersonateModalOpen] = useState(false);

  const { data: user, isLoading } = useQuery({
    queryKey: ["user-detail", userId],
    queryFn: () => fetchUserDetail(userId!),
    enabled: !!userId,
  });

  const { data: subs } = useQuery({
    queryKey: ["user-subs", userId],
    queryFn: () => fetchUserSubscriptions(userId!),
    enabled: !!userId,
  });

  const { data: alerts } = useQuery({
    queryKey: ["user-alerts", userId],
    queryFn: () => fetchUserAlerts(userId!),
    enabled: !!userId,
  });

  const { data: connections } = useQuery({
    queryKey: ["user-connections", userId],
    queryFn: () => fetchUserConnections(userId!),
    enabled: !!userId,
  });

  const { data: healthHistory } = useQuery({
    queryKey: ["health-history", userId],
    queryFn: () => fetchUserHealthHistory(userId!),
    enabled: !!userId,
  });

  const latestHealth =
    healthHistory && healthHistory.length > 0
      ? healthHistory[healthHistory.length - 1]
      : null;

  const statusMutation = useMutation({
    mutationFn: (body: { is_active: boolean; reason: string }) =>
      updateUserStatus(userId!, body),
    onSuccess: () => {
      message.success("User status updated");
      queryClient.invalidateQueries({ queryKey: ["user-detail", userId] });
      setModalOpen(false);
      setStatusReason("");
    },
  });

  const impersonateMutation = useMutation({
    mutationFn: () => impersonateUser(userId!),
    onSuccess: (data) => {
      setImpersonation(data);
      message.success(`Now impersonating ${data.user_email}`);
      setImpersonateModalOpen(false);
    },
    onError: () => message.error("Failed to impersonate user"),
  });

  if (isLoading || !user) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate("/users")}>
          Back
        </Button>
      </Space>

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={16}>
          <Card title="User Profile">
            <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
              <Descriptions.Item label="Email">{user.email}</Descriptions.Item>
              <Descriptions.Item label="Name">{user.full_name || "—"}</Descriptions.Item>
              <Descriptions.Item label="Status">
                <Tag color={user.is_active ? "green" : "red"}>
                  {user.is_active ? "Active" : "Inactive"}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Tier">
                <Tag color={user.tier === "pro" ? "gold" : user.tier === "enterprise" ? "blue" : "default"}>
                  {user.tier}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Verified">
                {user.is_verified ? "Yes" : "No"}
              </Descriptions.Item>
              <Descriptions.Item label="Onboarding">
                {user.onboarding_completed ? "Complete" : "Incomplete"}
              </Descriptions.Item>
              <Descriptions.Item label="Joined">
                {dayjs(user.created_at).format("MMM D, YYYY h:mm A")}
              </Descriptions.Item>
              <Descriptions.Item label="Last Login">
                {user.last_login_at
                  ? dayjs(user.last_login_at).format("MMM D, YYYY h:mm A")
                  : "Never"}
              </Descriptions.Item>
              <Descriptions.Item label="Tenant ID">
                <Typography.Text copyable style={{ fontSize: 12 }}>
                  {user.tenant_id}
                </Typography.Text>
              </Descriptions.Item>
              <Descriptions.Item label="Push Notifications">
                {user.push_notifications_enabled ? "Enabled" : "Disabled"}
              </Descriptions.Item>
            </Descriptions>

            <Space style={{ marginTop: 16 }}>
              {user.is_active ? (
                <DestructiveActionGuard
                  action="user.deactivate"
                  entityType="user"
                  entityId={userId!}
                  onExecute={() => setModalOpen(true)}
                >
                  {({ guard }) => (
                    <Button
                      danger
                      onClick={() => guard({ reason: "User deactivation requested" })}
                    >
                      Deactivate User
                    </Button>
                  )}
                </DestructiveActionGuard>
              ) : (
                <Button
                  type="primary"
                  onClick={() => setModalOpen(true)}
                >
                  Activate User
                </Button>
              )}
              {hasPermission(PERMISSIONS.IMPERSONATE) && (
                <Button
                  danger
                  icon={<UserSwitchOutlined />}
                  onClick={() => setImpersonateModalOpen(true)}
                >
                  Impersonate User
                </Button>
              )}
              {hasPermission(PERMISSIONS.NOTIFICATIONS_SEND) && (
                <Button
                  icon={<NotificationOutlined />}
                  onClick={() => navigate(`/notifications/send?userId=${userId}`)}
                >
                  Send Notification
                </Button>
              )}
            </Space>
          </Card>
        </Col>

        <Col xs={24} lg={8}>
          <Row gutter={[16, 16]}>
            {latestHealth && (
              <Col span={24}>
                <Card>
                  <Space align="center">
                    <HealthScoreBadge
                      score={latestHealth.score}
                      risk_level={latestHealth.risk_level}
                    />
                    <div>
                      <Typography.Text strong>Health Score</Typography.Text>
                      <br />
                      <Typography.Text type="secondary" style={{ fontSize: 12 }}>
                        {latestHealth.risk_level.replace("_", " ")} &middot;{" "}
                        {dayjs(latestHealth.snapshot_date).format("MMM D")}
                      </Typography.Text>
                    </div>
                  </Space>
                </Card>
              </Col>
            )}
            <Col span={12}>
              <Card>
                <Statistic title="Subscriptions" value={user.subscription_count} />
              </Card>
            </Col>
            <Col span={12}>
              <Card>
                <Statistic title="Alerts" value={user.alert_count} />
              </Card>
            </Col>
            <Col span={12}>
              <Card>
                <Statistic title="Bank Conn." value={user.bank_connection_count} />
              </Card>
            </Col>
            <Col span={12}>
              <Card>
                <Statistic title="Email Conn." value={user.email_connection_count} />
              </Card>
            </Col>
          </Row>
        </Col>
      </Row>

      <Card style={{ marginTop: 16 }}>
        <Tabs
          items={[
            {
              key: "subs",
              label: `Subscriptions (${subs?.length || 0})`,
              children: (
                <Table
                  dataSource={subs}
                  rowKey="id"
                  size="small"
                  pagination={{ pageSize: 10 }}
                  columns={[
                    { title: "Name", dataIndex: "name", ellipsis: true },
                    {
                      title: "Amount",
                      dataIndex: "amount",
                      width: 100,
                      render: (v: number, r) => `${r.currency} ${v.toFixed(2)}`,
                    },
                    { title: "Cycle", dataIndex: "billing_cycle", width: 90 },
                    {
                      title: "Status",
                      dataIndex: "is_active",
                      width: 80,
                      render: (a: boolean) => (
                        <Tag color={a ? "green" : "default"}>{a ? "Active" : "Inactive"}</Tag>
                      ),
                    },
                    {
                      title: "AI Flag",
                      dataIndex: "ai_flag",
                      width: 100,
                      render: (f: string) =>
                        f !== "none" ? <Tag color="orange">{f}</Tag> : "—",
                    },
                    { title: "Source", dataIndex: "source", width: 80 },
                  ]}
                />
              ),
            },
            {
              key: "alerts",
              label: `Alerts (${alerts?.length || 0})`,
              children: (
                <Table
                  dataSource={alerts}
                  rowKey="id"
                  size="small"
                  pagination={{ pageSize: 10 }}
                  columns={[
                    { title: "Title", dataIndex: "title", ellipsis: true },
                    {
                      title: "Severity",
                      dataIndex: "severity",
                      width: 90,
                      render: (s: string) => (
                        <Tag
                          color={
                            s === "critical" ? "red" : s === "warning" ? "orange" : "blue"
                          }
                        >
                          {s}
                        </Tag>
                      ),
                    },
                    { title: "Type", dataIndex: "alert_type", width: 140 },
                    {
                      title: "Read",
                      dataIndex: "is_read",
                      width: 60,
                      render: (r: boolean) => (r ? "Yes" : "No"),
                    },
                    {
                      title: "Date",
                      dataIndex: "created_at",
                      width: 110,
                      render: (v: string) => dayjs(v).format("MMM D, YYYY"),
                    },
                  ]}
                />
              ),
            },
            {
              key: "connections",
              label: `Connections (${
                (connections?.bank_connections.length || 0) +
                (connections?.email_connections.length || 0)
              })`,
              children: (
                <>
                  <Typography.Text strong style={{ display: "block", marginBottom: 8 }}>
                    Bank Connections
                  </Typography.Text>
                  <Table
                    dataSource={connections?.bank_connections}
                    rowKey="id"
                    size="small"
                    pagination={false}
                    columns={[
                      { title: "Institution", dataIndex: "institution_name" },
                      { title: "Provider", dataIndex: "provider", width: 80 },
                      {
                        title: "Status",
                        dataIndex: "status",
                        width: 110,
                        render: (s: string) => (
                          <Tag color={s === "connected" ? "green" : s === "error" ? "red" : "orange"}>
                            {s}
                          </Tag>
                        ),
                      },
                      { title: "Accounts", dataIndex: "account_count", width: 80, align: "center" },
                    ]}
                  />

                  <Typography.Text strong style={{ display: "block", margin: "16px 0 8px" }}>
                    Email Connections
                  </Typography.Text>
                  <Table
                    dataSource={connections?.email_connections}
                    rowKey="id"
                    size="small"
                    pagination={false}
                    columns={[
                      { title: "Email", dataIndex: "email_address" },
                      { title: "Provider", dataIndex: "provider", width: 80 },
                      {
                        title: "Status",
                        dataIndex: "status",
                        width: 110,
                        render: (s: string) => (
                          <Tag color={s === "connected" ? "green" : s === "error" ? "red" : "orange"}>
                            {s}
                          </Tag>
                        ),
                      },
                      { title: "Scanned", dataIndex: "scanned_email_count", width: 80, align: "center" },
                    ]}
                  />
                </>
              ),
            },
          ]}
        />
      </Card>

      <Modal
        title={user.is_active ? "Deactivate User" : "Activate User"}
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        onOk={() =>
          statusMutation.mutate({
            is_active: !user.is_active,
            reason: statusReason,
          })
        }
        okButtonProps={{ disabled: statusReason.length < 3, loading: statusMutation.isPending }}
      >
        <Typography.Paragraph>
          {user.is_active
            ? `This will deactivate ${user.email}. They will not be able to log in.`
            : `This will reactivate ${user.email}.`}
        </Typography.Paragraph>
        <Input.TextArea
          placeholder="Reason (required, min 3 characters)"
          value={statusReason}
          onChange={(e) => setStatusReason(e.target.value)}
          rows={3}
        />
      </Modal>

      <Modal
        title="Impersonate User"
        open={impersonateModalOpen}
        onCancel={() => setImpersonateModalOpen(false)}
        onOk={() => impersonateMutation.mutate()}
        okText="Start Impersonation"
        okButtonProps={{
          danger: true,
          loading: impersonateMutation.isPending,
        }}
      >
        <Typography.Paragraph>
          Are you sure you want to impersonate <strong>{user.email}</strong>?
        </Typography.Paragraph>
        <Typography.Paragraph type="secondary">
          This action is logged in the audit trail. You will receive a temporary
          token to view the app as this user. The session will expire automatically.
        </Typography.Paragraph>
      </Modal>
    </>
  );
}
