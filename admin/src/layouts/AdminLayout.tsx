import {
  DashboardOutlined,
  TeamOutlined,
  BankOutlined,
  BarChartOutlined,
  HeartOutlined,
  LogoutOutlined,
  AppstoreOutlined,
  AlertOutlined,
} from "@ant-design/icons";
import { Layout, Menu, Typography, Button, theme } from "antd";
import { Outlet, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "@/lib/auth";

const { Header, Sider, Content } = Layout;

const menuItems = [
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
  {
    key: "analytics-group",
    icon: <BarChartOutlined />,
    label: "Analytics",
    children: [
      { key: "/analytics/signups", label: "Signups & Growth" },
      { key: "/analytics/subscriptions", label: "Subscriptions" },
      { key: "/analytics/connections", label: "Connections" },
      { key: "/analytics/revenue", label: "Revenue" },
    ],
  },
  {
    key: "monitoring-group",
    icon: <HeartOutlined />,
    label: "Monitoring",
    children: [
      { key: "/monitoring/health", label: "System Health" },
      { key: "/monitoring/errors", label: "Error Log" },
      { key: "/monitoring/celery", label: "Celery Tasks" },
    ],
  },
];

export default function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout } = useAuth();
  const { token } = theme.useToken();

  return (
    <Layout style={{ minHeight: "100vh" }}>
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
          defaultOpenKeys={["analytics-group", "monitoring-group"]}
          onClick={({ key }) => {
            if (!key.endsWith("-group")) {
              navigate(key);
            }
          }}
          items={menuItems}
          style={{ background: "transparent", borderRight: 0 }}
        />

        <div style={{ position: "absolute", bottom: 16, left: 16, right: 16 }}>
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
          <AlertOutlined style={{ color: token.colorTextSecondary }} />
        </Header>

        <Content style={{ margin: 24 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
