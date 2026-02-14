/**
 * Admin authentication context.
 * Uses sessionStorage to persist the admin API key during the browser session.
 */

import {
  createContext,
  useContext,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import React from "react";
import { verifyAdminKey } from "./api";

interface AuthContextValue {
  isAuthenticated: boolean;
  login: (key: string) => Promise<boolean>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(
    () => sessionStorage.getItem("admin_key") !== null,
  );

  const login = useCallback(async (key: string): Promise<boolean> => {
    const valid = await verifyAdminKey(key);
    if (valid) {
      sessionStorage.setItem("admin_key", key);
      setIsAuthenticated(true);
    }
    return valid;
  }, []);

  const logout = useCallback(() => {
    sessionStorage.removeItem("admin_key");
    setIsAuthenticated(false);
  }, []);

  return React.createElement(
    AuthContext.Provider,
    { value: { isAuthenticated, login, logout } },
    children,
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return ctx;
}
