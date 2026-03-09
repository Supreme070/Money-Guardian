/**
 * Approval detail page — full request info, timeline, and action buttons.
 */

import { useState } from "react";
import {
  Card,
  Descriptions,
  Spin,
  Tag,
  Typography,
  Button,
  Space,
  Timeline,
  Modal,
  Input,
  message,
} from "antd";
import {
  ArrowLeftOutlined,
  CheckOutlined,
  CloseOutlined,
  ThunderboltOutlined,
  ClockCircleOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
} from "@ant-design/icons";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchApprovalDetail, reviewApproval, executeApproval } from "@/lib/api";
import { useAdminAuth } from "@/lib/adminAuth";
import { PERMISSIONS } from "@/lib/permissions";
import dayjs from "dayjs";

const STATUS_COLORS: Record<string, string> = {
  pending: "#FBBD5C",
  approved: "#22C55E",
  rejected: "#EF4444",
  expired: "default",
  executed: "#375EFD",
};

export default function ApprovalDetailPage() {
  const { approvalId } = useParams<{ approvalId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { hasPermission, role } = useAdminAuth();
  const canManage = hasPermission(PERMISSIONS.APPROVALS_MANAGE) && role === "super_admin";

  const [reviewModalOpen, setReviewModalOpen] = useState(false);
  const [reviewAction, setReviewAction] = useState<"approved" | "rejected">("approved");
  const [reviewNote, setReviewNote] = useState("");

  const { data: request, isLoading } = useQuery({
    queryKey: ["approval-detail", approvalId],
    queryFn: () => fetchApprovalDetail(approvalId!),
    enabled: !!approvalId,
  });

  const reviewMutation = useMutation({
    mutationFn: (body: { status: "approved" | "rejected"; note: string }) =>
      reviewApproval(approvalId!, { status: body.status, review_note: body.note || undefined }),
    onSuccess: () => {
      message.success("Approval reviewed");
      queryClient.invalidateQueries({ queryKey: ["approval-detail", approvalId] });
      queryClient.invalidateQueries({ queryKey: ["approvals"] });
      queryClient.invalidateQueries({ queryKey: ["approvals-pending-count"] });
      setReviewModalOpen(false);
      setReviewNote("");
    },
    onError: () => message.error("Failed to review approval"),
  });

  const executeMutation = useMutation({
    mutationFn: () => executeApproval(approvalId!),
    onSuccess: () => {
      message.success("Approval executed");
      queryClient.invalidateQueries({ queryKey: ["approval-detail", approvalId] });
      queryClient.invalidateQueries({ queryKey: ["approvals"] });
    },
    onError: () => message.error("Failed to execute approval"),
  });

  if (isLoading || !request) {
    return <Spin size="large" style={{ display: "block", margin: "100px auto" }} />;
  }

  const timelineItems = [
    {
      color: "blue",
      dot: <ClockCircleOutlined />,
      children: (
        <>
          <Typography.Text strong>Created</Typography.Text>
          <br />
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {dayjs(request.created_at).format("MMM D, YYYY h:mm:ss A")}
          </Typography.Text>
          <br />
          <Typography.Text style={{ fontSize: 12 }}>
            By {request.requester_name} ({request.requester_email})
          </Typography.Text>
        </>
      ),
    },
  ];

  if (request.reviewed_at) {
    const isApproved = request.status === "approved" || request.status === "executed";
    timelineItems.push({
      color: isApproved ? "green" : "red",
      dot: isApproved ? <CheckCircleOutlined /> : <CloseCircleOutlined />,
      children: (
        <>
          <Typography.Text strong>
            {isApproved ? "Approved" : "Rejected"}
          </Typography.Text>
          <br />
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {dayjs(request.reviewed_at).format("MMM D, YYYY h:mm:ss A")}
          </Typography.Text>
          {request.review_note && (
            <>
              <br />
              <Typography.Text style={{ fontSize: 12 }}>
                Note: {request.review_note}
              </Typography.Text>
            </>
          )}
        </>
      ),
    });
  }

  if (request.executed_at) {
    timelineItems.push({
      color: "#375EFD",
      dot: <ThunderboltOutlined />,
      children: (
        <>
          <Typography.Text strong>Executed</Typography.Text>
          <br />
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {dayjs(request.executed_at).format("MMM D, YYYY h:mm:ss A")}
          </Typography.Text>
        </>
      ),
    });
  }

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate("/approvals")}>
          Back
        </Button>
      </Space>

      <Card
        title={
          <Space>
            <Typography.Text strong>Approval Request</Typography.Text>
            <Tag color={STATUS_COLORS[request.status]}>
              {request.status.toUpperCase()}
            </Tag>
          </Space>
        }
        extra={
          <Space>
            {request.status === "pending" && canManage && (
              <>
                <Button
                  type="primary"
                  icon={<CheckOutlined />}
                  style={{ background: "#22C55E", borderColor: "#22C55E" }}
                  onClick={() => {
                    setReviewAction("approved");
                    setReviewNote("");
                    setReviewModalOpen(true);
                  }}
                >
                  Approve
                </Button>
                <Button
                  danger
                  icon={<CloseOutlined />}
                  onClick={() => {
                    setReviewAction("rejected");
                    setReviewNote("");
                    setReviewModalOpen(true);
                  }}
                >
                  Reject
                </Button>
              </>
            )}
            {request.status === "approved" && canManage && (
              <Button
                type="primary"
                icon={<ThunderboltOutlined />}
                style={{ background: "#375EFD", borderColor: "#375EFD" }}
                onClick={() => executeMutation.mutate()}
                loading={executeMutation.isPending}
              >
                Execute
              </Button>
            )}
          </Space>
        }
      >
        <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
          <Descriptions.Item label="Action">
            <Tag color="blue">{request.action}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Entity Type">{request.entity_type}</Descriptions.Item>
          <Descriptions.Item label="Entity ID">
            {request.entity_id ? (
              <Typography.Text copyable style={{ fontSize: 12 }}>
                {request.entity_id}
              </Typography.Text>
            ) : (
              "N/A"
            )}
          </Descriptions.Item>
          <Descriptions.Item label="Requester">
            {request.requester_name} ({request.requester_email})
          </Descriptions.Item>
          <Descriptions.Item label="Reason" span={2}>
            {request.reason}
          </Descriptions.Item>
          {request.review_note && (
            <Descriptions.Item label="Review Note" span={2}>
              {request.review_note}
            </Descriptions.Item>
          )}
          <Descriptions.Item label="Expires">
            {dayjs(request.expires_at).format("MMM D, YYYY h:mm A")}
          </Descriptions.Item>
          <Descriptions.Item label="Created">
            {dayjs(request.created_at).format("MMM D, YYYY h:mm A")}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      {Object.keys(request.parameters).length > 0 && (
        <Card title="Parameters" style={{ marginTop: 16 }}>
          <pre
            style={{
              background: "#f5f5f5",
              padding: 16,
              borderRadius: 8,
              fontSize: 12,
              overflow: "auto",
              maxHeight: 300,
            }}
          >
            {JSON.stringify(request.parameters, null, 2)}
          </pre>
        </Card>
      )}

      <Card title="Timeline" style={{ marginTop: 16 }}>
        <Timeline items={timelineItems} />
      </Card>

      <Modal
        title={reviewAction === "approved" ? "Approve Request" : "Reject Request"}
        open={reviewModalOpen}
        onCancel={() => setReviewModalOpen(false)}
        onOk={() => {
          if (reviewAction === "rejected" && reviewNote.length < 3) {
            message.warning("Review note is required when rejecting");
            return;
          }
          reviewMutation.mutate({ status: reviewAction, note: reviewNote });
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
    </>
  );
}
