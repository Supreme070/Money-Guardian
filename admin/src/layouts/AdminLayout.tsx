import {
  DashboardOutlined,
  TeamOutlined,
  BankOutlined,
  BarChartOutlined,
  HeartOutlined,
  LogoutOutlined,
  AppstoreOutlined,
  AlertOutlined,
  AuditOutlined,
  UserSwitchOutlined,
  SafetyCertificateOutlined,
  NotificationOutlined,
  DollarOutlined,
  FlagOutlined,
  ThunderboltOutlined,
  ExportOutlined,
  CheckSquareOutlined,
  ApiOutlined,
} from "@ant-design/icons";
import { Layout, Menu, Typography, Button, Tag, Space, theme } from "antd";
import { Outlet, useNavigate, useLocation } from "react-router-dom";
import { useMemo } from "react";
import { useAdminAuth } from "@/lib/adminAuth";
import { PERMISSIONS } from "@/lib/permissions";
import ImpersonationBanner from "@/components/ImpersonationBanner";
import CommandPalette from "@/components/CommandPalette";
import ApprovalBadge from "@/components/ApprovalBadge";
import type { ItemType } from "antd/es/menu/interface";

const { Header, Sider, Content } = Layout;

const ROLE_COLORS: Record<string, string> = {
  super_admin: "red",
  admin: "blue",
  support: "green",
  viewer: "default",
};

export default function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout, profile, hasPermission } = useAdminAuth();
  const { token } = theme.useToken();

  const menuItems = useMemo(() => {
    const items: ItemType[] = [
      {
        key: "/",
        icon: <DashboardOutlined />,
        label: "Dashboard",
      },
      {
        key: "/users",
        icon: <TeamOutlined />,
        label: "Users",
      },
      {
        key: "/tenants",
        icon: <BankOutlined />,
        label: "Tenants",
      },
    ];

    if (hasPermission(PERMISSIONS.FEATURE_FLAGS_MANAGE)) {
      items.push({
        key: "/feature-flags",
        icon: <FlagOutlined />,
        label: "Feature Flags",
      });
    }

    if (hasPermission(PERMISSIONS.ANALYTICS_VIEW)) {
      items.push({
        key: "analytics-group",
        icon: <BarChartOutlined />,
        label: "Analytics",
        children: [
          { key: "/analytics/signups", label: "Signups & Growth" },
          { key: "/analytics/subscriptions", label: "Subscriptions" },
          { key: "/analytics/connections", label: "Connections" },
          { key: "/analytics/revenue", label: "Revenue" },
          { key: "/analytics/health", label: "Customer Health" },
          { key: "/analytics/cohorts", label: "Cohort Analysis" },
          { key: "/analytics/retention", label: "Retention" },
          { key: "/analytics/funnel", label: "Conversion Funnel" },
        ],
      });
    }

    items.push({
      key: "monitoring-group",
      icon: <HeartOutlined />,
      label: "Monitoring",
      children: [
        { key: "/monitoring/health", label: "System Health" },
        { key: "/monitoring/errors", label: "Error Log" },
        { key: "/monitoring/celery", label: "Celery Tasks" },
      ],
    });

    if (hasPermission(PERMISSIONS.AUDIT_LOG_VIEW)) {
      items.push({
        key: "/audit-log",
        icon: <AuditOutlined />,
        label: "Audit Log",
      });
    }

    if (hasPermission(PERMISSIONS.NOTIFICATIONS_SEND)) {
      items.push({
        key: "notifications-group",
        icon: <NotificationOutlined />,
        label: "Notifications",
        children: [
          { key: "/notifications/send", label: "Send Notification" },
          { key: "/notifications/history", label: "History" },
        ],
      });
    }

    if (hasPermission(PERMISSIONS.BILLING_MANAGE)) {
      items.push({
        key: "/billing",
        icon: <DollarOutlined />,
        label: "Billing",
        disabled: true,
      });
    }

    if (hasPermission(PERMISSIONS.BULK_OPERATIONS)) {
      items.push({
        key: "/bulk-operations",
        icon: <ThunderboltOutlined />,
        label: "Bulk Operations",
      });
    }

    if (hasPermission(PERMISSIONS.ANALYTICS_VIEW)) {
      items.push({
        key: "/export",
        icon: <ExportOutlined />,
        label: "Data Export",
      });
    }

    if (hasPermission(PERMISSIONS.APPROVALS_MANAGE)) {
      items.push({
        key: "/approvals",
        icon: <CheckSquareOutlined />,
        label: "Approvals",
      });
    }

    if (hasPermission(PERMISSIONS.ANALYTICS_VIEW)) {
      items.push({
        key: "/webhooks",
        icon: <ApiOutlined />,
        label: "Webhooks",
      });
    }

    if (hasPermission(PERMISSIONS.ADMIN_USERS_MANAGE)) {
      items.push({
        key: "/admin-users",
        icon: <UserSwitchOutlined />,
        label: "Admin Users",
      });
    }

    items.push({
      key: "/mfa-setup",
      icon: <SafetyCertificateOutlined />,
      label: "MFA Setup",
    });

    return items;
  }, [hasPermission]);

  return (
    <Layout style={{ minHeight: "100vh" }}>
      <CommandPalette />
      <ImpersonationBanner />
      <Sider
        width={240}
        style={{
          background: "#15294A",
          overflow: "auto",
          height: "100vh",
          position: "fixed",
          left: 0,
          top: 0,
          bottom: 0,
        }}
      >
        <div
          style={{
            padding: "20px 24px",
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          <AppstoreOutlined style={{ color: "#375EFD", fontSize: 24 }} />
          <Typography.Text
            strong
            style={{ color: "#fff", fontSize: 16 }}
          >
            MG Admin
          </Typography.Text>
        </div>

        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          defaultOpenKeys={["analytics-group", "monitoring-group", "notifications-group"]}
          onClick={({ key }) => {
            if (!key.endsWith("-group")) {
              navigate(key);
            }
          }}
          items={menuItems}
          style={{ background: "transparent", borderRight: 0 }}
        />

        <div style={{ position: "absolute", bottom: 16, left: 16, right: 16 }}>
          {profile && (
            <div style={{ marginBottom: 12, padding: "0 4px" }}>
              <Typography.Text
                style={{ color: "#fff", fontSize: 13, display: "block" }}
                ellipsis
              >
                {profile.full_name}
              </Typography.Text>
              <Tag
                color={ROLE_COLORS[profile.role] || "default"}
                style={{ marginTop: 4, fontSize: 11 }}
              >
                {profile.role.replace("_", " ").toUpperCase()}
              </Tag>
            </div>
          )}
          <Button
            type="text"
            icon={<LogoutOutlined />}
            onClick={logout}
            block
            style={{ color: "#6D7F99", textAlign: "left" }}
          >
            Logout
          </Button>
        </div>
      </Sider>

      <Layout style={{ marginLeft: 240 }}>
        <Header
          style={{
            background: token.colorBgContainer,
            padding: "0 24px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            borderBottom: `1px solid ${token.colorBorderSecondary}`,
          }}
        >
          <Typography.Text type="secondary">
            Money Guardian Admin Portal
          </Typography.Text>
          <Space size={16}>
            <ApprovalBadge />
            <AlertOutlined style={{ color: token.colorTextSecondary }} />
          </Space>
        </Header>

        <Content style={{ margin: 24 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
