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

