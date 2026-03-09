/**
 * Approval queue page — list and review pending approval requests.
 */

import { useState } from "react";
import {
  Typography,
  Table,
  Tag,
  Button,
  Modal,
  Input,
  Space,
  Tabs,
  message,
  Tooltip,
} from "antd";
import {
  CheckOutlined,
  CloseOutlined,
  ThunderboltOutlined,
  EyeOutlined,
} from "@ant-design/icons";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchApprovals, reviewApproval, executeApproval } from "@/lib/api";
import { useAdminAuth } from "@/lib/adminAuth";
import { PERMISSIONS } from "@/lib/permissions";
import type { ApprovalRequest } from "@/lib/types";
import dayjs from "dayjs";

const STATUS_COLORS: Record<string, string> = {
  pending: "#FBBD5C",
  approved: "#22C55E",
  rejected: "#EF4444",
  expired: "default",
  executed: "#375EFD",
};

export default function ApprovalQueuePage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { hasPermission, role } = useAdminAuth();
  const canManage = hasPermission(PERMISSIONS.APPROVALS_MANAGE) && role === "super_admin";

  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const [reviewModalOpen, setReviewModalOpen] = useState(false);
  const [reviewTarget, setReviewTarget] = useState<ApprovalRequest | null>(null);
  const [reviewAction, setReviewAction] = useState<"approved" | "rejected">("approved");
  const [reviewNote, setReviewNote] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["approvals", page, statusFilter],
    queryFn: () =>
      fetchApprovals({
        status: statusFilter,
        page,
        page_size: 20,
      }),
    staleTime: 10_000,
  });

  const reviewMutation = useMutation({
    mutationFn: ({ id, status, note }: { id: string; status: "approved" | "rejected"; note: string }) =>
      reviewApproval(id, { status, review_note: note || undefined }),
    onSuccess: () => {
      message.success("Approval reviewed");
      queryClient.invalidateQueries({ queryKey: ["approvals"] });
      queryClient.invalidateQueries({ queryKey: ["approvals-pending-count"] });
      setReviewModalOpen(false);
      setReviewNote("");
    },
    onError: () => message.error("Failed to review approval"),
  });

  const executeMutation = useMutation({
    mutationFn: (id: string) => executeApproval(id),
    onSuccess: () => {
      message.success("Approval executed");
      queryClient.invalidateQueries({ queryKey: ["approvals"] });
    },
    onError: () => message.error("Failed to execute approval"),
  });

  function openReview(record: ApprovalRequest, action: "approved" | "rejected") {
    setReviewTarget(record);
    setReviewAction(action);
    setReviewNote("");
    setReviewModalOpen(true);
  }

  const columns = [
    {
      title: "Requester",
      key: "requester",
      width: 200,
      render: (_: unknown, r: ApprovalRequest) => (
        <div>
          <Typography.Text strong>{r.requester_name}</Typography.Text>
          <br />
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {r.requester_email}
          </Typography.Text>
        </div>
      ),
    },
    {
      title: "Action",
      dataIndex: "action",
      key: "action",
      width: 160,
      render: (v: string) => <Tag color="blue">{v}</Tag>,
    },
    {
      title: "Entity",
      key: "entity",
      width: 180,
      render: (_: unknown, r: ApprovalRequest) => (
        <span>
          <Tag>{r.entity_type}</Tag>
          {r.entity_id && (
            <Typography.Text code style={{ fontSize: 11 }}>
              {r.entity_id.slice(0, 8)}...
            </Typography.Text>
          )}
        </span>
      ),
    },
    {
      title: "Reason",
      dataIndex: "reason",
      key: "reason",
      ellipsis: true,
      render: (v: string) => (
        <Typography.Text ellipsis={{ tooltip: v }} style={{ maxWidth: 200, display: "inline-block" }}>
          {v}
        </Typography.Text>
      ),
    },
    {
      title: "Status",
      dataIndex: "status",
      key: "status",
      width: 110,
      render: (status: ApprovalRequest["status"]) => (
        <Tag color={STATUS_COLORS[status]}>{status.toUpperCase()}</Tag>
      ),
    },
    {
      title: "Expires",
      dataIndex: "expires_at",
      key: "expires_at",
      width: 140,
      render: (v: string) => {
        const d = dayjs(v);
        const expired = d.isBefore(dayjs());
        return (
          <Typography.Text type={expired ? "danger" : "secondary"} style={{ fontSize: 12 }}>
            {d.format("MMM D, h:mm A")}
          </Typography.Text>
        );
      },
    },
    {
      title: "Actions",
      key: "actions",
      width: 200,
      render: (_: unknown, record: ApprovalRequest) => (
        <Space>
          <Tooltip title="View details">
            <Button
              size="small"
              icon={<EyeOutlined />}
              onClick={() => navigate(`/approvals/${record.id}`)}
            />
          </Tooltip>
          {record.status === "pending" && canManage && (
            <>
              <Tooltip title="Approve">
                <Button
                  size="small"
                  type="primary"
                  icon={<CheckOutlined />}
                  style={{ background: "#22C55E", borderColor: "#22C55E" }}
                  onClick={() => openReview(record, "approved")}
                />
              </Tooltip>
              <Tooltip title="Reject">
                <Button
                  size="small"
                  danger
                  icon={<CloseOutlined />}
                  onClick={() => openReview(record, "rejected")}
                />
              </Tooltip>
            </>
          )}
          {record.status === "approved" && canManage && (
            <Tooltip title="Execute">
              <Button
                size="small"
                type="primary"
                icon={<ThunderboltOutlined />}
                style={{ background: "#375EFD", borderColor: "#375EFD" }}
                onClick={() => executeMutation.mutate(record.id)}
                loading={executeMutation.isPending}
              />
            </Tooltip>
          )}
        </Space>
      ),
    },
  ];

  const tabItems = [
    { key: "all", label: "All" },
    { key: "pending", label: `Pending (${data?.pending_count ?? 0})` },
    { key: "approved", label: "Approved" },
    { key: "rejected", label: "Rejected" },
  ];

  return (
    <div>
      <Typography.Title level={3}>Approval Queue</Typography.Title>

      <Tabs
        activeKey={statusFilter ?? "all"}
        onChange={(key) => {
          setStatusFilter(key === "all" ? undefined : key);
          setPage(1);
        }}
        items={tabItems}
        style={{ marginBottom: 16 }}
      />

      <Table
        rowKey="id"
        columns={columns}
        dataSource={data?.requests}
        loading={isLoading}
        pagination={{
          current: page,
          pageSize: 20,
          total: data?.total_count ?? 0,
          onChange: setPage,
          showSizeChanger: false,
        }}
        scroll={{ x: 1100 }}
      />

      <Modal
        title={reviewAction === "approved" ? "Approve Request" : "Reject Request"}
        open={reviewModalOpen}
        onCancel={() => setReviewModalOpen(false)}
        onOk={() => {
          if (!reviewTarget) return;
          if (reviewAction === "rejected" && reviewNote.length < 3) {
            message.warning("Review note is required when rejecting");
            return;
          }
          reviewMutation.mutate({
            id: reviewTarget.id,
            status: reviewAction,
            note: reviewNote,
          });
        }}
        okText={reviewAction === "approved" ? "Approve" : "Reject"}
        okButtonProps={{
          danger: reviewAction === "rejected",
          style:
            reviewAction === "approved"
              ? { background: "#22C55E", borderColor: "#22C55E" }
              : undefined,
          loading: reviewMutation.isPending,
          disabled: reviewAction === "rejected" && reviewNote.length < 3,
        }}
      >
        {reviewTarget && (
          <>
            <Typography.Paragraph>
              <strong>Action:</strong> {reviewTarget.action}
            </Typography.Paragraph>
            <Typography.Paragraph>
              <strong>Requester:</strong> {reviewTarget.requester_name} ({reviewTarget.requester_email})
            </Typography.Paragraph>
            <Typography.Paragraph>
              <strong>Reason:</strong> {reviewTarget.reason}
            </Typography.Paragraph>
          </>
        )}
        <Input.TextArea
          placeholder={
            reviewAction === "rejected"
              ? "Review note (required for rejection, min 3 characters)"
              : "Review note (optional)"
          }
          value={reviewNote}
          onChange={(e) => setReviewNote(e.target.value)}
          rows={3}
        />
      </Modal>
    </div>
  );
}
