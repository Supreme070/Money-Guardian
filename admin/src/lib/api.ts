/**
 * Axios API client for the admin portal.
 *
 * Uses JWT Bearer tokens (with legacy X-Admin-Key fallback).
 */

import axios from "axios";
import type {
  AdminAlertItem,
  AdminSubscriptionItem,
  AdminTenantDetail,
  AdminUserConnectionsResponse,
  AdminUserDetail,
  AnalyticsOverview,
  ApprovalListResponse,
  ApprovalRequest,
  AuditLogResponse,
  BulkOperation,
  BulkOperationListResponse,
  CeleryStatus,
  CohortData,
  ConnectionAnalytics,
  ErrorLogResponse,
  FeatureFlag,
  FeatureFlagListResponse,
  FunnelStep,
  HealthScore,
  HealthScoreListResponse,
  PaginatedTenantsResponse,
  PaginatedUsersResponse,
  RetentionPoint,
  RevenueAnalytics,
  SearchResponse,
  SignupAnalytics,
  SubscriptionAnalytics,
  SystemHealthDetail,
  TenantStatusUpdateResponse,
  UserStatusUpdateResponse,
  AdminLoginResponse,
  AdminTokenResponse,
  AdminProfile,
  AdminUserListResponse,
  AdminNotification,
  NotificationListResponse,
  TenantBillingResponse,
  ImpersonationResponse,
  WebhookEvent,
  WebhookEventListResponse,
  WebhookStats,
} from "./types";

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "",
  headers: { "Content-Type": "application/json" },
});

// Attach JWT Bearer token (or legacy admin key) on every request
apiClient.interceptors.request.use((config) => {
  try {
    const raw = sessionStorage.getItem("mg_admin_tokens");
    if (raw) {
      const { accessToken } = JSON.parse(raw);
      if (accessToken) {
        config.headers["Authorization"] = `Bearer ${accessToken}`;
      }
    } else {
      // Legacy fallback
      const key = sessionStorage.getItem("admin_key");
      if (key) {
        config.headers["X-Admin-Key"] = key;
      }
    }
  } catch {
    // Ignore parse errors
  }
  return config;
});

// Redirect to login on 401/403
apiClient.interceptors.response.use(
  (res) => res,
  (error: unknown) => {
    if (
      axios.isAxiosError(error) &&
      (error.response?.status === 401 || error.response?.status === 403)
    ) {
      sessionStorage.removeItem("mg_admin_tokens");
      sessionStorage.removeItem("admin_key");
      window.location.hash = "#/login";
    }
    return Promise.reject(error);
  },
);

const P = "/api/v1/admin";

// ---------------------------------------------------------------------------
// Admin Auth
// ---------------------------------------------------------------------------

export async function adminLogin(
  email: string,
  password: string,
): Promise<AdminLoginResponse> {
  const { data } = await apiClient.post<AdminLoginResponse>(
    `${P}/auth/login`,
    { email, password },
  );
  return data;
}

export async function adminVerifyMfa(
  sessionToken: string,
  code: string,
): Promise<AdminTokenResponse> {
  const { data } = await apiClient.post<AdminTokenResponse>(
    `${P}/auth/verify-mfa`,
    { session_token: sessionToken, code },
  );
  return data;
}

export async function adminRefreshToken(
  refreshToken: string,
): Promise<AdminTokenResponse> {
  const { data } = await apiClient.post<AdminTokenResponse>(
    `${P}/auth/refresh`,
    { refresh_token: refreshToken },
  );
  return data;
}

export async function adminLogout(refreshToken: string): Promise<void> {
  await apiClient.post(`${P}/auth/logout`, { refresh_token: refreshToken });
}

export async function adminGetMe(): Promise<AdminProfile> {
  const { data } = await apiClient.get<AdminProfile>(`${P}/auth/me`);
  return data;
}

export async function adminSetupMfa(): Promise<{ secret: string; qr_uri: string }> {
  const { data } = await apiClient.post<{ secret: string; qr_uri: string }>(
    `${P}/auth/setup-mfa`,
  );
  return data;
}

export async function adminConfirmMfa(code: string): Promise<{ mfa_enabled: boolean }> {
  const { data } = await apiClient.post<{ mfa_enabled: boolean }>(
    `${P}/auth/confirm-mfa`,
    { code },
  );
  return data;
}

// ---------------------------------------------------------------------------
// Admin User Management
// ---------------------------------------------------------------------------

export async function fetchAdminUsers(): Promise<AdminUserListResponse> {
  const { data } = await apiClient.get<AdminUserListResponse>(`${P}/admin-users`);
  return data;
}

export async function createAdminUser(body: {
  email: string;
  password: string;
  full_name: string;
  role: string;
}): Promise<AdminProfile> {
  const { data } = await apiClient.post<AdminProfile>(`${P}/admin-users`, body);
  return data;
}

export async function updateAdminUser(
  adminId: string,
  body: { full_name?: string; role?: string; is_active?: boolean },
): Promise<AdminProfile> {
  const { data } = await apiClient.put<AdminProfile>(
    `${P}/admin-users/${adminId}`,
    body,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Audit Log
// ---------------------------------------------------------------------------

export async function fetchAuditLog(params?: {
  page?: number;
  page_size?: number;
  action?: string;
  entity_type?: string;
  admin_user_id?: string;
}): Promise<AuditLogResponse> {
  const { data } = await apiClient.get<AuditLogResponse>(`${P}/audit-log`, { params });
  return data;
}

// ---------------------------------------------------------------------------
// User Management
// ---------------------------------------------------------------------------

export async function fetchUsers(params: {
  page?: number;
  page_size?: number;
  search?: string;
  tier?: string;
  is_active?: boolean;
}): Promise<PaginatedUsersResponse> {
  const { data } = await apiClient.get<PaginatedUsersResponse>(`${P}/users`, {
    params,
  });
  return data;
}

export async function fetchUserDetail(
  userId: string,
): Promise<AdminUserDetail> {
  const { data } = await apiClient.get<AdminUserDetail>(
    `${P}/users/${userId}`,
  );
  return data;
}

export async function updateUserStatus(
  userId: string,
  body: { is_active: boolean; reason: string },
): Promise<UserStatusUpdateResponse> {
  const { data } = await apiClient.put<UserStatusUpdateResponse>(
    `${P}/users/${userId}/status`,
    body,
  );
  return data;
}

export async function fetchUserSubscriptions(
  userId: string,
): Promise<AdminSubscriptionItem[]> {
  const { data } = await apiClient.get<AdminSubscriptionItem[]>(
    `${P}/users/${userId}/subscriptions`,
  );
  return data;
}

export async function fetchUserAlerts(
  userId: string,
): Promise<AdminAlertItem[]> {
  const { data } = await apiClient.get<AdminAlertItem[]>(
    `${P}/users/${userId}/alerts`,
  );
  return data;
}

export async function fetchUserConnections(
  userId: string,
): Promise<AdminUserConnectionsResponse> {
  const { data } = await apiClient.get<AdminUserConnectionsResponse>(
    `${P}/users/${userId}/connections`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Tenant Management
// ---------------------------------------------------------------------------

export async function fetchTenants(params: {
  page?: number;
  page_size?: number;
  tier?: string;
  status?: string;
}): Promise<PaginatedTenantsResponse> {
  const { data } = await apiClient.get<PaginatedTenantsResponse>(
    `${P}/tenants`,
    { params },
  );
  return data;
}

export async function fetchTenantDetail(
  tenantId: string,
): Promise<AdminTenantDetail> {
  const { data } = await apiClient.get<AdminTenantDetail>(
    `${P}/tenants/${tenantId}`,
  );
  return data;
}

export async function updateTenantStatus(
  tenantId: string,
  body: { status: string; reason: string },
): Promise<TenantStatusUpdateResponse> {
  const { data } = await apiClient.put<TenantStatusUpdateResponse>(
    `${P}/tenants/${tenantId}/status`,
    body,
  );
  return data;
}

export async function overrideTenantTier(
  tenantId: string,
  body: { tier: string; reason: string },
): Promise<{ tenant_id: string; previous_tier: string; new_tier: string }> {
  const { data } = await apiClient.post<{
    tenant_id: string;
    previous_tier: string;
    new_tier: string;
  }>(`${P}/tenants/${tenantId}/tier`, body);
  return data;
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

export async function fetchAnalyticsOverview(): Promise<AnalyticsOverview> {
  const { data } = await apiClient.get<AnalyticsOverview>(
    `${P}/analytics/overview`,
  );
  return data;
}

export async function fetchSignupAnalytics(params?: {
  period?: string;
  days?: number;
}): Promise<SignupAnalytics> {
  const { data } = await apiClient.get<SignupAnalytics>(
    `${P}/analytics/signups`,
    { params },
  );
  return data;
}

export async function fetchSubscriptionAnalytics(): Promise<SubscriptionAnalytics> {
  const { data } = await apiClient.get<SubscriptionAnalytics>(
    `${P}/analytics/subscriptions`,
  );
  return data;
}

export async function fetchConnectionAnalytics(): Promise<ConnectionAnalytics> {
  const { data } = await apiClient.get<ConnectionAnalytics>(
    `${P}/analytics/connections`,
  );
  return data;
}

export async function fetchRevenueAnalytics(): Promise<RevenueAnalytics> {
  const { data } = await apiClient.get<RevenueAnalytics>(
    `${P}/analytics/revenue`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Monitoring
// ---------------------------------------------------------------------------

export async function fetchSystemHealth(): Promise<SystemHealthDetail> {
  const { data } = await apiClient.get<SystemHealthDetail>(
    `${P}/monitoring/health`,
  );
  return data;
}

export async function fetchErrorLog(params?: {
  page?: number;
  page_size?: number;
  entity_type?: string;
}): Promise<ErrorLogResponse> {
  const { data } = await apiClient.get<ErrorLogResponse>(
    `${P}/monitoring/errors`,
    { params },
  );
  return data;
}

export async function fetchCeleryStatus(): Promise<CeleryStatus> {
  const { data } = await apiClient.get<CeleryStatus>(
    `${P}/monitoring/celery`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

export async function sendNotification(data: {
  notification_type: string;
  target_type: string;
  target_ids?: string[];
  target_tier?: string;
  title: string;
  body: string;
}): Promise<AdminNotification> {
  const { data: result } = await apiClient.post<AdminNotification>(
    `${P}/notifications/`,
    data,
  );
  return result;
}

export async function fetchNotifications(params: {
  page?: number;
  page_size?: number;
}): Promise<NotificationListResponse> {
  const { data } = await apiClient.get<NotificationListResponse>(
    `${P}/notifications/`,
    { params },
  );
  return data;
}

export async function fetchNotificationDetail(
  id: string,
): Promise<AdminNotification> {
  const { data } = await apiClient.get<AdminNotification>(
    `${P}/notifications/${id}`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Billing
// ---------------------------------------------------------------------------

export async function fetchTenantBilling(
  tenantId: string,
): Promise<TenantBillingResponse> {
  const { data } = await apiClient.get<TenantBillingResponse>(
    `${P}/billing/tenants/${tenantId}`,
  );
  return data;
}

export async function issueRefund(data: {
  payment_intent_id: string;
  amount_cents?: number;
  reason: string;
}): Promise<{ refund_id: string; status: string }> {
  const { data: result } = await apiClient.post<{ refund_id: string; status: string }>(
    `${P}/billing/refund`,
    data,
  );
  return result;
}

export async function cancelSubscription(
  subscriptionId: string,
  data: { at_period_end?: boolean; reason: string },
): Promise<{ status: string }> {
  const { data: result } = await apiClient.post<{ status: string }>(
    `${P}/billing/subscriptions/${subscriptionId}/cancel`,
    data,
  );
  return result;
}

export async function grantCredit(
  customerId: string,
  data: { amount_cents: number; description: string },
): Promise<{ balance: number }> {
  const { data: result } = await apiClient.post<{ balance: number }>(
    `${P}/billing/customers/${customerId}/credit`,
    data,
  );
  return result;
}

// ---------------------------------------------------------------------------
// Impersonation
// ---------------------------------------------------------------------------

export async function impersonateUser(
  userId: string,
): Promise<ImpersonationResponse> {
  const { data } = await apiClient.post<ImpersonationResponse>(
    `${P}/users/${userId}/impersonate`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Feature Flags
// ---------------------------------------------------------------------------

export async function fetchFeatureFlags(): Promise<FeatureFlagListResponse> {
  const { data } = await apiClient.get<FeatureFlagListResponse>(`${P}/feature-flags/`);
  return data;
}

export async function createFeatureFlag(
  body: Record<string, unknown>,
): Promise<FeatureFlag> {
  const { data } = await apiClient.post<FeatureFlag>(`${P}/feature-flags/`, body);
  return data;
}

export async function updateFeatureFlag(
  id: string,
  body: Record<string, unknown>,
): Promise<FeatureFlag> {
  const { data } = await apiClient.put<FeatureFlag>(`${P}/feature-flags/${id}`, body);
  return data;
}

export async function deleteFeatureFlag(id: string): Promise<void> {
  await apiClient.delete(`${P}/feature-flags/${id}`);
}

// ---------------------------------------------------------------------------
// Health Scores
// ---------------------------------------------------------------------------

export async function fetchHealthScores(params: {
  page?: number;
  page_size?: number;
  risk_level?: string;
  min_score?: number;
  max_score?: number;
}): Promise<HealthScoreListResponse> {
  const { data } = await apiClient.get<HealthScoreListResponse>(`${P}/health-scores`, {
    params,
  });
  return data;
}

export async function fetchUserHealthHistory(
  userId: string,
): Promise<HealthScore[]> {
  const { data } = await apiClient.get<HealthScore[]>(`${P}/health-scores/${userId}`);
  return data;
}

// ---------------------------------------------------------------------------
// Advanced Analytics
// ---------------------------------------------------------------------------

export async function fetchCohortData(): Promise<CohortData[]> {
  const { data } = await apiClient.get<CohortData[]>(`${P}/analytics/cohorts`);
  return data;
}

export async function fetchFunnelData(): Promise<FunnelStep[]> {
  const { data } = await apiClient.get<FunnelStep[]>(`${P}/analytics/funnel`);
  return data;
}

export async function fetchRetentionData(): Promise<RetentionPoint[]> {
  const { data } = await apiClient.get<RetentionPoint[]>(`${P}/analytics/retention`);
  return data;
}

// ---------------------------------------------------------------------------
// Bulk Operations
// ---------------------------------------------------------------------------

export async function createBulkUserStatus(data: {
  user_ids: string[];
  new_status: string;
  reason: string;
}): Promise<BulkOperation> {
  const { data: result } = await apiClient.post<BulkOperation>(
    `${P}/bulk/user-status`,
    data,
  );
  return result;
}

export async function createBulkTierOverride(data: {
  tenant_ids: string[];
  new_tier: string;
  reason: string;
}): Promise<BulkOperation> {
  const { data: result } = await apiClient.post<BulkOperation>(
    `${P}/bulk/tier-override`,
    data,
  );
  return result;
}

export async function createBulkNotification(data: {
  user_ids: string[];
  notification_type: string;
  title: string;
  body: string;
}): Promise<BulkOperation> {
  const { data: result } = await apiClient.post<BulkOperation>(
    `${P}/bulk/notification`,
    data,
  );
  return result;
}

export async function fetchBulkOperations(params: {
  page?: number;
  page_size?: number;
}): Promise<BulkOperationListResponse> {
  const { data } = await apiClient.get<BulkOperationListResponse>(
    `${P}/bulk/`,
    { params },
  );
  return data;
}

export async function fetchBulkOperation(
  id: string,
): Promise<BulkOperation> {
  const { data } = await apiClient.get<BulkOperation>(`${P}/bulk/${id}`);
  return data;
}

export async function cancelBulkOperation(
  id: string,
): Promise<BulkOperation> {
  const { data } = await apiClient.post<BulkOperation>(
    `${P}/bulk/${id}/cancel`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

export async function requestExport(data: {
  export_type: string;
  format?: string;
  filters?: Record<string, unknown>;
}): Promise<{ export_id: string; status: string }> {
  const { data: result } = await apiClient.post<{
    export_id: string;
    status: string;
  }>(`${P}/export/`, data);
  return result;
}

export function getExportDownloadUrl(exportId: string): string {
  return `${apiClient.defaults.baseURL ?? ""}${P}/export/${exportId}/download`;
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

export async function adminSearch(
  query: string,
  entityTypes?: string[],
): Promise<SearchResponse> {
  const { data } = await apiClient.post<SearchResponse>(`${P}/search`, {
    query,
    entity_types: entityTypes,
  });
  return data;
}

// ---------------------------------------------------------------------------
// Approvals
// ---------------------------------------------------------------------------

export async function fetchApprovals(params: {
  status?: string;
  page?: number;
  page_size?: number;
}): Promise<ApprovalListResponse> {
  const { data } = await apiClient.get<ApprovalListResponse>(`${P}/approvals`, {
    params,
  });
  return data;
}

export async function fetchApprovalDetail(
  id: string,
): Promise<ApprovalRequest> {
  const { data } = await apiClient.get<ApprovalRequest>(
    `${P}/approvals/${id}`,
  );
  return data;
}

export async function createApprovalRequest(body: {
  action: string;
  entity_type: string;
  entity_id?: string;
  parameters?: Record<string, unknown>;
  reason: string;
}): Promise<ApprovalRequest> {
  const { data } = await apiClient.post<ApprovalRequest>(
    `${P}/approvals`,
    body,
  );
  return data;
}

export async function reviewApproval(
  id: string,
  body: { status: "approved" | "rejected"; review_note?: string },
): Promise<ApprovalRequest> {
  const { data } = await apiClient.post<ApprovalRequest>(
    `${P}/approvals/${id}/review`,
    body,
  );
  return data;
}

export async function executeApproval(
  id: string,
): Promise<ApprovalRequest> {
  const { data } = await apiClient.post<ApprovalRequest>(
    `${P}/approvals/${id}/execute`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Webhooks
// ---------------------------------------------------------------------------

export async function fetchWebhookEvents(params: {
  provider?: string;
  event_type?: string;
  status?: string;
  page?: number;
  page_size?: number;
}): Promise<WebhookEventListResponse> {
  const { data } = await apiClient.get<WebhookEventListResponse>(
    `${P}/webhooks`,
    { params },
  );
  return data;
}

export async function fetchWebhookStats(): Promise<WebhookStats> {
  const { data } = await apiClient.get<WebhookStats>(
    `${P}/webhooks/stats`,
  );
  return data;
}

export async function fetchWebhookDetail(
  id: string,
): Promise<WebhookEvent> {
  const { data } = await apiClient.get<WebhookEvent>(
    `${P}/webhooks/${id}`,
  );
  return data;
}

// ---------------------------------------------------------------------------
// Legacy auth verification (kept for backward compat)
// ---------------------------------------------------------------------------

export async function verifyAdminKey(key: string): Promise<boolean> {
  try {
    await apiClient.get(`${P}/stats`, {
      headers: { "X-Admin-Key": key },
    });
    return true;
  } catch {
    return false;
  }
}
