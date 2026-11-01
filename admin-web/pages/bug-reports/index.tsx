/**
 * pages/bug-reports/index.tsx
 * ===========================
 * Danh sách bug reports (Web Admin / dev team) — restyle theo theme KinderLog.
 */

import { useEffect, useMemo, useState } from "react";
import useSWR from "swr";
import { useRouter } from "next/router";
import Link from "next/link";
import AdminLayout from "@/components/AdminLayout";
import { Badge, Card, EmptyState, Spinner } from "@/components/ui";
import { Pill, SearchBar, SearchableSelect, SelectOption } from "@/components/ui-school";
import { apiFetch, clearToken, getToken } from "@/lib/api";
import {
  CATEGORY_LABELS,
  ROLE_LABELS,
  SEVERITY_COLORS,
  STATUS_COLORS,
  formatDate,
  relativeTime,
} from "@/lib/format";

interface BugReportItem {
  bug_report_id: string;
  user: { user_id: string; username: string; role: string };
  teacher: { teacher_id: string; full_name: string; email: string } | null;
  title: string;
  description: string;
  category: string;
  severity: string;
  status: string;
  app_version: string | null;
  build_number: string | null;
  os_version: string | null;
  device_model: string | null;
  network_type: string | null;
  resolved_at: string | null;
  closed_at: string | null;
  attachment_count: number;
  created_at: string;
  updated_at: string;
}

interface ListResponse {
  items: BugReportItem[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
  has_next: boolean;
  has_prev: boolean;
}

export default function BugReportsListPage() {
  const router = useRouter();
  const [tokenReady, setTokenReady] = useState(false);
  const [page, setPage] = useState(1);
  const [filterStatus, setFilterStatus] = useState("");
  const [filterSeverity, setFilterSeverity] = useState("");
  const [filterCategory, setFilterCategory] = useState("");
  const [filterRole, setFilterRole] = useState("");
  const [search, setSearch] = useState("");

  const statusOptions = useMemo<SelectOption[]>(
    () => [
      { value: "", label: "Tất cả trạng thái" },
      ...Object.entries(STATUS_COLORS).map(([k, v]) => ({ value: k, label: v.label })),
    ],
    []
  );

  const severityOptions = useMemo<SelectOption[]>(
    () => [
      { value: "", label: "Tất cả mức độ" },
      ...Object.entries(SEVERITY_COLORS).map(([k, v]) => ({ value: k, label: v.label })),
    ],
    []
  );

  const categoryOptions = useMemo<SelectOption[]>(
    () => [
      { value: "", label: "Tất cả loại lỗi" },
      ...Object.entries(CATEGORY_LABELS).map(([k, v]) => ({ value: k, label: v })),
    ],
    []
  );

  const roleOptions = useMemo<SelectOption[]>(
    () => [
      { value: "", label: "Tất cả người gửi" },
      ...Object.entries(ROLE_LABELS).map(([k, v]) => ({ value: k, label: v })),
    ],
    []
  );

  useEffect(() => {
    if (!getToken("adminApp")) {
      router.replace("/login");
    } else {
      setTokenReady(true);
    }
  }, [router]);

  const query: Record<string, any> = {
    page,
    page_size: 20,
    order_by: "created_at_desc",
  };
  if (filterStatus) query.status = filterStatus;
  if (filterSeverity) query.severity = filterSeverity;
  if (filterCategory) query.category = filterCategory;
  if (filterRole) query.user_role = filterRole;
  if (search.trim()) query.search = search.trim();

  const { data, error } = useSWR<ListResponse>(
    tokenReady ? ["/api/bug-reports", query] : null,
    ([url, q]) =>
      apiFetch<ListResponse>(url, {
        query: q as Record<string, string | number | null | undefined>,
        account: "adminApp",
      }),
  );

  const resetFilters = () => {
    setFilterStatus("");
    setFilterSeverity("");
    setFilterCategory("");
    setFilterRole("");
    setSearch("");
    setPage(1);
  };

  return (
    <AdminLayout currentPage="bug-reports">
      <div className="space-y-4">
        {/* Title */}
        <div className="flex items-end justify-between flex-wrap gap-2">
          <div>
            <h1 className="text-2xl font-bold text-ink tracking-tight">
              Quản lý Bug Report
            </h1>
            <p className="text-sm text-ink-soft mt-1">
              Xem và xử lý bug reports từ giáo viên / phụ huynh
            </p>
          </div>
          {data && (
            <div className="text-sm text-ink-soft">
              Tổng:{" "}
              <span className="font-bold text-ink">{data.total}</span> reports
            </div>
          )}
        </div>

        {/* Filters */}
        <Card className="p-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-3">
            <SearchBar
              value={search}
              onChange={(v) => {
                setSearch(v);
                setPage(1);
              }}
              placeholder="🔍 Tìm theo tiêu đề..."
            />
            <SearchableSelect
              options={statusOptions}
              value={filterStatus}
              onChange={(v) => {
                setFilterStatus(v);
                setPage(1);
              }}
              placeholder="Tất cả trạng thái"
              searchPlaceholder="Tìm trạng thái..."
              allowClear={true}
            />
            <SearchableSelect
              options={severityOptions}
              value={filterSeverity}
              onChange={(v) => {
                setFilterSeverity(v);
                setPage(1);
              }}
              placeholder="Tất cả mức độ"
              searchPlaceholder="Tìm mức độ..."
              allowClear={true}
            />
            <SearchableSelect
              options={categoryOptions}
              value={filterCategory}
              onChange={(v) => {
                setFilterCategory(v);
                setPage(1);
              }}
              placeholder="Tất cả loại lỗi"
              searchPlaceholder="Tìm loại lỗi..."
              allowClear={true}
            />
            <SearchableSelect
              options={roleOptions}
              value={filterRole}
              onChange={(v) => {
                setFilterRole(v);
                setPage(1);
              }}
              placeholder="Tất cả người gửi"
              searchPlaceholder="Tìm người gửi..."
              allowClear={true}
            />
          </div>
          <div className="mt-2 flex justify-end">
            <button
              onClick={resetFilters}
              className="text-xs text-ink-soft hover:text-ink underline"
            >
              Xóa bộ lọc
            </button>
          </div>
        </Card>

        {/* List */}
        <Card>
          {error ? (
            <div className="p-8 text-center text-bad space-y-2">
              <p className="font-semibold">Lỗi tải dữ liệu. Hãy thử lại sau.</p>
              <button
                onClick={() => {
                  clearToken("adminApp");
                  router.replace("/login");
                }}
                className="kbtn kbtn-danger"
              >
                Đăng nhập lại
              </button>
            </div>
          ) : !data ? (
            <Spinner />
          ) : data.items.length === 0 ? (
            <EmptyState
              icon="🎉"
              title="Không có bug report nào"
              description="Hiện không có report nào khớp với bộ lọc."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead
                  className="text-xs uppercase tracking-wider"
                  style={{ background: "#EFECE5", color: "#605D57" }}
                >
                  <tr>
                    <th className="px-4 py-3 text-left font-semibold">Tiêu đề</th>
                    <th className="px-4 py-3 text-left font-semibold">Người gửi</th>
                    <th className="px-4 py-3 text-left font-semibold">Loại</th>
                    <th className="px-4 py-3 text-left font-semibold">Mức độ</th>
                    <th className="px-4 py-3 text-left font-semibold">Trạng thái</th>
                    <th className="px-4 py-3 text-left font-semibold">Ảnh</th>
                    <th className="px-4 py-3 text-left font-semibold">Ngày gửi</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.map((r, idx) => {
                    const statusColor = STATUS_COLORS[r.status] || {
                      bg: "bg-gray-100",
                      text: "text-gray-700",
                      label: r.status,
                    };
                    const sevColor = SEVERITY_COLORS[r.severity] || {
                      bg: "bg-gray-100",
                      text: "text-gray-700",
                      label: r.severity,
                    };
                    return (
                      <tr
                        key={r.bug_report_id}
                        className={`hover:bg-sunken cursor-pointer ${
                          idx > 0 ? "border-t border-line" : ""
                        }`}
                        onClick={() => router.push(`/bug-reports/${r.bug_report_id}`)}
                      >
                        <td className="px-4 py-3 max-w-xs">
                          <div className="font-semibold text-ink line-clamp-1">
                            {r.title}
                          </div>
                          <div className="text-xs text-ink-soft line-clamp-1 mt-0.5">
                            {r.description}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="text-ink">{r.user?.username || "—"}</div>
                          <div className="text-xs text-ink-soft">
                            {ROLE_LABELS[r.user?.role] || r.user?.role}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-ink-soft">
                          {CATEGORY_LABELS[r.category] || r.category}
                        </td>
                        <td className="px-4 py-3">
                          <Pill
                            tone={
                              sevColor.bg.includes("red")
                                ? "bad"
                                : sevColor.bg.includes("orange")
                                  ? "warn"
                                  : sevColor.bg.includes("blue")
                                    ? "info"
                                    : "neutral"
                            }
                          >
                            {sevColor.label}
                          </Pill>
                        </td>
                        <td className="px-4 py-3">
                          <Pill
                            tone={
                              statusColor.bg.includes("green")
                                ? "ok"
                                : statusColor.bg.includes("yellow")
                                  ? "warn"
                                  : statusColor.bg.includes("blue")
                                    ? "info"
                                    : statusColor.bg.includes("purple")
                                      ? "brand"
                                      : "neutral"
                            }
                          >
                            {statusColor.label}
                          </Pill>
                        </td>
                        <td className="px-4 py-3 text-ink-soft">
                          {r.attachment_count > 0 ? `📎 ${r.attachment_count}` : "—"}
                        </td>
                        <td className="px-4 py-3 text-ink-soft whitespace-nowrap">
                          <div title={formatDate(r.created_at)}>
                            {relativeTime(r.created_at)}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        {/* Pagination */}
        {data && data.total_pages > 1 && (
          <div className="flex items-center justify-between text-sm">
            <div className="text-ink-soft">
              Trang <span className="font-bold text-ink">{data.page}</span> /{" "}
              {data.total_pages}
            </div>
            <div className="flex gap-2">
              <button
                disabled={!data.has_prev}
                onClick={() => setPage(page - 1)}
                className="kbtn kbtn-secondary disabled:opacity-40"
              >
                ← Trước
              </button>
              <button
                disabled={!data.has_next}
                onClick={() => setPage(page + 1)}
                className="kbtn kbtn-secondary disabled:opacity-40"
              >
                Sau →
              </button>
            </div>
          </div>
        )}
      </div>
    </AdminLayout>
  );
}