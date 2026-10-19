/**
 * pages/bug-reports/index.tsx
 * ===========================
 * Trang danh sách bug reports với filter + pagination.
 */

import { useEffect, useState } from "react";
import useSWR from "swr";
import { useRouter } from "next/router";
import Link from "next/link";
import AdminLayout from "@/components/AdminLayout";
import { Badge, Card, EmptyState, Spinner } from "@/components/ui";
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

  useEffect(() => {
    if (!getToken()) {
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
        <div className="flex items-end justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Quản lý Bug Report</h1>
            <p className="text-sm text-gray-500 mt-1">
              Xem và xử lý bug reports từ giáo viên / phụ huynh
            </p>
          </div>
          {data && (
            <div className="text-sm text-gray-500">
              Tổng: <span className="font-semibold text-gray-900">{data.total}</span> reports
            </div>
          )}
        </div>

        {/* Filters */}
        <Card className="p-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-3">
            <input
              type="text"
              placeholder="🔍 Tìm theo tiêu đề..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
            />
            <select
              value={filterStatus}
              onChange={(e) => {
                setFilterStatus(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
            >
              <option value="">Tất cả trạng thái</option>
              {Object.entries(STATUS_COLORS).map(([k, v]) => (
                <option key={k} value={k}>
                  {v.label}
                </option>
              ))}
            </select>
            <select
              value={filterSeverity}
              onChange={(e) => {
                setFilterSeverity(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
            >
              <option value="">Tất cả mức độ</option>
              {Object.entries(SEVERITY_COLORS).map(([k, v]) => (
                <option key={k} value={k}>
                  {v.label}
                </option>
              ))}
            </select>
            <select
              value={filterCategory}
              onChange={(e) => {
                setFilterCategory(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
            >
              <option value="">Tất cả loại lỗi</option>
              {Object.entries(CATEGORY_LABELS).map(([k, v]) => (
                <option key={k} value={k}>
                  {v}
                </option>
              ))}
            </select>
            <select
              value={filterRole}
              onChange={(e) => {
                setFilterRole(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
            >
              <option value="">Tất cả người gửi</option>
              {Object.entries(ROLE_LABELS).map(([k, v]) => (
                <option key={k} value={k}>
                  {v}
                </option>
              ))}
            </select>
          </div>
          <div className="mt-2 flex justify-end">
            <button
              onClick={resetFilters}
              className="text-xs text-gray-500 hover:text-gray-700 underline"
            >
              Xóa bộ lọc
            </button>
          </div>
        </Card>

        {/* List */}
        <Card>
          {error ? (
            <div className="p-8 text-center text-red-600 space-y-2">
              <p className="font-medium">Lỗi tải dữ liệu. Hãy thử lại sau.</p>
              <button
                onClick={() => {
                  clearToken();
                  router.replace("/login");
                }}
                className="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded text-xs font-medium transition"
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
                <thead className="bg-gray-50 text-gray-600 text-xs uppercase tracking-wider">
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
                <tbody className="divide-y divide-gray-100">
                  {data.items.map((r) => {
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
                        className="hover:bg-gray-50 cursor-pointer"
                        onClick={() => router.push(`/bug-reports/${r.bug_report_id}`)}
                      >
                        <td className="px-4 py-3 max-w-xs">
                          <div className="font-medium text-gray-900 line-clamp-1">
                            {r.title}
                          </div>
                          <div className="text-xs text-gray-500 line-clamp-1 mt-0.5">
                            {r.description}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="text-gray-900">{r.user?.username || "—"}</div>
                          <div className="text-xs text-gray-500">
                            {ROLE_LABELS[r.user?.role] || r.user?.role}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-gray-700">
                          {CATEGORY_LABELS[r.category] || r.category}
                        </td>
                        <td className="px-4 py-3">
                          <Badge bg={sevColor.bg} text={sevColor.text}>
                            {sevColor.label}
                          </Badge>
                        </td>
                        <td className="px-4 py-3">
                          <Badge bg={statusColor.bg} text={statusColor.text}>
                            {statusColor.label}
                          </Badge>
                        </td>
                        <td className="px-4 py-3 text-gray-600">
                          {r.attachment_count > 0 ? `📎 ${r.attachment_count}` : "—"}
                        </td>
                        <td className="px-4 py-3 text-gray-600 whitespace-nowrap">
                          <div title={formatDate(r.created_at)}>{relativeTime(r.created_at)}</div>
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
            <div className="text-gray-500">
              Trang <span className="font-semibold">{data.page}</span> / {data.total_pages}
            </div>
            <div className="flex gap-2">
              <button
                disabled={!data.has_prev}
                onClick={() => setPage(page - 1)}
                className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-40 hover:bg-gray-50"
              >
                ← Trước
              </button>
              <button
                disabled={!data.has_next}
                onClick={() => setPage(page + 1)}
                className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-40 hover:bg-gray-50"
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
