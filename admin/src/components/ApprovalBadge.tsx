/**
 * Header badge showing pending approval count.
 * Auto-refreshes every 30 seconds.
 */

import { Badge } from "antd";
import { CheckSquareOutlined } from "@ant-design/icons";
import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchApprovals } from "@/lib/api";

export default function ApprovalBadge() {
  const navigate = useNavigate();

  const { data } = useQuery({
    queryKey: ["approvals-pending-count"],
    queryFn: () => fetchApprovals({ status: "pending", page: 1, page_size: 1 }),
    staleTime: 15_000,
    refetchInterval: 30_000,
  });

  const pendingCount = data?.pending_count ?? 0;

  return (
    <Badge count={pendingCount} size="small" offset={[-2, 2]}>
      <CheckSquareOutlined
        style={{ fontSize: 18, cursor: "pointer", color: "#6D7F99" }}
        onClick={() => navigate("/approvals")}
      />
    </Badge>
  );
}
