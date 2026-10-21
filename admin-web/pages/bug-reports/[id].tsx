/**
 * pages/bug-reports/[id].tsx
 * ==========================
 * Chi tiết bug report — restyle theo theme KinderLog.
 */

import { useEffect, useState } from "react";
import useSWR from "swr";
import { useRouter } from "next/router";
import Link from "next/link";
import AdminLayout from "@/components/AdminLayout";
import { Badge, Card, Spinner } from "@/components/ui";
import { Pill } from "@/components/ui-school";
import { apiFetch, ApiError, getToken } from "@/lib/api";
import ImageViewerModal from "@/components/ImageViewerModal";
import {
  CATEGORY_LABELS,
  ROLE_LABELS,
  SEVERITY_COLORS,
  STATUS_COLORS,
  formatDate,
  formatFileSize,
  isImageAttachment,
  resolveAttachmentUrl,
  sanitizeUrl,
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

function statusPillTone(key: string): "ok" | "warn" | "info" | "brand" | "neutral" {
  const c = STATUS_COLORS[key]?.bg || "";
  if (c.includes("green")) return "ok";
  if (c.includes("yellow")) return "warn";
  if (c.includes("blue")) return "info";
  if (c.includes("purple")) return "brand";
  return "neutral";
}

function sevPillTone(key: string): "bad" | "warn" | "info" | "neutral" {
  const c = SEVERITY_COLORS[key]?.bg || "";
  if (c.includes("red")) return "bad";
  if (c.includes("orange")) return "warn";
  if (c.includes("blue")) return "info";
  return "neutral";
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

  // State cho Modal xem ảnh phóng to trực tiếp
  const [viewerOpen, setViewerOpen] = useState(false);
  const [activeImageIndex, setActiveImageIndex] = useState(0);

  useEffect(() => {
    if (!getToken("adminApp")) {
      router.replace("/login");
    } else {
      setTokenReady(true);
    }
  }, [router]);

  const { data: report, error, mutate } = useSWR<DetailResponse>(
    tokenReady && id ? `/api/bug-reports/${id}` : null,
    (url: string) => apiFetch<DetailResponse>(url, { account: "adminApp" }),
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
      const body: Record<string, string> = {};
      if (newStatus !== report.status) body.status = newStatus;
      if (newCategory !== report.category) body.category = newCategory;
      if (newSeverity !== report.severity) body.severity = newSeverity;
      const trimmed = comment.trim();
      if (trimmed) body.comment = trimmed;

      const updated = await apiFetch<DetailResponse>(
        `/api/bug-reports/${report.bug_report_id}`,
        { method: "PATCH", body, account: "adminApp" },
      );
      setComment("");
      setSaveOk(true);
      await mutate(updated, { revalidate: true });
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

  const hasChange =
    !!report &&
    (newStatus !== report.status ||
      newCategory !== report.category ||
      newSeverity !== report.severity ||
      comment.trim().length > 0);

  const imageAttachments = (report?.attachments || []).filter(isImageAttachment);
  const otherAttachments = (report?.attachments || []).filter((att) => !isImageAttachment(att));

  const handleOpenImage = (attachmentId: string) => {
    const idx = imageAttachments.findIndex((img) => img.attachment_id === attachmentId);
    setActiveImageIndex(idx >= 0 ? idx : 0);
    setViewerOpen(true);
  };

  if (!tokenReady) return <Spinner />;

  if (error) {
    return (
      <AdminLayout currentPage="bug-reports">
        <div className="text-center py-16">
          <div className="text-5xl mb-3">😢</div>
          <div className="text-ink font-bold">Không tìm thấy bug report</div>
          <Link
            href="/bug-reports"
            className="text-sm mt-2 inline-block hover:underline"
            style={{ color: "#16665a" }}
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

  return (
    <AdminLayout currentPage="bug-reports">
      <div className="space-y-4 max-w-5xl">
        {/* Breadcrumb */}
        <div className="text-sm text-ink-soft">
          <Link href="/bug-reports" className="hover:underline" style={{ color: "#16665a" }}>
            Quản lý Bug Report
          </Link>
          <span className="mx-1.5">/</span>
          <span className="text-ink">Chi tiết</span>
        </div>

        {/* Header */}
        <Card className="p-6">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-2 flex-wrap">
                <Pill tone={statusPillTone(report.status)}>
                  {STATUS_COLORS[report.status]?.label || report.status}
                </Pill>
                <Pill tone={sevPillTone(report.severity)}>
                  {SEVERITY_COLORS[report.severity]?.label || report.severity}
                </Pill>
                <span className="text-xs text-ink-soft">
                  {CATEGORY_LABELS[report.category] || report.category}
                </span>
              </div>
              <h1 className="text-xl font-bold text-ink">{report.title}</h1>
              <div className="text-sm text-ink-soft mt-1.5">
                #{report.bug_report_id.slice(0, 8)} · tạo lúc{" "}
                {formatDate(report.created_at)}
              </div>
            </div>
          </div>

          <div className="mt-5 pt-5 border-t border-line">
            <h3 className="text-xs font-bold text-ink-faint uppercase tracking-wider mb-2">
              Mô tả chi tiết
            </h3>
            <p className="text-sm text-ink whitespace-pre-wrap leading-relaxed">
              {report.description}
            </p>
          </div>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          {/* Left */}
          <div className="lg:col-span-2 space-y-4">
            {/* Reporter & Assignee */}
            <Card className="p-5">
              <h3 className="text-sm font-bold text-ink mb-3">
                Thông tin liên quan
              </h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <div className="text-xs text-ink-faint mb-0.5">Người gửi</div>
                  <div className="font-semibold text-ink">
                    {report.user?.username || "—"}
                  </div>
                  <div className="text-xs text-ink-soft">
                    {ROLE_LABELS[report.user?.role] || report.user?.role}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-ink-faint mb-0.5">Người xử lý</div>
                  <div className="font-semibold text-ink">
                    {report.teacher?.full_name || (
                      <span className="text-ink-faint italic">Chưa gán</span>
                    )}
                  </div>
                  {report.teacher?.email && (
                    <div className="text-xs text-ink-soft">
                      {report.teacher.email}
                    </div>
                  )}
                </div>
              </div>
            </Card>

            {/* Device */}
            {(report.app_version || report.os_version || report.device_model) && (
              <Card className="p-5">
                <h3 className="text-sm font-bold text-ink mb-3">
                  Thiết bị & Môi trường
                </h3>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  {report.app_version && (
                    <div>
                      <div className="text-xs text-ink-faint">App version</div>
                      <div className="font-semibold">
                        {report.app_version}
                        {report.build_number && ` (build ${report.build_number})`}
                      </div>
                    </div>
                  )}
                  {report.os_version && (
                    <div>
                      <div className="text-xs text-ink-faint">OS</div>
                      <div className="font-semibold">{report.os_version}</div>
                    </div>
                  )}
                  {report.device_model && (
                    <div>
                      <div className="text-xs text-ink-faint">Device</div>
                      <div className="font-semibold">{report.device_model}</div>
                    </div>
                  )}
                  {report.network_type && (
                    <div>
                      <div className="text-xs text-ink-faint">Network</div>
                      <div className="font-semibold">{report.network_type}</div>
                    </div>
                  )}
                </div>
              </Card>
            )}

            {/* Attachments */}
            {report.attachments && report.attachments.length > 0 && (
              <Card className="p-5">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="text-sm font-bold text-ink flex items-center gap-2">
                    <span>File đính kèm</span>
                    <span className="text-xs px-2 py-0.5 rounded-full bg-sunken text-ink-soft">
                      {report.attachments.length}
                    </span>
                  </h3>
                  {imageAttachments.length > 0 && (
                    <span className="text-xs text-ink-soft">
                      Nhấn vào hình để xem trực tiếp
                    </span>
                  )}
                </div>

                {/* Phần 1: Hình ảnh đính kèm (Screenshots) */}
                {imageAttachments.length > 0 && (
                  <div className="mb-4">
                    <div className="text-xs font-semibold text-ink-faint uppercase tracking-wider mb-2">
                      Hình ảnh chụp màn hình ({imageAttachments.length})
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                      {imageAttachments.map((att) => {
                        const imgUrl = resolveAttachmentUrl(att.file_url);
                        return (
                          <div
                            key={att.attachment_id}
                            onClick={() => handleOpenImage(att.attachment_id)}
                            className="group relative border border-line rounded-xl overflow-hidden bg-white hover:border-teal-700/50 hover:shadow-md transition-all cursor-pointer flex flex-col"
                            title="Nhấn để xem hình ảnh trực tiếp"
                          >
                            {/* Khung thumbnail hình ảnh */}
                            <div className="relative aspect-video w-full bg-sunken overflow-hidden flex items-center justify-center">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={imgUrl}
                                alt={att.file_name}
                                className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
                                onError={(e) => {
                                  // Khi không load được thumbnail
                                  const target = e.target as HTMLElement;
                                  target.style.display = "none";
                                  const fallback = target.parentElement?.querySelector(".img-fallback");
                                  if (fallback) (fallback as HTMLElement).style.display = "flex";
                                }}
                              />
                              <div className="img-fallback hidden flex-col items-center justify-center text-ink-faint p-2 text-center text-xs">
                                <span className="text-xl mb-1">🖼️</span>
                                <span className="text-[10px]">Ảnh lỗi</span>
                              </div>

                              {/* Hover overlay hint */}
                              <div className="absolute inset-0 bg-neutral-900/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1.5 text-white font-medium text-xs">
                                <span>🔍</span>
                                <span>Xem ảnh</span>
                              </div>
                            </div>

                            {/* Thông tin tên file và dung lượng */}
                            <div className="p-2.5 flex-1 flex flex-col justify-between">
                              <div className="text-xs font-semibold text-ink truncate group-hover:text-teal-800 transition-colors">
                                {att.file_name}
                              </div>
                              <div className="text-[11px] text-ink-faint mt-1 flex items-center justify-between">
                                <span>{formatFileSize(att.file_size)}</span>
                                <span className="text-teal-700 font-semibold group-hover:underline">
                                  Phóng to ↗
                                </span>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* Phần 2: Tài liệu & file khác (nếu có) */}
                {otherAttachments.length > 0 && (
                  <div>
                    {imageAttachments.length > 0 && (
                      <div className="text-xs font-semibold text-ink-faint uppercase tracking-wider mb-2">
                        Tệp tin khác ({otherAttachments.length})
                      </div>
                    )}
                    <div className="space-y-2">
                      {otherAttachments.map((att) => {
                        const safeUrl = resolveAttachmentUrl(att.file_url) || sanitizeUrl(att.file_url);
                        return (
                          <a
                            key={att.attachment_id}
                            href={safeUrl}
                            download={att.file_name}
                            className="flex items-center gap-3 p-2.5 border border-line rounded-control hover:bg-sunken transition-colors"
                          >
                            <span className="text-2xl">📄</span>
                            <div className="flex-1 min-w-0">
                              <div className="text-sm font-semibold text-ink truncate">
                                {att.file_name}
                              </div>
                              <div className="text-xs text-ink-faint">
                                {att.mime_type}
                                {att.file_size && ` · ${formatFileSize(att.file_size)}`}
                              </div>
                            </div>
                            <span className="text-xs font-semibold" style={{ color: "#16665a" }}>
                              Tải về ⬇
                            </span>
                          </a>
                        );
                      })}
                    </div>
                  </div>
                )}
              </Card>
            )}

            {/* History */}
            <Card className="p-5">
              <h3 className="text-sm font-bold text-ink mb-3">
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
                        className="border-l-2 pl-3 py-1"
                        style={{ borderColor: "#a3c2b3" }}
                      >
                        <div className="text-xs text-ink-faint">
                          {formatDate(h.created_at)}
                        </div>
                        <div className="text-sm text-ink mt-0.5">
                          {h.old_status && h.new_status ? (
                            <>
                              <Pill tone={statusPillTone(h.old_status)}>
                                {oldC?.label || h.old_status}
                              </Pill>{" "}
                              →{" "}
                              <Pill tone={statusPillTone(h.new_status)}>
                                {newC?.label || h.new_status}
                              </Pill>
                            </>
                          ) : h.new_status ? (
                            <>
                              Đã tạo với trạng thái{" "}
                              <Pill tone={statusPillTone(h.new_status)}>
                                {newC?.label || h.new_status}
                              </Pill>
                            </>
                          ) : (
                            "Cập nhật"
                          )}
                        </div>
                        {h.comment && (
                          <div className="text-xs text-ink-soft mt-1 italic">
                            💬 {h.comment}
                          </div>
                        )}
                        {h.changed_by && (
                          <div className="text-xs text-ink-faint mt-0.5">
                            bởi {h.changed_by.username}
                          </div>
                        )}
                      </li>
                    );
                  })}
                </ol>
              ) : (
                <div className="text-sm text-ink-soft italic">
                  Chưa có lịch sử thay đổi.
                </div>
              )}
            </Card>
          </div>

          {/* Right */}
          <div className="space-y-4">
            <Card className="p-5 sticky top-6">
              <h3 className="text-sm font-bold text-ink mb-3">
                Cập nhật trạng thái
              </h3>

              <label className="klabel">Trạng thái mới</label>
              <select
                value={newStatus}
                onChange={(e) => setNewStatus(e.target.value)}
                className="kinput"
              >
                {Object.entries(STATUS_COLORS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v.label}
                  </option>
                ))}
              </select>

              <label className="klabel mt-3 block">Loại lỗi</label>
              <select
                value={newCategory}
                onChange={(e) => setNewCategory(e.target.value)}
                className="kinput"
              >
                {Object.entries(CATEGORY_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </select>

              <label className="klabel mt-3 block">Mức độ nghiêm trọng</label>
              <select
                value={newSeverity}
                onChange={(e) => setNewSeverity(e.target.value)}
                className="kinput"
              >
                {Object.entries(SEVERITY_COLORS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v.label}
                  </option>
                ))}
              </select>

              <label className="klabel mt-3 block">Ghi chú (optional)</label>
              <textarea
                rows={3}
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                placeholder="Nhập ghi chú về thay đổi này..."
                className="kinput"
                style={{ resize: "none" }}
              />

              <button
                onClick={handleSave}
                disabled={saving || !hasChange}
                className="kbtn kbtn-primary w-full justify-center mt-3"
              >
                {saving ? "Đang lưu..." : "Lưu thay đổi"}
              </button>

              {saveOk && (
                <div className="mt-2 px-2.5 py-1.5 rounded-control text-xs" style={{ background: "#E7F1EA", color: "#3F8B5C" }}>
                  ✅ Đã lưu thành công
                </div>
              )}
              {saveError && (
                <div className="mt-2 px-2.5 py-1.5 rounded-control text-xs" style={{ background: "#F6E6E1", color: "#BB4A34" }}>
                  ⚠️ {saveError}
                </div>
              )}

              <div className="mt-4 pt-4 border-t border-line text-xs text-ink-soft space-y-1">
                <div>Tạo: {formatDate(report.created_at)}</div>
                <div>Cập nhật: {formatDate(report.updated_at)}</div>
                {report.resolved_at && <div>Resolved: {formatDate(report.resolved_at)}</div>}
                {report.closed_at && <div>Closed: {formatDate(report.closed_at)}</div>}
              </div>
            </Card>
          </div>
        </div>
      </div>

      {/* Lightbox Modal xem ảnh trực tiếp trên màn hình hiện tại */}
      <ImageViewerModal
        isOpen={viewerOpen}
        onClose={() => setViewerOpen(false)}
        images={imageAttachments}
        currentIndex={activeImageIndex}
        onSelectIndex={setActiveImageIndex}
      />
    </AdminLayout>
  );
}