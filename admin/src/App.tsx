import { HashRouter, Routes, Route, Navigate } from "react-router-dom";
import { useAdminAuth } from "@/lib/adminAuth";
import AdminLayout from "@/layouts/AdminLayout";
import LoginPage from "@/pages/auth/LoginPage";
import MfaSetupPage from "@/pages/auth/MfaSetupPage";
import DashboardPage from "@/pages/Dashboard";
import UserListPage from "@/pages/users/UserList";
import UserDetailPage from "@/pages/users/UserDetail";
import TenantListPage from "@/pages/tenants/TenantList";
import TenantDetailPage from "@/pages/tenants/TenantDetail";
import SignupAnalyticsPage from "@/pages/analytics/SignupAnalytics";
import SubscriptionAnalyticsPage from "@/pages/analytics/SubscriptionAnalytics";
import ConnectionAnalyticsPage from "@/pages/analytics/ConnectionAnalytics";
import RevenueAnalyticsPage from "@/pages/analytics/RevenueAnalytics";
import CustomerHealthPage from "@/pages/analytics/CustomerHealth";
import CustomerHealthDetailPage from "@/pages/analytics/CustomerHealthDetail";
import CohortAnalysisPage from "@/pages/analytics/CohortAnalysis";
import RetentionCurvesPage from "@/pages/analytics/RetentionCurves";
import ConversionFunnelPage from "@/pages/analytics/ConversionFunnel";
import FeatureFlagListPage from "@/pages/feature-flags/FeatureFlagList";
import SystemHealthPage from "@/pages/monitoring/SystemHealth";
import ErrorLogPage from "@/pages/monitoring/ErrorLog";
import CeleryTasksPage from "@/pages/monitoring/CeleryTasks";
import AuditLogPage from "@/pages/AuditLog";
import AdminUsersPage from "@/pages/AdminUsers";
import SendNotificationPage from "@/pages/notifications/SendNotification";
import NotificationHistoryPage from "@/pages/notifications/NotificationHistory";
import BillingManagementPage from "@/pages/billing/BillingManagement";
import BulkOperationsPage from "@/pages/bulk/BulkOperations";
import BulkOperationDetailPage from "@/pages/bulk/BulkOperationDetail";
import DataExportPage from "@/pages/export/DataExport";
import ApprovalQueuePage from "@/pages/approvals/ApprovalQueue";
import ApprovalDetailPage from "@/pages/approvals/ApprovalDetail";
import WebhookDashboardPage from "@/pages/webhooks/WebhookDashboard";
import WebhookDetailPage from "@/pages/webhooks/WebhookDetail";

function ProtectedRoutes() {
  const { isAuthenticated } = useAdminAuth();

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
        <Route path="analytics/health" element={<CustomerHealthPage />} />
        <Route path="analytics/health/:userId" element={<CustomerHealthDetailPage />} />
        <Route path="analytics/cohorts" element={<CohortAnalysisPage />} />
        <Route path="analytics/retention" element={<RetentionCurvesPage />} />
        <Route path="analytics/funnel" element={<ConversionFunnelPage />} />
        <Route path="feature-flags" element={<FeatureFlagListPage />} />
        <Route path="monitoring/health" element={<SystemHealthPage />} />
        <Route path="monitoring/errors" element={<ErrorLogPage />} />
        <Route path="monitoring/celery" element={<CeleryTasksPage />} />
        <Route path="audit-log" element={<AuditLogPage />} />
        <Route path="admin-users" element={<AdminUsersPage />} />
        <Route path="notifications/send" element={<SendNotificationPage />} />
        <Route path="notifications/history" element={<NotificationHistoryPage />} />
        <Route path="billing/:tenantId" element={<BillingManagementPage />} />
        <Route path="bulk-operations" element={<BulkOperationsPage />} />
        <Route path="bulk-operations/:operationId" element={<BulkOperationDetailPage />} />
        <Route path="export" element={<DataExportPage />} />
        <Route path="approvals" element={<ApprovalQueuePage />} />
        <Route path="approvals/:approvalId" element={<ApprovalDetailPage />} />
        <Route path="webhooks" element={<WebhookDashboardPage />} />
        <Route path="webhooks/:webhookId" element={<WebhookDetailPage />} />
        <Route path="mfa-setup" element={<MfaSetupPage />} />
      </Route>
    </Routes>
  );
}

export default function App() {
  const { isAuthenticated } = useAdminAuth();

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
