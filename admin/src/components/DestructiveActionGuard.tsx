/**
 * Guard for destructive admin actions.
 *
 * - super_admin: executes directly (with confirmation modal)
 * - Other roles: creates an approval request instead
 */

import { useState } from "react";
import { Modal, Input, message, Typography } from "antd";
import { useMutation } from "@tanstack/react-query";
import { useAdminAuth } from "@/lib/adminAuth";
import { createApprovalRequest } from "@/lib/api";

interface GuardParams {
  reason: string;
}

interface DestructiveActionGuardProps {
  action: string;
  entityType: string;
  entityId: string;
  onExecute: () => void;
  children: (props: { guard: (params: GuardParams) => void }) => React.ReactNode;
}

export default function DestructiveActionGuard({
  action,
  entityType,
  entityId,
  onExecute,
  children,
}: DestructiveActionGuardProps) {
  const { role } = useAdminAuth();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [approvalReason, setApprovalReason] = useState("");

  const approvalMutation = useMutation({
    mutationFn: (reason: string) =>
      createApprovalRequest({
        action,
        entity_type: entityType,
        entity_id: entityId,
        reason,
      }),
    onSuccess: () => {
      message.success("Approval request submitted. A super admin will review it.");
      setConfirmOpen(false);
      setApprovalReason("");
    },
    onError: () => {
      message.error("Failed to create approval request");
    },
  });

  function guard(params: GuardParams) {
    if (role === "super_admin") {
      // Super admin: confirm and execute directly
      Modal.confirm({
        title: "Confirm Destructive Action",
        content: (
          <>
            <Typography.Paragraph>
              You are about to perform: <strong>{action}</strong> on {entityType} {entityId.slice(0, 8)}...
            </Typography.Paragraph>
            <Typography.Paragraph type="secondary">
              Reason: {params.reason}
            </Typography.Paragraph>
          </>
        ),
        okText: "Execute",
        okButtonProps: { danger: true },
        onOk: () => {
          onExecute();
        },
      });
    } else {
      // Non-super_admin: create approval request
      setApprovalReason(params.reason);
      setConfirmOpen(true);
    }
  }

  return (
    <>
      {children({ guard })}

      <Modal
        title="Request Approval"
        open={confirmOpen}
        onCancel={() => setConfirmOpen(false)}
        onOk={() => approvalMutation.mutate(approvalReason)}
        okText="Submit for Approval"
        okButtonProps={{
          disabled: approvalReason.length < 3,
          loading: approvalMutation.isPending,
        }}
      >
        <Typography.Paragraph>
          This action requires super admin approval. Your request will be reviewed.
        </Typography.Paragraph>
        <Typography.Paragraph type="secondary">
          Action: <strong>{action}</strong> on {entityType}
        </Typography.Paragraph>
        <Input.TextArea
          placeholder="Reason for this action (min 3 characters)"
          value={approvalReason}
          onChange={(e) => setApprovalReason(e.target.value)}
          rows={3}
        />
      </Modal>
    </>
  );
}
