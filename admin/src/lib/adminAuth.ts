/**
 * Admin JWT authentication context.
 *
 * Replaces the legacy sessionStorage API key approach with proper
 * JWT-based auth, token refresh, and role state.
 */

import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  type ReactNode,
} from "react";
import React from "react";
import { adminLogin, adminVerifyMfa, adminLogout, adminGetMe } from "./api";

export type AdminRole = "super_admin" | "admin" | "support" | "viewer";

interface AdminProfile {
  id: string;
  email: string;
  full_name: string;
  role: AdminRole;
  mfa_enabled: boolean;
}

interface AuthState {
  isAuthenticated: boolean;
  profile: AdminProfile | null;
  accessToken: string | null;
  refreshToken: string | null;
}

interface AuthContextValue {
  isAuthenticated: boolean;
  profile: AdminProfile | null;
  role: AdminRole | null;
  login: (email: string, password: string) => Promise<{ requiresMfa: boolean; sessionToken?: string }>;
  verifyMfa: (sessionToken: string, code: string) => Promise<void>;
  logout: () => Promise<void>;
  getAccessToken: () => string | null;
  hasPermission: (permission: string) => boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const TOKEN_KEY = "mg_admin_tokens";

function loadTokens(): { accessToken: string; refreshToken: string } | null {
  try {
    const raw = sessionStorage.getItem(TOKEN_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function saveTokens(accessToken: string, refreshToken: string): void {
  sessionStorage.setItem(TOKEN_KEY, JSON.stringify({ accessToken, refreshToken }));
}

function clearTokens(): void {
  sessionStorage.removeItem(TOKEN_KEY);
  // Also clear legacy key
  sessionStorage.removeItem("admin_key");
}

// Role -> permission set (mirrors backend rbac_service.py)
const ROLE_PERMISSIONS: Record<AdminRole, Set<string>> = {
  super_admin: new Set([
    "users.view", "users.modify", "tenants.view", "tenants.modify",
    "analytics.view", "notifications.send", "impersonate",
    "admin_users.manage", "feature_flags.manage", "audit_log.view",
    "bulk_operations", "billing.manage", "approvals.manage",
  ]),
  admin: new Set([
    "users.view", "users.modify", "tenants.view", "tenants.modify",
    "analytics.view", "notifications.send", "feature_flags.manage",
    "audit_log.view", "bulk_operations", "billing.manage",
  ]),
  support: new Set([
    "users.view", "users.modify", "tenants.view", "notifications.send",
  ]),
  viewer: new Set([
    "users.view", "tenants.view", "analytics.view",
  ]),
};

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>(() => {
    const tokens = loadTokens();
    return {
      isAuthenticated: tokens !== null,
      profile: null,
      accessToken: tokens?.accessToken ?? null,
      refreshToken: tokens?.refreshToken ?? null,
    };
  });

  // Load profile on mount if tokens exist
  useEffect(() => {
    if (state.accessToken && !state.profile) {
      adminGetMe().then((profile) => {
        setState((prev) => ({ ...prev, profile }));
      }).catch(() => {
        clearTokens();
        setState({ isAuthenticated: false, profile: null, accessToken: null, refreshToken: null });
      });
    }
  }, [state.accessToken]);

  const login = useCallback(async (email: string, password: string) => {
    const response = await adminLogin(email, password);
    if (response.requires_mfa) {
      return { requiresMfa: true, sessionToken: response.refresh_token };
    }
    saveTokens(response.access_token, response.refresh_token);
    const profile = await adminGetMe();
    setState({
      isAuthenticated: true,
      profile,
      accessToken: response.access_token,
      refreshToken: response.refresh_token,
    });
    return { requiresMfa: false };
  }, []);

  const verifyMfa = useCallback(async (sessionToken: string, code: string) => {
    const response = await adminVerifyMfa(sessionToken, code);
    saveTokens(response.access_token, response.refresh_token);
    const profile = await adminGetMe();
    setState({
      isAuthenticated: true,
      profile,
      accessToken: response.access_token,
      refreshToken: response.refresh_token,
    });
  }, []);

  const logout = useCallback(async () => {
    try {
      if (state.refreshToken) {
        await adminLogout(state.refreshToken);
      }
    } catch {
      // Ignore logout errors
    }
    clearTokens();
    setState({ isAuthenticated: false, profile: null, accessToken: null, refreshToken: null });
  }, [state.refreshToken]);

  const getAccessToken = useCallback(() => state.accessToken, [state.accessToken]);

  const hasPermission = useCallback((permission: string): boolean => {
    if (!state.profile) return false;
    const perms = ROLE_PERMISSIONS[state.profile.role];
    return perms?.has(permission) ?? false;
  }, [state.profile]);

  const value: AuthContextValue = {
    isAuthenticated: state.isAuthenticated,
    profile: state.profile,
    role: state.profile?.role ?? null,
    login,
    verifyMfa,
    logout,
    getAccessToken,
    hasPermission,
  };

  return React.createElement(AuthContext.Provider, { value }, children);
}

export function useAdminAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAdminAuth must be used within AdminAuthProvider");
  }
  return ctx;
}
