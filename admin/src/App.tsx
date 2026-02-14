import { HashRouter, Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import AdminLayout from "@/layouts/AdminLayout";
import LoginPage from "@/pages/Login";
import DashboardPage from "@/pages/Dashboard";
import UserListPage from "@/pages/users/UserList";
import UserDetailPage from "@/pages/users/UserDetail";
import TenantListPage from "@/pages/tenants/TenantList";
import TenantDetailPage from "@/pages/tenants/TenantDetail";
import SignupAnalyticsPage from "@/pages/analytics/SignupAnalytics";
import SubscriptionAnalyticsPage from "@/pages/analytics/SubscriptionAnalytics";
import ConnectionAnalyticsPage from "@/pages/analytics/ConnectionAnalytics";
import RevenueAnalyticsPage from "@/pages/analytics/RevenueAnalytics";
import SystemHealthPage from "@/pages/monitoring/SystemHealth";
import ErrorLogPage from "@/pages/monitoring/ErrorLog";
import CeleryTasksPage from "@/pages/monitoring/CeleryTasks";

function ProtectedRoutes() {
  const { isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return (
    <Routes>
      <Route element={<AdminLayout />}>
        <Route index element={<DashboardPage />} />
        <Route path="users" element={<UserListPage />} />
        <Route path="users/:userId" element={<UserDetailPage />} />
        <Route path="tenants" element={<TenantListPage />} />
        <Route path="tenants/:tenantId" element={<TenantDetailPage />} />
        <Route path="analytics/signups" element={<SignupAnalyticsPage />} />
        <Route path="analytics/subscriptions" element={<SubscriptionAnalyticsPage />} />
        <Route path="analytics/connections" element={<ConnectionAnalyticsPage />} />
        <Route path="analytics/revenue" element={<RevenueAnalyticsPage />} />
        <Route path="monitoring/health" element={<SystemHealthPage />} />
        <Route path="monitoring/errors" element={<ErrorLogPage />} />
        <Route path="monitoring/celery" element={<CeleryTasksPage />} />
      </Route>
    </Routes>
  );
}

export default function App() {
  const { isAuthenticated } = useAuth();

  return (
    <HashRouter>
      <Routes>
        <Route
          path="/login"
          element={isAuthenticated ? <Navigate to="/" replace /> : <LoginPage />}
        />
        <Route path="/*" element={<ProtectedRoutes />} />
      </Routes>
    </HashRouter>
  );
}
