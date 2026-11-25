/**
 * lib/format.ts
 * =============
 * Helper format cho UI.
 */

export const STATUS_COLORS: Record<string, { bg: string; text: string; label: string; enLabel: string }> = {
  open: { bg: "bg-blue-100", text: "text-blue-800", label: "Mới", enLabel: "Open" },
  in_progress: { bg: "bg-yellow-100", text: "text-yellow-800", label: "Đang xử lý", enLabel: "In Progress" },
  resolved: { bg: "bg-green-100", text: "text-green-800", label: "Đã sửa", enLabel: "Resolved" },
  closed: { bg: "bg-gray-100", text: "text-gray-800", label: "Đã đóng", enLabel: "Closed" },
  wont_fix: { bg: "bg-purple-100", text: "text-purple-800", label: "Không sửa", enLabel: "Won't Fix" },
};

export const SEVERITY_COLORS: Record<string, { bg: string; text: string; label: string; enLabel: string }> = {
  low: { bg: "bg-gray-100", text: "text-gray-700", label: "Thấp", enLabel: "Low" },
  medium: { bg: "bg-blue-100", text: "text-blue-700", label: "Trung bình", enLabel: "Medium" },
  high: { bg: "bg-orange-100", text: "text-orange-800", label: "Cao", enLabel: "High" },
  critical: { bg: "bg-red-100", text: "text-red-800", label: "Nghiêm trọng", enLabel: "Critical" },
};

export const CATEGORY_LABELS: Record<string, string> = {
  ui: "Giao diện",
  performance: "Hiệu năng",
  crash: "Crash",
  data: "Dữ liệu",
  notification: "Thông báo",
  network: "Mạng",
  auth: "Đăng nhập",
  other: "Khác",
};

export const CATEGORY_LABELS_EN: Record<string, string> = {
  ui: "UI / Layout",
  performance: "Performance",
  crash: "Crash",
  data: "Data",
  notification: "Notification",
  network: "Network",
  auth: "Authentication",
  other: "Other",
};

export const ROLE_LABELS: Record<string, string> = {
  teacher: "Giáo viên",
  parent: "Phụ huynh",
  admin: "Admin (nhà trường)",
};

export const ROLE_LABELS_EN: Record<string, string> = {
  teacher: "Teacher",
  parent: "Parent",
  admin: "School Admin",
};

export function getStatusLabel(key: string, lang: "vi" | "en" = "vi"): string {
  const item = STATUS_COLORS[key];
  if (!item) return key;
  return lang === "en" ? item.enLabel : item.label;
}

export function getSeverityLabel(key: string, lang: "vi" | "en" = "vi"): string {
  const item = SEVERITY_COLORS[key];
  if (!item) return key;
  return lang === "en" ? item.enLabel : item.label;
}

export function getCategoryLabel(key: string, lang: "vi" | "en" = "vi"): string {
  if (lang === "en") return CATEGORY_LABELS_EN[key] || CATEGORY_LABELS[key] || key;
  return CATEGORY_LABELS[key] || key;
}

export function getRoleLabel(key: string, lang: "vi" | "en" = "vi"): string {
  if (lang === "en") return ROLE_LABELS_EN[key] || ROLE_LABELS[key] || key;
  return ROLE_LABELS[key] || key;
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleString("vi-VN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatDateShort(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleDateString("vi-VN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
}

export function relativeTime(iso: string | null | undefined, lang: "vi" | "en" = "vi"): string {
  if (!iso) return "—";
  const then = new Date(iso).getTime();
  const now = Date.now();
  const diff = Math.floor((now - then) / 1000);
  if (lang === "en") {
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
    return formatDateShort(iso);
  }
  if (diff < 60) return `${diff} giây trước`;
  if (diff < 3600) return `${Math.floor(diff / 60)} phút trước`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} giờ trước`;
  if (diff < 604800) return `${Math.floor(diff / 86400)} ngày trước`;
  return formatDateShort(iso);
}

/**
 * Kiểm tra và làm sạch URL ngăn chặn XSS (chặn javascript:, data:, vbscript:).
 */
export function sanitizeUrl(url: string | null | undefined): string {
  if (!url) return "#";
  const trimmed = url.trim();
  if (/^(https?:\/\/|\/)/i.test(trimmed) && !/^\s*javascript:/i.test(trimmed)) {
    return trimmed;
  }
  return "#";
}

/**
 * Chuẩn hóa URL của file đính kèm/hình ảnh trước khi render:
 * - Chặn scheme nguy hiểm (javascript:)
 * - Backend đã trả URL tuyệt đối đúng host/scheme (MINIO_PUBLIC_URL),
 *   client không tự đoán hostname nữa.
 */
export function resolveAttachmentUrl(url: string | null | undefined): string {
  if (!url) return "";
  const trimmed = url.trim();
  if (!trimmed) return "";
  if (/^(https?:\/\/|\/)/i.test(trimmed)) {
    return trimmed;
  }
  return "";
}

/**
 * Kiểm tra xem một file đính kèm có phải là hình ảnh hay không.
 */
export function isImageAttachment(att: {
  mime_type?: string | null;
  file_name?: string | null;
}): boolean {
  if (att.mime_type && att.mime_type.toLowerCase().startsWith("image/")) {
    return true;
  }
  if (att.file_name) {
    const ext = att.file_name.split(".").pop()?.toLowerCase();
    return !!ext && ["jpg", "jpeg", "png", "gif", "webp", "bmp", "svg", "ico"].includes(ext);
  }
  return false;
}

/**
 * Định dạng kích thước file từ bytes sang chuỗi dễ đọc (B, KB, MB).
 */
export function formatFileSize(bytes: number | null | undefined): string {
  if (!bytes || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const val = bytes / Math.pow(1024, i);
  return `${val.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

