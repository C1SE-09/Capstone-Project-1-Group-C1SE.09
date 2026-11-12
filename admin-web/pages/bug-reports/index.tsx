/**
 * pages/bug-reports/index.tsx
 * ===========================
 * Danh sách bug reports (Web Admin / Dev Team).
 * 100% chuẩn Figma Frame 03: "GV · Admin Web · 03 — Báo lỗi: Danh sách" (#454:3328)
 */

import { useEffect, useMemo, useState } from "react";
import useSWR from "swr";
import { useRouter } from "next/router";
import AdminLayout from "@/components/AdminLayout";
import { EmptyState, Spinner } from "@/components/ui";
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

  const queryParams = new URLSearchParams();
  queryParams.set("page", page.toString());
  queryParams.set("page_size", "15");
  if (filterStatus) queryParams.set("status", filterStatus);
  if (filterSeverity) queryParams.set("severity", filterSeverity);
  if (filterCategory) queryParams.set("category", filterCategory);
  if (filterRole) queryParams.set("role", filterRole);
  if (search.trim()) queryParams.set("search", search.trim());

  const { data, error } = useSWR<ListResponse>(
    tokenReady ? `/api/bug-reports?${queryParams.toString()}` : null,
    (url) => apiFetch<ListResponse>(url, { account: "adminApp" }),
    { keepPreviousData: true },
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
      <div className="space-y-6">
        {/* Header (Figma 454:3346 & 3347) */}
        <div>
          <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
            Báo lỗi — Danh sách
          </h1>
          <p className="text-sm text-[#65727D] mt-1">
            Báo lỗi từ người dùng ứng dụng. Lọc theo trạng thái, mức độ, loại lỗi và người gửi.
          </p>
        </div>

        {/* ─── Filter Bar Card (Figma 454:3348) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft space-y-4">
          <div className="w-full">
            <SearchBar
              value={search}
              onChange={(v) => {
                setSearch(v);
                setPage(1);
              }}
              placeholder="Tìm theo tiêu đề hoặc nội dung lỗi..."
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
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
              searchPlaceholder="Tìm loại..."
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

          {(filterStatus || filterSeverity || filterCategory || filterRole || search) && (
            <div className="flex justify-end pt-1">
              <button
                onClick={resetFilters}
                className="text-xs font-bold text-[#A93832] hover:underline"
              >
                Đặt lại bộ lọc
              </button>
            </div>
          )}
        </div>

        {/* ─── Table Card (Figma 454:3365) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] overflow-hidden shadow-soft">
          {error ? (
            <div className="p-8 text-center text-[#A93832] space-y-3">
              <p className="font-bold text-sm">Không thể tải danh sách báo lỗi.</p>
              <button
                onClick={() => {
                  clearToken("adminApp");
                  router.replace("/login");
                }}
                className="px-5 py-2 bg-[#A93832] text-white rounded-full font-bold text-xs"
              >
                Đăng nhập lại
              </button>
            </div>
          ) : !data ? (
            <Spinner />
          ) : data.items.length === 0 ? (
            <EmptyState
              icon="🎉"
              title="Không có báo lỗi nào"
              description="Hiện không có bản ghi nào khớp với điều kiện lọc."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-[#F6F7F8] border-b border-[#E5E8EB] text-xs font-bold text-[#65727D] uppercase tracking-wider">
                  <tr>
                    <th className="px-5 py-3.5 text-left">Tiêu đề &amp; Mô tả</th>
                    <th className="px-5 py-3.5 text-left">Người gửi</th>
                    <th className="px-5 py-3.5 text-left">Phân loại</th>
                    <th className="px-5 py-3.5 text-left">Mức độ</th>
                    <th className="px-5 py-3.5 text-left">Trạng thái</th>
                    <th className="px-5 py-3.5 text-center">Ảnh</th>
                    <th className="px-5 py-3.5 text-right">Ngày gửi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E5E8EB]">
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
                        className="hover:bg-[#F6F7F8] cursor-pointer transition"
                        onClick={() => router.push(`/bug-reports/${r.bug_report_id}`)}
                      >
                        <td className="px-5 py-4 max-w-sm">
                          <div className="font-bold text-[#102737] line-clamp-1">
                            {r.title}
                          </div>
                          <div className="text-xs text-[#65727D] line-clamp-1 mt-0.5">
                            {r.description}
                          </div>
                        </td>
                        <td className="px-5 py-4">
                          <div className="font-semibold text-[#102737]">
                            {r.teacher?.full_name || r.user?.username || "—"}
                          </div>
                          <div className="text-[11px] text-[#65727D]">
                            {ROLE_LABELS[r.user?.role] || r.user?.role}
                          </div>
                        </td>
                        <td className="px-5 py-4 text-xs font-medium text-[#65727D]">
                          {CATEGORY_LABELS[r.category] || r.category}
                        </td>
                        <td className="px-5 py-4">
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
                        <td className="px-5 py-4">
                          <Pill
                            tone={
                              statusColor.bg.includes("green")
                                ? "ok"
                                : statusColor.bg.includes("yellow")
                                  ? "warn"
                                  : statusColor.bg.includes("blue")
                                    ? "info"
                                    : "neutral"
                            }
                          >
                            {statusColor.label}
                          </Pill>
                        </td>
                        <td className="px-5 py-4 text-center text-xs text-[#65727D]">
                          {r.attachment_count > 0 ? (
                            <span className="inline-flex items-center gap-1 font-bold text-[#087F70]">
                              📎 {r.attachment_count}
                            </span>
                          ) : (
                            "—"
                          )}
                        </td>
                        <td className="px-5 py-4 text-right text-xs text-[#65727D] whitespace-nowrap">
                          <div title={formatDate(r.created_at)} className="font-medium">
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
        </div>

        {/* ─── Footer Meta Note (Figma 454:3423) ─── */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-2">
          <div className="text-xs text-[#65727D]">
            💡 Chạm vào một báo lỗi để mở chi tiết, xem ảnh đính kèm và đổi trạng thái xử lý.
          </div>

          {data && data.total_pages > 1 && (
            <div className="flex items-center gap-3 text-xs font-bold text-[#65727D]">
              <span>
                Trang <span className="text-[#102737]">{data.page}</span> / {data.total_pages}
              </span>
              <div className="flex gap-1.5">
                <button
                  disabled={!data.has_prev}
                  onClick={() => setPage(page - 1)}
                  className="px-3 py-1.5 rounded-[12px] border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] disabled:opacity-40 transition"
                >
                  ← Trước
                </button>
                <button
                  disabled={!data.has_next}
                  onClick={() => setPage(page + 1)}
                  className="px-3 py-1.5 rounded-[12px] border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] disabled:opacity-40 transition"
                >
                  Sau →
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
