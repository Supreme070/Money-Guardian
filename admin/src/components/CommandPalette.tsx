/**
 * Command palette (Cmd+K / Ctrl+K) for global search and quick navigation.
 */

import { useState, useEffect, useCallback, useRef } from "react";
import { Modal, Input, List, Tag, Typography, Empty, Spin, Space } from "antd";
import {
  SearchOutlined,
  TeamOutlined,
  BankOutlined,
  AlertOutlined,
  AuditOutlined,
  DashboardOutlined,
  BarChartOutlined,
  FlagOutlined,
  SettingOutlined,
} from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { adminSearch } from "@/lib/api";
import type { SearchResult } from "@/lib/types";

const ENTITY_ICONS: Record<string, React.ReactNode> = {
  user: <TeamOutlined />,
  tenant: <BankOutlined />,
  subscription: <AlertOutlined />,
  audit_log: <AuditOutlined />,
};

const ENTITY_COLORS: Record<string, string> = {
  user: "blue",
  tenant: "green",
  subscription: "purple",
  audit_log: "orange",
};

interface QuickAction {
  label: string;
  path: string;
  icon: React.ReactNode;
}

const QUICK_ACTIONS: QuickAction[] = [
  { label: "Go to Dashboard", path: "/", icon: <DashboardOutlined /> },
  { label: "Go to Users", path: "/users", icon: <TeamOutlined /> },
  { label: "Go to Tenants", path: "/tenants", icon: <BankOutlined /> },
  { label: "Go to Audit Log", path: "/audit-log", icon: <AuditOutlined /> },
  { label: "Go to Analytics", path: "/analytics/signups", icon: <BarChartOutlined /> },
  { label: "Go to Feature Flags", path: "/feature-flags", icon: <FlagOutlined /> },
  { label: "Go to Approvals", path: "/approvals", icon: <SettingOutlined /> },
];

function getEntityPath(entityType: string, entityId: string): string {
  switch (entityType) {
    case "user":
      return `/users/${entityId}`;
    case "tenant":
      return `/tenants/${entityId}`;
    case "subscription":
      return `/users`;
    case "audit_log":
      return `/audit-log`;
    default:
      return "/";
  }
}

export default function CommandPalette() {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const navigate = useNavigate();
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Global keyboard listener
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setOpen((prev) => !prev);
      }
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  // Debounced search
  useEffect(() => {
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }
    if (!query.trim()) {
      setResults([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    debounceRef.current = setTimeout(() => {
      adminSearch(query)
        .then((res) => {
          setResults(res.results);
          setActiveIndex(0);
        })
        .catch(() => {
          setResults([]);
        })
        .finally(() => setLoading(false));
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  const handleClose = useCallback(() => {
    setOpen(false);
    setQuery("");
    setResults([]);
    setActiveIndex(0);
  }, []);

  const handleSelect = useCallback(
    (path: string) => {
      navigate(path);
      handleClose();
    },
    [navigate, handleClose],
  );

  // Combine results + quick actions for keyboard nav
  const showQuickActions = !query.trim();
  const totalItems = showQuickActions ? QUICK_ACTIONS.length : results.length;

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setActiveIndex((prev) => Math.min(prev + 1, totalItems - 1));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setActiveIndex((prev) => Math.max(prev - 1, 0));
      } else if (e.key === "Enter") {
        e.preventDefault();
        if (showQuickActions && QUICK_ACTIONS[activeIndex]) {
          handleSelect(QUICK_ACTIONS[activeIndex].path);
        } else if (results[activeIndex]) {
          const r = results[activeIndex];
          handleSelect(getEntityPath(r.entity_type, r.entity_id));
        }
      } else if (e.key === "Escape") {
        handleClose();
      }
    },
    [totalItems, showQuickActions, activeIndex, results, handleSelect, handleClose],
  );

  // Group results by entity_type
  const grouped = results.reduce<Record<string, SearchResult[]>>((acc, r) => {
    const group = acc[r.entity_type] ?? [];
    group.push(r);
    acc[r.entity_type] = group;
    return acc;
  }, {});

  let flatIndex = -1;

  return (
    <Modal
      open={open}
      onCancel={handleClose}
      footer={null}
      closable={false}
      width={600}
      styles={{
        body: { padding: 0 },
        header: { background: "#15294A" },
      }}
      style={{ top: 80 }}
    >
      <div style={{ background: "#15294A", padding: "16px 20px", borderRadius: "8px 8px 0 0" }}>
        <Input
          ref={(el) => {
            // Focus input when modal opens
            if (el) {
              (inputRef as React.MutableRefObject<HTMLInputElement | null>).current =
                el.input as HTMLInputElement | null;
              el.focus();
            }
          }}
          prefix={<SearchOutlined style={{ color: "#6D7F99" }} />}
          placeholder="Search users, tenants, subscriptions... (Esc to close)"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          variant="borderless"
          size="large"
          style={{ color: "#fff", background: "rgba(255,255,255,0.1)", borderRadius: 8 }}
          styles={{ input: { color: "#fff" } }}
        />
      </div>

      <div style={{ maxHeight: 400, overflowY: "auto", padding: "8px 0" }}>
        {loading && (
          <div style={{ textAlign: "center", padding: 24 }}>
            <Spin />
          </div>
        )}

        {!loading && query.trim() && results.length === 0 && (
          <Empty
            description="No results found"
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            style={{ padding: 24 }}
          />
        )}

        {!loading &&
          query.trim() &&
          Object.entries(grouped).map(([entityType, items]) => (
            <div key={entityType}>
              <Typography.Text
                type="secondary"
                style={{
                  display: "block",
                  padding: "8px 20px 4px",
                  fontSize: 11,
                  textTransform: "uppercase",
                  letterSpacing: 1,
                }}
              >
                {entityType.replace("_", " ")}s
              </Typography.Text>
              <List
                dataSource={items}
                renderItem={(item) => {
                  flatIndex++;
                  const idx = flatIndex;
                  return (
                    <List.Item
                      style={{
                        padding: "8px 20px",
                        cursor: "pointer",
                        background: idx === activeIndex ? "#f0f5ff" : "transparent",
                      }}
                      onClick={() =>
                        handleSelect(getEntityPath(item.entity_type, item.entity_id))
                      }
                      onMouseEnter={() => setActiveIndex(idx)}
                    >
                      <Space>
                        {ENTITY_ICONS[item.entity_type] ?? <SearchOutlined />}
                        <div>
                          <Typography.Text strong>{item.title}</Typography.Text>
                          <br />
                          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
                            {item.subtitle}
                          </Typography.Text>
                        </div>
                      </Space>
                      <Tag color={ENTITY_COLORS[item.entity_type] ?? "default"}>
                        {item.match_field}
                      </Tag>
                    </List.Item>
                  );
                }}
              />
            </div>
          ))}

        {showQuickActions && !loading && (
          <>
            <Typography.Text
              type="secondary"
              style={{
                display: "block",
                padding: "8px 20px 4px",
                fontSize: 11,
                textTransform: "uppercase",
                letterSpacing: 1,
              }}
            >
              Quick Actions
            </Typography.Text>
            <List
              dataSource={QUICK_ACTIONS}
              renderItem={(action, idx) => (
                <List.Item
                  style={{
                    padding: "8px 20px",
                    cursor: "pointer",
                    background: idx === activeIndex ? "#f0f5ff" : "transparent",
                  }}
                  onClick={() => handleSelect(action.path)}
                  onMouseEnter={() => setActiveIndex(idx)}
                >
                  <Space>
                    {action.icon}
                    <Typography.Text>{action.label}</Typography.Text>
                  </Space>
                </List.Item>
              )}
            />
          </>
        )}
      </div>

      <div
        style={{
          borderTop: "1px solid #f0f0f0",
          padding: "8px 20px",
          display: "flex",
          gap: 16,
          fontSize: 11,
          color: "#797878",
        }}
      >
        <span>
          <Tag style={{ fontSize: 10 }}>↑↓</Tag> Navigate
        </span>
        <span>
          <Tag style={{ fontSize: 10 }}>Enter</Tag> Select
        </span>
        <span>
          <Tag style={{ fontSize: 10 }}>Esc</Tag> Close
        </span>
      </div>
    </Modal>
  );
}
