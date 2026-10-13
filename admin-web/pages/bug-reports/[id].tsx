/**
 * pages/bug-reports/[id].tsx
 * ==========================
 * Trang chi tiết bug report: xem thông tin + đổi trạng thái.
 */

import { useEffect, useState } from "react";
import useSWR from "swr";
import { useRouter } from "next/router";
import Link from "next/link";
import AdminLayout from "@/components/AdminLayout";
import { Badge, Card, Spinner } from "@/components/ui";
import { apiFetch, ApiError, getToken } from "@/lib/api";
import {
  CATEGORY_LABELS,
  ROLE_LABELS,
  SEVERITY_COLORS,
  STATUS_COLORS,
  formatDate,
} from "@/lib/format";

interface HistoryEntry {
  history_id: string;
  changed_by: { user_id: string; username: string; role: string } | null;
  old_status: string | null;
  new_status: string | null;
  old_teacher_id: string | null;
  new_teacher_id: string | null;
  comment: string | null;
  created_at: string;
}

interface Attachment {
  attachment_id: string;
  file_url: string;
  file_name: string;
  file_size: number | null;
  mime_type: string | null;
  description: string | null;
  created_at: string | null;
}

interface DetailResponse {
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
  attachments: Attachment[];
  history: HistoryEntry[];
  created_at: string;
  updated_at: string;
}

export default function BugReportDetailPage() {
  const router = useRouter();
  const { id } = router.query;
  const [tokenReady, setTokenReady] = useState(false);
  const [newStatus, setNewStatus] = useState("");
  const [newCategory, setNewCategory] = useState("");
  const [newSeverity, setNewSeverity] = useState("");
  const [comment, setComment] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saveOk, setSaveOk] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
    } else {
      setTokenReady(true);
    }
  }, [router]);

  const { data: report, error, mutate } = useSWR<DetailResponse>(
    tokenReady && id ? `/api/bug-reports/${id}` : null,
    (url: string) => apiFetch<DetailResponse>(url),
  );

  useEffect(() => {
    if (report) {
      setNewStatus(report.status);
      setNewCategory(report.category);
      setNewSeverity(report.severity);
    }
  }, [report]);

  const handleSave = async () => {
    if (!report) return;
    setSaveError(null);
    setSaveOk(false);
    setSaving(true);

    try {
      // Chỉ gửi field thực sự thay đổi (không gửi null lung tung)
      const body: Record<string, string> = {};
      if (newStatus !== report.status) body.status = newStatus;
      if (newCategory !== report.category) body.category = newCategory;
      if (newSeverity !== report.severity) body.severity = newSeverity;
      const trimmed = comment.trim();
      if (trimmed) body.comment = trimmed;

      // PATCH trả về BugReportDetail mới nhất (kèm history cập nhật).
      // Dùng luôn data này để update cache, khỏi gọi GET lại.
      const updated = await apiFetch<DetailResponse>(
        `/api/bug-reports/${report.bug_report_id}`,
        { method: "PATCH", body },
      );
      setComment("");
      setSaveOk(true);
      // Update cache với data mới từ server, force revalidate để chắc chắn
      await mutate(updated, { revalidate: true });
      // Đồng bộ state cục bộ (3 dropdown) với data mới
      setNewStatus(updated.status);
      setNewCategory(updated.category);
      setNewSeverity(updated.severity);
      setTimeout(() => setSaveOk(false), 3000);
    } catch (err) {
      if (err instanceof ApiError) {
        setSaveError(err.detail);
      } else {
        setSaveError("Có lỗi xảy ra. Vui lòng thử lại.");
      }
    } finally {
      setSaving(false);
    }
  };

  // Enable Save khi: đổi 1 trong 3 dropdown, HOẶC có ghi chú
  const hasChange =
    !!report &&
    (newStatus !== report.status ||
      newCategory !== report.category ||
      newSeverity !== report.severity ||
      comment.trim().length > 0);

  if (!tokenReady) return <Spinner />;

  if (error) {
    return (
      <AdminLayout currentPage="bug-reports">
        <div className="text-center py-16">
          <div className="text-5xl mb-3">😢</div>
          <div className="text-gray-700 font-semibold">Không tìm thấy bug report</div>
          <Link
            href="/bug-reports"
            className="text-brand-600 text-sm mt-2 inline-block hover:underline"
          >
            ← Quay lại danh sách
          </Link>
        </div>
      </AdminLayout>
    );
  }

  if (!report) {
    return (
      <AdminLayout currentPage="bug-reports">
        <Spinner />
      </AdminLayout>
    );
  }

  const statusColor = STATUS_COLORS[report.status] || {
    bg: "bg-gray-100",
    text: "text-gray-700",
    label: report.status,
  };
  const sevColor = SEVERITY_COLORS[report.severity] || {
    bg: "bg-gray-100",
    text: "text-gray-700",
    label: report.severity,
  };

  return (
    <AdminLayout currentPage="bug-reports">
      <div className="space-y-4 max-w-5xl">
        {/* Breadcrumb */}
        <div className="text-sm text-gray-500">
          <Link href="/bug-reports" className="hover:text-brand-600 hover:underline">
            Quản lý Bug Report
          </Link>
          <span className="mx-1.5">/</span>
          <span className="text-gray-700">Chi tiết</span>
        </div>

        {/* Header */}
        <Card className="p-6">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-2 flex-wrap">
                <Badge bg={statusColor.bg} text={statusColor.text}>
                  {statusColor.label}
                </Badge>
                <Badge bg={sevColor.bg} text={sevColor.text}>
                  {sevColor.label}
                </Badge>
                <span className="text-xs text-gray-500">
                  {CATEGORY_LABELS[report.category] || report.category}
                </span>
              </div>
              <h1 className="text-xl font-bold text-gray-900">{report.title}</h1>
              <div className="text-sm text-gray-500 mt-1.5">
                #{report.bug_report_id.slice(0, 8)} · tạo lúc {formatDate(report.created_at)}
              </div>
            </div>
          </div>

          {/* Description */}
          <div className="mt-5 pt-5 border-t border-gray-100">
            <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">
              Mô tả chi tiết
            </h3>
            <p className="text-sm text-gray-800 whitespace-pre-wrap leading-relaxed">
              {report.description}
            </p>
          </div>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          {/* Left: Meta info */}
          <div className="lg:col-span-2 space-y-4">
            {/* Reporter & Assignee */}
            <Card className="p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Thông tin liên quan</h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <div className="text-xs text-gray-500 mb-0.5">Người gửi</div>
                  <div className="font-medium text-gray-900">
                    {report.user?.username || "—"}
                  </div>
                  <div className="text-xs text-gray-500">
                    {ROLE_LABELS[report.user?.role] || report.user?.role}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-0.5">Người xử lý</div>
                  <div className="font-medium text-gray-900">
                    {report.teacher?.full_name || (
                      <span className="text-gray-400 italic">Chưa gán</span>
                    )}
                  </div>
                  {report.teacher?.email && (
                    <div className="text-xs text-gray-500">{report.teacher.email}</div>
                  )}
                </div>
              </div>
            </Card>

            {/* Device info */}
            {(report.app_version || report.os_version || report.device_model) && (
              <Card className="p-5">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Thiết bị & Môi trường</h3>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  {report.app_version && (
                    <div>
                      <div className="text-xs text-gray-500">App version</div>
                      <div className="font-medium">
                        {report.app_version}
                        {report.build_number && ` (build ${report.build_number})`}
                      </div>
                    </div>
                  )}
                  {report.os_version && (
                    <div>
                      <div className="text-xs text-gray-500">OS</div>
                      <div className="font-medium">{report.os_version}</div>
                    </div>
                  )}
                  {report.device_model && (
                    <div>
                      <div className="text-xs text-gray-500">Device</div>
                      <div className="font-medium">{report.device_model}</div>
                    </div>
                  )}
                  {report.network_type && (
                    <div>
                      <div className="text-xs text-gray-500">Network</div>
                      <div className="font-medium">{report.network_type}</div>
                    </div>
                  )}
                </div>
              </Card>
            )}

            {/* Attachments */}
            {report.attachments && report.attachments.length > 0 && (
              <Card className="p-5">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">
                  File đính kèm ({report.attachments.length})
                </h3>
                <div className="space-y-2">
                  {report.attachments.map((att) => (
                    <a
                      key={att.attachment_id}
                      href={att.file_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-3 p-2.5 border border-gray-200 rounded-lg hover:bg-gray-50"
                    >
                      <span className="text-2xl">
                        {att.mime_type?.startsWith("image/") ? "🖼️" : "📄"}
                      </span>
                      <div className="flex-1 min-w-0">
                        <div className="text-sm font-medium text-gray-900 truncate">
                          {att.file_name}
                        </div>
                        <div className="text-xs text-gray-500">
                          {att.mime_type}
                          {att.file_size && ` · ${(att.file_size / 1024).toFixed(1)} KB`}
                        </div>
                      </div>
                      <span className="text-xs text-brand-600">Mở ↗</span>
                    </a>
                  ))}
                </div>
              </Card>
            )}

            {/* History */}
            <Card className="p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">
                Lịch sử thay đổi ({report.history?.length || 0})
              </h3>
              {report.history && report.history.length > 0 ? (
                <ol className="space-y-3">
                  {report.history.map((h) => {
                    const oldC = h.old_status ? STATUS_COLORS[h.old_status] : null;
                    const newC = h.new_status ? STATUS_COLORS[h.new_status] : null;
                    return (
                      <li
                        key={h.history_id}
                        className="border-l-2 border-brand-300 pl-3 py-1"
                      >
                        <div className="text-xs text-gray-500">{formatDate(h.created_at)}</div>
                        <div className="text-sm text-gray-800 mt-0.5">
                          {h.old_status && h.new_status ? (
                            <>
                              <Badge bg={oldC!.bg} text={oldC!.text}>
                                {oldC!.label}
                              </Badge>{" "}
                              →{" "}
                              <Badge bg={newC!.bg} text={newC!.text}>
                                {newC!.label}
                              </Badge>
                            </>
                          ) : h.new_status ? (
                            <>
                              Đã tạo với trạng thái{" "}
                              <Badge bg={newC!.bg} text={newC!.text}>
                                {newC!.label}
                              </Badge>
                            </>
                          ) : (
                            "Cập nhật"
                          )}
                        </div>
                        {h.comment && (
                          <div className="text-xs text-gray-600 mt-1 italic">
                            💬 {h.comment}
                          </div>
                        )}
                        {h.changed_by && (
                          <div className="text-xs text-gray-400 mt-0.5">
                            bởi {h.changed_by.username}
                          </div>
                        )}
                      </li>
                    );
                  })}
                </ol>
              ) : (
                <div className="text-sm text-gray-500 italic">Chưa có lịch sử thay đổi.</div>
              )}
            </Card>
          </div>

          {/* Right: Action panel */}
          <div className="space-y-4">
            <Card className="p-5 sticky top-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Cập nhật trạng thái</h3>

              <label className="block text-xs font-medium text-gray-700 mb-1.5">
                Trạng thái mới
              </label>
              <select
                value={newStatus}
                onChange={(e) => setNewStatus(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
              >
                {Object.entries(STATUS_COLORS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v.label}
                  </option>
                ))}
              </select>

              <label className="block text-xs font-medium text-gray-700 mb-1.5 mt-3">
                Loại lỗi{" "}
                {newCategory === "other" && report.category === "other" && (
                  <span className="text-amber-600 font-normal">
                    (chưa phân loại)
                  </span>
                )}
              </label>
              <select
                value={newCategory}
                onChange={(e) => setNewCategory(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
              >
                {Object.entries(CATEGORY_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </select>

              <label className="block text-xs font-medium text-gray-700 mb-1.5 mt-3">
                Mức độ nghiêm trọng
              </label>
              <select
                value={newSeverity}
                onChange={(e) => setNewSeverity(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
              >
                {Object.entries(SEVERITY_COLORS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v.label}
                  </option>
                ))}
              </select>

              <label className="block text-xs font-medium text-gray-700 mb-1.5 mt-3">
                Ghi chú (optional)
              </label>
              <textarea
                rows={3}
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                placeholder="Nhập ghi chú về thay đổi này..."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none resize-none"
              />

              <button
                onClick={handleSave}
                disabled={saving || !hasChange}
                className="w-full mt-3 bg-brand-600 hover:bg-brand-700 disabled:bg-gray-300 text-white font-semibold py-2 rounded-lg text-sm transition"
              >
                {saving ? "Đang lưu..." : "Lưu thay đổi"}
              </button>

              {saveOk && (
                <div className="mt-2 bg-green-50 text-green-700 text-xs px-2.5 py-1.5 rounded">
                  ✅ Đã lưu thành công
                </div>
              )}
              {saveError && (
                <div className="mt-2 bg-red-50 text-red-700 text-xs px-2.5 py-1.5 rounded">
                  ⚠️ {saveError}
                </div>
              )}

              <div className="mt-4 pt-4 border-t border-gray-100 text-xs text-gray-500 space-y-1">
                <div>Tạo: {formatDate(report.created_at)}</div>
                <div>Cập nhật: {formatDate(report.updated_at)}</div>
                {report.resolved_at && <div>Resolved: {formatDate(report.resolved_at)}</div>}
                {report.closed_at && <div>Closed: {formatDate(report.closed_at)}</div>}
              </div>
            </Card>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}
