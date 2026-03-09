/**
 * Wraps content that requires a specific permission.
 * Renders nothing (or a fallback) if the current admin lacks the permission.
 */

import type { ReactNode } from "react";
import { useAdminAuth } from "@/lib/adminAuth";

interface RoleGuardProps {
  permission: string;
  children: ReactNode;
  fallback?: ReactNode;
}

export default function RoleGuard({ permission, children, fallback = null }: RoleGuardProps) {
  const { hasPermission } = useAdminAuth();

  if (!hasPermission(permission)) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}
