/**
 * components/ui-school.tsx
 * =========================
 * UI components nhỏ dùng chung cho School Admin — y hệt pattern Flutter app.
 */

import { ReactNode } from "react";

/* ════════ Spinner ════════ */
export function Spinner({ className = "" }: { className?: string }) {
  return (
    <div className={`flex items-center justify-center py-10 ${className}`}>
      <svg
        width="32"
        height="32"
        viewBox="0 0 24 24"
        fill="none"
        className="animate-spin"
      >
        <circle
          cx="12"
          cy="12"
          r="10"
          stroke="#16665a"
          strokeWidth="3"
          opacity="0.25"
        />
        <path
          d="M12 2a10 10 0 0 1 10 10"
          stroke="#16665a"
          strokeWidth="3"
          strokeLinecap="round"
        />
      </svg>
    </div>
  );
}

/* ════════ KPI / Metric Card ════════ */
interface KpiCardProps {
  icon: string;
  title: string;
  subtitle?: string;
  value: ReactNode;
  tone?: "brand" | "ok" | "warn" | "bad" | "info";
  rightSlot?: ReactNode;
  children?: ReactNode;
}

const TONE_COLOR: Record<NonNullable<KpiCardProps["tone"]>, { bg: string; fg: string; ring: string }> = {
  brand: { bg: "#E6EFEC", fg: "#16665a", ring: "#16665a" },
  ok: { bg: "#E7F1EA", fg: "#3F8B5C", ring: "#3F8B5C" },
  warn: { bg: "#F6EED9", fg: "#B0791B", ring: "#B0791B" },
  bad: { bg: "#F6E6E1", fg: "#BB4A34", ring: "#BB4A34" },
  info: { bg: "#E7EEF3", fg: "#4B6F8C", ring: "#4B6F8C" },
};

export function KpiCard({
  icon,
  title,
  subtitle,
  value,
  tone = "brand",
  rightSlot,
  children,
}: KpiCardProps) {
  const toneClass = TONE_COLOR[tone];
  return (
    <div className="card p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <div
              className="flex items-center justify-center text-base"
              style={{
                width: 32,
                height: 32,
                borderRadius: 8,
                background: toneClass.bg,
                color: toneClass.fg,
              }}
            >
              <span>{icon}</span>
            </div>
            <div className="min-w-0">
              <div className="text-[13px] font-bold text-ink">{title}</div>
              {subtitle && (
                <div className="text-[11px] text-ink-soft">{subtitle}</div>
              )}
            </div>
          </div>
          <div className="mt-3 text-2xl font-extrabold text-ink leading-none">
            {value}
          </div>
        </div>
        {rightSlot}
      </div>
      {children && <div className="mt-3">{children}</div>}
    </div>
  );
}

/* ════════ ProgressBar ════════ */
export function ProgressBar({
  value,
  tone = "brand",
  height = 8,
}: {
  value: number; // 0..1
  tone?: "brand" | "ok" | "warn" | "bad";
  height?: number;
}) {
  const clamped = Math.max(0, Math.min(1, value));
  const color = TONE_COLOR[tone === "ok" ? "ok" : tone === "warn" ? "warn" : tone === "bad" ? "bad" : "brand"].ring;
  return (
    <div
      style={{
        height,
        background: `${color}26`,
        borderRadius: 99,
        overflow: "hidden",
      }}
    >
      <div
        style={{
          width: `${clamped * 100}%`,
          height: "100%",
          background: color,
          borderRadius: 99,
          transition: "width 0.3s ease",
        }}
      />
    </div>
  );
}

/* ════════ Tag / Pill ════════ */
export function Pill({
  children,
  tone = "neutral",
  className = "",
}: {
  children: ReactNode;
  tone?: "neutral" | "brand" | "ok" | "warn" | "bad" | "info";
  className?: string;
}) {
  const map = {
    neutral: { bg: "#EFECE5", fg: "#605D57" },
    brand: { bg: "#E6EFEC", fg: "#114F46" },
    ok: { bg: "#E7F1EA", fg: "#3F8B5C" },
    warn: { bg: "#F6EED9", fg: "#8A5E12" },
    bad: { bg: "#F6E6E1", fg: "#BB4A34" },
    info: { bg: "#E7EEF3", fg: "#4B6F8C" },
  };
  const c = map[tone];
  return (
    <span
      className={`ktag ${className}`}
      style={{ background: c.bg, color: c.fg }}
    >
      {children}
    </span>
  );
}

/* ════════ Modal ════════ */
interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  size?: "sm" | "md" | "lg" | "xl";
}

const MODAL_SIZE = {
  sm: "max-w-md",
  md: "max-w-lg",
  lg: "max-w-2xl",
  xl: "max-w-4xl",
};

export function Modal({
  open,
  onClose,
  title,
  children,
  footer,
  size = "md",
}: ModalProps) {
  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(20,24,28,0.45)" }}
      onClick={onClose}
    >
      <div
        className={`bg-white rounded-card w-full ${MODAL_SIZE[size]} max-h-[92vh] flex flex-col shadow-pop`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-line">
          <h3 className="text-base font-bold text-ink">{title}</h3>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-control hover:bg-sunken text-ink-soft"
            aria-label="Đóng"
          >
            ✕
          </button>
        </div>
        <div className="flex-1 overflow-auto p-5">{children}</div>
        {footer && (
          <div className="px-5 py-3.5 border-t border-line flex justify-end gap-2">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}

/* ════════ Drawer (slide từ phải, dùng cho form chỉnh sửa) ════════ */
export function Drawer({
  open,
  onClose,
  title,
  children,
  footer,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex justify-end"
      style={{ background: "rgba(20,24,28,0.45)" }}
      onClick={onClose}
    >
      <div
        className="bg-white w-full max-w-lg h-full flex flex-col shadow-pop"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-line">
          <h3 className="text-base font-bold text-ink">{title}</h3>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-control hover:bg-sunken text-ink-soft"
            aria-label="Đóng"
          >
            ✕
          </button>
        </div>
        <div className="flex-1 overflow-auto p-5">{children}</div>
        {footer && (
          <div className="px-5 py-3.5 border-t border-line flex justify-end gap-2">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}

/* ════════ Toast (mini snackbar) ════════ */
export function Toast({
  message,
  tone = "brand",
  onClose,
}: {
  message: string;
  tone?: "brand" | "ok" | "warn" | "bad";
  onClose: () => void;
}) {
  const map = {
    brand: { bg: "#16665a", icon: "ℹ" },
    ok: { bg: "#3F8B5C", icon: "✓" },
    warn: { bg: "#B0791B", icon: "⚠" },
    bad: { bg: "#BB4A34", icon: "✕" },
  };
  const t = map[tone];
  return (
    <div
      className="fixed bottom-6 right-6 z-[60] flex items-center gap-3 px-4 py-2.5 rounded-control shadow-pop text-white text-sm"
      style={{ background: t.bg, maxWidth: 380 }}
      onClick={onClose}
    >
      <span className="font-bold">{t.icon}</span>
      <span className="flex-1">{message}</span>
      <button className="text-white/80" aria-label="Đóng">
        ✕
      </button>
    </div>
  );
}

/* ════════ FormField (label + input + helper) ════════ */
export function FormField({
  label,
  required,
  error,
  hint,
  children,
}: {
  label: string;
  required?: boolean;
  error?: string | null;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <div className="mb-3">
      <label className="klabel">
        {label}
        {required && <span className="text-bad ml-0.5">*</span>}
      </label>
      {children}
      {hint && !error && (
        <div className="text-xs text-ink-faint mt-1">{hint}</div>
      )}
      {error && (
        <div className="text-xs text-bad mt-1 font-medium">{error}</div>
      )}
    </div>
  );
}

/* ════════ SearchBar ════════ */
export function SearchBar({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <div className="relative">
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder ?? "Tìm kiếm..."}
        className="kinput pl-9"
      />
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="#605D57"
        className="absolute left-3 top-1/2 -translate-y-1/2"
      >
        <path d="M15.5 14h-.79l-.28-.27A6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0A4.5 4.5 0 1 1 14 9.5 4.51 4.51 0 0 1 9.5 14z" />
      </svg>
      {value && (
        <button
          onClick={() => onChange("")}
          className="absolute right-2 top-1/2 -translate-y-1/2 text-ink-soft hover:text-ink w-6 h-6 flex items-center justify-center"
        >
          ✕
        </button>
      )}
    </div>
  );
}

/* ════════ ConfirmDialog ════════ */
export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = "Xác nhận",
  cancelLabel = "Hủy",
  tone = "danger",
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: "danger" | "primary";
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Modal
      open={open}
      onClose={onCancel}
      title={title}
      size="sm"
      footer={
        <>
          <button onClick={onCancel} className="kbtn kbtn-secondary">
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            className={`kbtn ${tone === "danger" ? "kbtn-danger" : "kbtn-primary"}`}
          >
            {confirmLabel}
          </button>
        </>
      }
    >
      <p className="text-sm text-ink-soft leading-relaxed">{message}</p>
    </Modal>
  );
}

/* ════════ EmptyState ════════ */
export function EmptyState({
  icon = "📭",
  title,
  description,
  action,
}: {
  icon?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="text-center py-12">
      <div className="text-5xl mb-3 opacity-50">{icon}</div>
      <div className="text-ink font-semibold">{title}</div>
      {description && (
        <div className="text-sm text-ink-soft mt-1">{description}</div>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}