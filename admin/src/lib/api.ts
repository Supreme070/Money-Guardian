/**
 * Axios API client for the admin portal.
 * All requests include the X-Admin-Key header.
 */

import axios from "axios";
import type {
  AdminAlertItem,
  AdminSubscriptionItem,
  AdminTenantDetail,
  AdminUserConnectionsResponse,
  AdminUserDetail,
  AnalyticsOverview,
  CeleryStatus,
  ConnectionAnalytics,
  ErrorLogResponse,
  PaginatedTenantsResponse,
  PaginatedUsersResponse,
  RevenueAnalytics,
  SignupAnalytics,
  SubscriptionAnalytics,
  SystemHealthDetail,
  TenantStatusUpdateResponse,
  UserStatusUpdateResponse,
} from "./types";

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "",
  headers: { "Content-Type": "application/json" },
});

// Attach admin key from sessionStorage on every request
apiClient.interceptors.request.use((config) => {
  const key = sessionStorage.getItem("admin_key");
  if (key) {
    config.headers["X-Admin-Key"] = key;
  }
  return config;
});

// Redirect to login on 403
apiClient.interceptors.response.use(
  (res) => res,
  (error: unknown) => {
    if (axios.isAxiosError(error) && error.response?.status === 403) {
      sessionStorage.removeItem("admin_key");
      window.location.hash = "#/login";
    }
    return Promise.reject(error);
  },
);

const P = "/api/v1/admin";

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
// Auth verification (test key against /admin/stats)
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
