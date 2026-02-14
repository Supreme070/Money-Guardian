/**
 * Strictly typed API response shapes for the admin portal.
 * Mirrors the Pydantic schemas in backend/app/schemas/admin.py.
 */

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

export interface PaginationMeta {
  page: number;
  page_size: number;
  total_count: number;
  total_pages: number;
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

export interface AdminUserListItem {
  id: string;
  email: string;
  full_name: string | null;
  tenant_id: string;
  tier: string;
  is_active: boolean;
  is_verified: boolean;
  subscription_count: number;
  connection_count: number;
  created_at: string;
  last_login_at: string | null;
}

export interface PaginatedUsersResponse {
  users: AdminUserListItem[];
  pagination: PaginationMeta;
}

export interface AdminUserDetail {
  id: string;
  email: string;
  full_name: string | null;
  tenant_id: string;
  tier: string;
  is_active: boolean;
  is_verified: boolean;
  push_notifications_enabled: boolean;
  email_notifications_enabled: boolean;
  subscription_tier: string;
  subscription_expires_at: string | null;
  onboarding_completed: boolean;
  created_at: string;
  updated_at: string;
  last_login_at: string | null;
  subscription_count: number;
  bank_connection_count: number;
  email_connection_count: number;
  alert_count: number;
  unread_alert_count: number;
}

export interface UserStatusUpdateResponse {
  user_id: string;
  is_active: boolean;
  reason: string;
}

export interface AdminSubscriptionItem {
  id: string;
  name: string;
  amount: number;
  currency: string;
  billing_cycle: string;
  is_active: boolean;
  is_paused: boolean;
  ai_flag: string;
  source: string;
  next_billing_date: string | null;
  created_at: string;
}

export interface AdminAlertItem {
  id: string;
  alert_type: string;
  severity: string;
  title: string;
  message: string;
  amount: number | null;
  is_read: boolean;
  is_dismissed: boolean;
  created_at: string;
}

export interface AdminBankConnectionItem {
  id: string;
  provider: string;
  institution_name: string;
  status: string;
  error_code: string | null;
  error_message: string | null;
  last_sync_at: string | null;
  account_count: number;
  created_at: string;
}

export interface AdminEmailConnectionItem {
  id: string;
  provider: string;
  email_address: string;
  status: string;
  error_message: string | null;
  last_scan_at: string | null;
  scanned_email_count: number;
  created_at: string;
}

export interface AdminUserConnectionsResponse {
  bank_connections: AdminBankConnectionItem[];
  email_connections: AdminEmailConnectionItem[];
}

// ---------------------------------------------------------------------------
// Tenants
// ---------------------------------------------------------------------------

export interface AdminTenantListItem {
  id: string;
  name: string;
  tier: string;
  status: string;
  user_count: number;
  subscription_count: number;
  created_at: string;
}

export interface PaginatedTenantsResponse {
  tenants: AdminTenantListItem[];
  pagination: PaginationMeta;
}

export interface AdminTenantDetail {
  id: string;
  name: string;
  tier: string;
  status: string;
  stripe_customer_id: string | null;
  user_count: number;
  subscription_count: number;
  bank_connection_count: number;
  email_connection_count: number;
  created_at: string;
  updated_at: string;
}

export interface TenantStatusUpdateResponse {
  tenant_id: string;
  previous_status: string;
  new_status: string;
  reason: string;
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

export interface AnalyticsOverview {
  total_users: number;
  active_users_30d: number;
  new_signups_7d: number;
  new_signups_30d: number;
  pro_users: number;
  enterprise_users: number;
  free_users: number;
  conversion_rate: number;
  total_subscriptions: number;
  total_bank_connections: number;
  total_email_connections: number;
  monthly_tracked_value: number;
}

export interface SignupDataPoint {
  date: string;
  count: number;
}

export interface SignupAnalytics {
  period: string;
  data_points: SignupDataPoint[];
  total: number;
}

export interface TopMerchant {
  name: string;
  count: number;
  total_monthly_value: number;
}

export interface SubscriptionAnalytics {
  total_tracked: number;
  avg_per_user: number;
  total_monthly_value: number;
  total_yearly_value: number;
  top_merchants: TopMerchant[];
  flag_distribution: Record<string, number>;
  source_distribution: Record<string, number>;
}

export interface ProviderStat {
  provider: string;
  total: number;
  connected: number;
  error: number;
  requires_reauth: number;
}

export interface ConnectionAnalytics {
  bank_providers: ProviderStat[];
  email_providers: ProviderStat[];
  bank_success_rate: number;
  email_success_rate: number;
}

export interface RevenueAnalytics {
  tier_breakdown: Record<string, number>;
  total_paid_users: number;
  churn_count_30d: number;
}

// ---------------------------------------------------------------------------
// Monitoring
// ---------------------------------------------------------------------------

export interface ServiceStatus {
  name: string;
  status: "healthy" | "unhealthy";
  latency_ms: number | null;
  error: string | null;
}

export interface SystemHealthDetail {
  services: ServiceStatus[];
  overall_status: "healthy" | "degraded" | "unhealthy";
}

export interface ErrorLogEntry {
  id: string;
  entity_type: "bank_connection" | "email_connection";
  entity_id: string;
  tenant_id: string;
  provider: string;
  institution_or_email: string;
  error_code: string | null;
  error_message: string | null;
  status: string;
  last_attempt_at: string | null;
  created_at: string;
}

export interface ErrorLogResponse {
  errors: ErrorLogEntry[];
  pagination: PaginationMeta;
}

export interface CeleryTaskInfo {
  name: string;
  schedule: string;
  last_run: string | null;
  description: string;
}

export interface CeleryStatus {
  scheduled_tasks: CeleryTaskInfo[];
}

// ---------------------------------------------------------------------------
// Legacy (stats)
// ---------------------------------------------------------------------------

export interface SystemStats {
  total_users: number;
  active_users: number;
  total_tenants: number;
  tier_breakdown: Record<string, number>;
  total_subscriptions: number;
  total_bank_connections: number;
  connected_bank_connections: number;
}
