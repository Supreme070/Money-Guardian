/**
 * Feature flag management page — list, toggle, create, edit, delete.
 */

import { useState } from "react";
import {
  Typography,
  Table,
  Tag,
  Button,
  Switch,
  Progress,
  Space,
  Popconfirm,
  message,
} from "antd";
import { PlusOutlined, EditOutlined, DeleteOutlined } from "@ant-design/icons";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchFeatureFlags, updateFeatureFlag, deleteFeatureFlag } from "@/lib/api";
import type { FeatureFlag } from "@/lib/types";
import FeatureFlagEditor from "./FeatureFlagEditor";

const TIER_COLORS: Record<string, string> = {
  free: "default",
  pro: "gold",
  enterprise: "blue",
};

export default function FeatureFlagListPage() {
  const queryClient = useQueryClient();
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingFlag, setEditingFlag] = useState<FeatureFlag | undefined>();

  const { data, isLoading } = useQuery({
    queryKey: ["feature-flags"],
    queryFn: fetchFeatureFlags,
    staleTime: 10_000,
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, is_enabled }: { id: string; is_enabled: boolean }) =>
      updateFeatureFlag(id, { is_enabled }),
    onSuccess: () => {
      message.success("Flag toggled");
      queryClient.invalidateQueries({ queryKey: ["feature-flags"] });
    },
    onError: () => message.error("Failed to toggle flag"),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteFeatureFlag,
    onSuccess: () => {
      message.success("Flag deleted");
      queryClient.invalidateQueries({ queryKey: ["feature-flags"] });
    },
    onError: () => message.error("Failed to delete flag"),
  });

  const handleEdit = (flag: FeatureFlag) => {
    setEditingFlag(flag);
    setEditorOpen(true);
  };

  const handleCreate = () => {
    setEditingFlag(undefined);
    setEditorOpen(true);
  };

  const columns = [
    {
      title: "Key",
      dataIndex: "key",
      key: "key",
      render: (v: string) => (
        <Typography.Text code style={{ fontSize: 12 }}>
          {v}
        </Typography.Text>
      ),
    },
    {
      title: "Name",
      dataIndex: "name",
      key: "name",
      ellipsis: true,
    },
    {
      title: "Status",
      dataIndex: "is_enabled",
      key: "is_enabled",
      width: 90,
      render: (enabled: boolean, record: FeatureFlag) => (
        <Switch
          checked={enabled}
          size="small"
          loading={toggleMutation.isPending}
          onChange={(checked) =>
            toggleMutation.mutate({ id: record.id, is_enabled: checked })
          }
        />
      ),
    },
    {
      title: "Rollout",
      dataIndex: "rollout_percentage",
      key: "rollout_percentage",
      width: 160,
      render: (pct: number) => (
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Progress
            percent={pct}
            size="small"
            showInfo={false}
            strokeColor="#375EFD"
            style={{ flex: 1, margin: 0 }}
          />
          <span style={{ fontSize: 12, whiteSpace: "nowrap" }}>{pct}%</span>
        </div>
      ),
    },
    {
      title: "Tiers",
      dataIndex: "target_tiers",
      key: "target_tiers",
      width: 180,
      render: (tiers: string[] | null) =>
        tiers && tiers.length > 0
          ? tiers.map((t) => (
              <Tag key={t} color={TIER_COLORS[t] || "default"}>
                {t}
              </Tag>
            ))
          : <Typography.Text type="secondary">All</Typography.Text>,
    },
    {
      title: "Actions",
      key: "actions",
      width: 110,
      render: (_: unknown, record: FeatureFlag) => (
        <Space>
          <Button
            size="small"
            icon={<EditOutlined />}
            onClick={() => handleEdit(record)}
          />
          <Popconfirm
            title="Delete this flag?"
            description="This cannot be undone."
            onConfirm={() => deleteMutation.mutate(record.id)}
            okText="Delete"
            okButtonProps={{ danger: true }}
          >
            <Button size="small" icon={<DeleteOutlined />} danger />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Space
        style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}
      >
        <Typography.Title level={3} style={{ margin: 0 }}>
          Feature Flags
        </Typography.Title>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={handleCreate}
          style={{ background: "#375EFD" }}
        >
          Create Flag
        </Button>
      </Space>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={data?.flags}
        loading={isLoading}
        pagination={false}
        scroll={{ x: 800 }}
      />

      <FeatureFlagEditor
        open={editorOpen}
        onClose={() => setEditorOpen(false)}
        flag={editingFlag}
      />
    </div>
  );
}
