/**
 * pages/bug-reports/[id].tsx
 * ==========================
 * Chi tiết bug report — 100% chuẩn Figma Frame 04: "GV · Admin Web · 04 — Báo lỗi: Chi tiết" (#454:3464)
 */

import { useEffect, useState } from "react";
import useSWR from "swr";
import { useRouter } from "next/router";
import Link from "next/link";
import AdminLayout from "@/components/AdminLayout";
import { Spinner } from "@/components/ui";
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

  const [activeImageIndex, setActiveImageIndex] = useState<number | null>(null);

  useEffect(() => {
    if (!getToken("adminApp")) {
      router.replace("/login");
    } else {
      setTokenReady(true);
    }
  }, [router]);

  const { data: report, mutate } = useSWR<DetailResponse>(
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

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!id || typeof id !== "string") return;

    setSaving(true);
    setSaveError(null);
    setSaveOk(false);

    try {
      await apiFetch<DetailResponse>(`/api/bug-reports/${id}`, {
        account: "adminApp",
        method: "PATCH",
        body: JSON.stringify({
          status: newStatus !== report?.status ? newStatus : undefined,
          category: newCategory !== report?.category ? newCategory : undefined,
          severity: newSeverity !== report?.severity ? newSeverity : undefined,
          comment: comment.trim() || undefined,
        }),
      });

      setComment("");
      setSaveOk(true);
      await mutate();
      setTimeout(() => setSaveOk(false), 3000);
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        setSaveError(err.detail || "Cập nhật thất bại");
      } else {
        setSaveError("Lỗi kết nối");
      }
    } finally {
      setSaving(false);
    }
  };

  const imageAttachments = (report?.attachments || []).filter((a) =>
    isImageAttachment(a)
  );
  const otherAttachments = (report?.attachments || []).filter(
    (a) => !isImageAttachment(a)
  );

  if (!tokenReady || !report) {
    return (
      <AdminLayout currentPage="bug-reports">
        <Spinner />
      </AdminLayout>
    );
  }

  return (
    <AdminLayout currentPage="bug-reports">
      <div className="space-y-6 max-w-5xl">
        {/* Breadcrumb */}
        <div className="flex items-center gap-2 text-xs font-bold text-[#65727D]">
          <Link href="/bug-reports" className="hover:text-[#087F70] transition">
            ← Danh sách báo lỗi
          </Link>
          <span>/</span>
          <span className="text-[#102737]">Chi tiết #{report.bug_report_id.slice(0, 8)}</span>
        </div>

        {/* ─── Header Card (Figma 454:3484) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-7 shadow-soft">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2 mb-2 flex-wrap">
                <Pill tone={statusPillTone(report.status)}>
                  {STATUS_COLORS[report.status]?.label || report.status}
                </Pill>
                <Pill tone={sevPillTone(report.severity)}>
                  {SEVERITY_COLORS[report.severity]?.label || report.severity}
                </Pill>
                <span className="text-xs font-bold text-[#65727D] bg-[#F6F7F8] px-2.5 py-1 rounded-full">
                  {CATEGORY_LABELS[report.category] || report.category}
                </span>
              </div>
              <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
                {report.title}
              </h1>
              <div className="text-xs text-[#65727D] mt-1.5 font-medium">
                Gửi lúc {formatDate(report.created_at)} bởi{" "}
                <span className="text-[#102737] font-bold">
                  {report.teacher?.full_name || report.user?.username}
                </span>{" "}
                ({ROLE_LABELS[report.user?.role] || report.user?.role})
              </div>
            </div>
          </div>

          <div className="mt-6 pt-6 border-t border-[#E5E8EB]">
            <h3 className="text-xs font-bold text-[#8C9BA5] uppercase tracking-wider mb-2">
              Mô tả chi tiết sự cố
            </h3>
            <p className="text-sm text-[#102737] whitespace-pre-wrap leading-relaxed bg-[#F6F7F8] p-4 rounded-[16px] border border-[#E5E8EB]/60">
              {report.description}
            </p>
          </div>
        </div>

        {/* ─── Grid 2 cột: Ảnh & Thiết bị vs Cập nhật ─── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          
          {/* Cột trái (7 cols): Ảnh đính kèm & Thiết bị */}
          <div className="lg:col-span-7 space-y-6">
            
            {/* Ảnh đính kèm (Figma 454:3504) */}
            <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft">
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-extrabold text-base text-[#102737] flex items-center gap-2">
                  <span>Ảnh đính kèm</span>
                  <span className="text-xs px-2.5 py-0.5 rounded-full bg-[#E6F3EB] text-[#087F70] font-bold">
                    {imageAttachments.length}
                  </span>
                </h3>
                {imageAttachments.length > 0 && (
                  <span className="text-xs text-[#65727D]">
                    Nhấn vào ảnh để phóng to
                  </span>
                )}
              </div>

              {imageAttachments.length > 0 ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  {imageAttachments.map((att, idx) => {
                    const imgUrl = resolveAttachmentUrl(att.file_url);
                    return (
                      <div
                        key={att.attachment_id}
                        onClick={() => setActiveImageIndex(idx)}
                        className="group relative aspect-video bg-[#F6F7F8] rounded-[16px] overflow-hidden border border-[#E5E8EB] cursor-pointer hover:border-[#087F70] transition"
                      >
                        <img
                          src={imgUrl}
                          alt={att.file_name}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-200"
                        />
                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white text-xs font-bold transition">
                          🔍 Xem ảnh
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="py-6 text-center text-xs text-[#8C9BA5]">
                  Không có ảnh chụp màn hình đính kèm.
                </div>
              )}

              {otherAttachments.length > 0 && (
                <div className="mt-4 pt-4 border-t border-[#E5E8EB] space-y-2">
                  <div className="text-xs font-bold text-[#8C9BA5] uppercase">File khác</div>
                  {otherAttachments.map((att) => (
                    <a
                      key={att.attachment_id}
                      href={sanitizeUrl(resolveAttachmentUrl(att.file_url))}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-between p-3 rounded-[12px] bg-[#F6F7F8] hover:bg-[#E6F3EB] text-xs font-semibold text-[#102737] transition"
                    >
                      <span>📎 {att.file_name}</span>
                      <span className="text-[#65727D]">{formatFileSize(att.file_size)}</span>
                    </a>
                  ))}
                </div>
              )}
            </div>

            {/* Môi trường & Thiết bị */}
            <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft">
              <h3 className="font-extrabold text-base text-[#102737] mb-4">
                Môi trường thiết bị
              </h3>
              <div className="grid grid-cols-2 gap-4 text-xs">
                <div className="p-3 bg-[#F6F7F8] rounded-[14px]">
                  <div className="text-[#8C9BA5] font-bold">App Version</div>
                  <div className="font-extrabold text-[#102737] text-sm mt-0.5">
                    {report.app_version || "1.0.0"} {report.build_number ? `(${report.build_number})` : ""}
                  </div>
                </div>
                <div className="p-3 bg-[#F6F7F8] rounded-[14px]">
                  <div className="text-[#8C9BA5] font-bold">Hệ điều hành</div>
                  <div className="font-extrabold text-[#102737] text-sm mt-0.5">
                    {report.os_version || "Không xác định"}
                  </div>
                </div>
                <div className="p-3 bg-[#F6F7F8] rounded-[14px]">
                  <div className="text-[#8C9BA5] font-bold">Thiết bị</div>
                  <div className="font-extrabold text-[#102737] text-sm mt-0.5">
                    {report.device_model || "Mobile Client"}
                  </div>
                </div>
                <div className="p-3 bg-[#F6F7F8] rounded-[14px]">
                  <div className="text-[#8C9BA5] font-bold">Kết nối mạng</div>
                  <div className="font-extrabold text-[#102737] text-sm mt-0.5">
                    {report.network_type || "WiFi / 4G"}
                  </div>
                </div>
              </div>
            </div>

          </div>

          {/* Cột phải (5 cols): Xử lý & Cập nhật trạng thái */}
          <div className="lg:col-span-5 space-y-6">
            
            {/* Form Cập nhật */}
            <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft">
              <h3 className="font-extrabold text-base text-[#102737] mb-4">
                Cập nhật xử lý
              </h3>

              <form onSubmit={handleUpdate} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold text-[#65727D] mb-1.5 uppercase">
                    Trạng thái xử lý
                  </label>
                  <select
                    value={newStatus}
                    onChange={(e) => setNewStatus(e.target.value)}
                    className="w-full h-11 px-3 rounded-[12px] border border-[#E5E8EB] text-sm font-semibold text-[#102737] focus:outline-none focus:border-[#087F70]"
                  >
                    {Object.entries(STATUS_COLORS).map(([k, v]) => (
                      <option key={k} value={k}>
                        {v.label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#65727D] mb-1.5 uppercase">
                    Mức độ nghiêm trọng
                  </label>
                  <select
                    value={newSeverity}
                    onChange={(e) => setNewSeverity(e.target.value)}
                    className="w-full h-11 px-3 rounded-[12px] border border-[#E5E8EB] text-sm font-semibold text-[#102737] focus:outline-none focus:border-[#087F70]"
                  >
                    {Object.entries(SEVERITY_COLORS).map(([k, v]) => (
                      <option key={k} value={k}>
                        {v.label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#65727D] mb-1.5 uppercase">
                    Ghi chú xử lý
                  </label>
                  <textarea
                    rows={3}
                    value={comment}
                    onChange={(e) => setComment(e.target.value)}
                    placeholder="Nhập ghi chú xử lý (sửa lỗi, lý do đóng, ...)"
                    className="w-full p-3 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] focus:outline-none focus:border-[#087F70]"
                  />
                </div>

                {saveError && (
                  <div className="p-3 bg-[#FDEAE5] text-[#A93832] rounded-[12px] text-xs font-medium">
                    {saveError}
                  </div>
                )}
                {saveOk && (
                  <div className="p-3 bg-[#E5F5E7] text-[#087F70] rounded-[12px] text-xs font-bold">
                    ✓ Cập nhật báo lỗi thành công!
                  </div>
                )}

                <button
                  type="submit"
                  disabled={saving}
                  className="w-full h-11 bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-xs rounded-full flex items-center justify-center gap-2 shadow-sm transition disabled:opacity-50"
                >
                  {saving ? "Đang lưu..." : "Lưu thay đổi"}
                </button>
              </form>
            </div>

            {/* Lịch sử xử lý */}
            <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft">
              <h3 className="font-extrabold text-base text-[#102737] mb-3">
                Lịch sử thay đổi
              </h3>
              <div className="space-y-3">
                {report.history && report.history.length > 0 ? (
                  report.history.map((h) => (
                    <div key={h.history_id} className="text-xs p-3 bg-[#F6F7F8] rounded-[14px]">
                      <div className="font-bold text-[#102737]">
                        {h.changed_by?.username || "Admin"} · {formatDate(h.created_at)}
                      </div>
                      <div className="text-[#65727D] mt-1">
                        Trạng thái: <span className="font-bold">{h.old_status}</span> →{" "}
                        <span className="font-bold text-[#087F70]">{h.new_status}</span>
                      </div>
                      {h.comment && (
                        <div className="mt-1 text-[#102737] italic">&ldquo;{h.comment}&rdquo;</div>
                      )}
                    </div>
                  ))
                ) : (
                  <div className="text-xs text-[#8C9BA5]">Chưa có lịch sử thay đổi.</div>
                )}
              </div>
            </div>

          </div>

        </div>

        {/* Modal xem ảnh */}
        {activeImageIndex !== null && (
          <ImageViewerModal
            isOpen={activeImageIndex !== null}
            images={imageAttachments}
            currentIndex={activeImageIndex}
            onSelectIndex={setActiveImageIndex}
            onClose={() => setActiveImageIndex(null)}
          />
        )}
      </div>
    </AdminLayout>
  );
}
