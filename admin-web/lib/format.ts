/**
 * lib/format.ts
 * =============
 * Helper format cho UI.
 */

export const STATUS_COLORS: Record<string, { bg: string; text: string; label: string }> = {
  open: { bg: "bg-blue-100", text: "text-blue-800", label: "Mới" },
  in_progress: { bg: "bg-yellow-100", text: "text-yellow-800", label: "Đang xử lý" },
  resolved: { bg: "bg-green-100", text: "text-green-800", label: "Đã sửa" },
  closed: { bg: "bg-gray-100", text: "text-gray-800", label: "Đã đóng" },
  wont_fix: { bg: "bg-purple-100", text: "text-purple-800", label: "Không sửa" },
};

export const SEVERITY_COLORS: Record<string, { bg: string; text: string; label: string }> = {
  low: { bg: "bg-gray-100", text: "text-gray-700", label: "Thấp" },
  medium: { bg: "bg-blue-100", text: "text-blue-700", label: "Trung bình" },
  high: { bg: "bg-orange-100", text: "text-orange-800", label: "Cao" },
  critical: { bg: "bg-red-100", text: "text-red-800", label: "Nghiêm trọng" },
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

export const ROLE_LABELS: Record<string, string> = {
  teacher: "Giáo viên",
  parent: "Phụ huynh",
  admin: "Admin (nhà trường)",
};

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

export function relativeTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  const then = new Date(iso).getTime();
  const now = Date.now();
  const diff = Math.floor((now - then) / 1000);
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
 * Chuẩn hóa URL của file đính kèm/hình ảnh để xem được trực tiếp trên trình duyệt máy khách:
 * - Giải quyết vấn đề URL chứa hostname nội bộ Docker "minio:9000" -> tự động chuyển thành hostname hiện tại (ví dụ localhost:9000)
 * - Xử lý đường dẫn tương đối (/bug-reports/...)
 * - Ngăn chặn XSS
 */
export function resolveAttachmentUrl(url: string | null | undefined): string {
  if (!url) return "";
  const trimmed = url.trim();
  if (!trimmed || /^\s*javascript:/i.test(trimmed)) return "";

  // Nếu chứa host nội bộ container MinIO (ví dụ http://minio:9000/...)
  if (trimmed.includes("minio:9000")) {
    const host =
      (typeof window !== "undefined" && window.location.hostname) || "localhost";
    return trimmed.replace(/https?:\/\/minio:9000/g, `http://${host}:9000`);
  }

  // Nếu là URL tuyệt đối hợp lệ
  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed;
  }

  // Nếu là đường dẫn tương đối (ví dụ /bug-reports/...)
  if (trimmed.startsWith("/")) {
    const host =
      (typeof window !== "undefined" && window.location.hostname) || "localhost";
    return `http://${host}:9000${trimmed}`;
  }

  return trimmed;
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

