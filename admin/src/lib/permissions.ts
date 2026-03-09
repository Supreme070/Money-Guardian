/**
 * Permission constants mirroring backend rbac_service.py.
 */

export const PERMISSIONS = {
  USERS_VIEW: "users.view",
  USERS_MODIFY: "users.modify",
  TENANTS_VIEW: "tenants.view",
  TENANTS_MODIFY: "tenants.modify",
  ANALYTICS_VIEW: "analytics.view",
  NOTIFICATIONS_SEND: "notifications.send",
  IMPERSONATE: "impersonate",
  ADMIN_USERS_MANAGE: "admin_users.manage",
  FEATURE_FLAGS_MANAGE: "feature_flags.manage",
  AUDIT_LOG_VIEW: "audit_log.view",
  BULK_OPERATIONS: "bulk_operations",
  BILLING_MANAGE: "billing.manage",
  APPROVALS_MANAGE: "approvals.manage",
} as const;

export type Permission = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];
