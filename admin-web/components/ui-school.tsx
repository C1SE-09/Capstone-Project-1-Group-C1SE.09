/**
 * components/ui-school.tsx
 * =========================
 * UI components nhỏ dùng chung cho School Admin — y hệt pattern Flutter app.
 */

import { ReactNode, useEffect, useRef, useState } from "react";
import {
  downloadExcelTemplate,
  parseExcelOrCsvDetailed,
  DetectedSheetInfo,
} from "@/lib/excel-helper";

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
  value: number; // 0..1 hoặc 0..100
  tone?: "brand" | "ok" | "warn" | "bad";
  height?: number;
}) {
  const normalized = value > 1 ? value / 100 : value;
  const clamped = Math.max(0, Math.min(1, normalized));
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
    <div className="relative flex items-center">
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="#605D57"
        className="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none select-none z-10"
      >
        <path d="M15.5 14h-.79l-.28-.27A6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0A4.5 4.5 0 1 1 14 9.5 4.51 4.51 0 0 1 9.5 14z" />
      </svg>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder ?? "Tìm kiếm..."}
        className="kinput !pl-10 !pr-9"
        style={{ paddingLeft: "2.5rem", paddingRight: "2.25rem" }}
      />
      {value && (
        <button
          type="button"
          onClick={() => onChange("")}
          className="absolute right-2 top-1/2 -translate-y-1/2 text-ink-soft hover:text-ink w-6 h-6 flex items-center justify-center rounded-full hover:bg-black/5 z-10"
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

/* ════════ ClassFilterSelect ════════ */
export function ClassFilterSelect({
  classes,
  value,
  onChange,
  placeholder = "Tất cả các lớp",
  className = "",
}: {
  classes: { id: string; name: string; room_number?: string }[];
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  className?: string;
}) {
  return (
    <div className={`relative flex items-center ${className}`}>
      <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-soft text-sm pointer-events-none select-none z-10 leading-none">
        🏫
      </span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="kinput !pl-10 !pr-9 text-sm font-medium appearance-none cursor-pointer bg-white"
        style={{ paddingLeft: "2.5rem", paddingRight: "2.25rem" }}
      >
        <option value="">{placeholder}</option>
        {classes.map((c) => (
          <option key={c.id} value={c.id}>
            {c.name} {c.room_number ? `(${c.room_number})` : ""}
          </option>
        ))}
      </select>
      {value ? (
        <button
          type="button"
          onClick={() => onChange("")}
          title="Bỏ lọc lớp"
          className="absolute right-2.5 top-1/2 -translate-y-1/2 text-ink-soft hover:text-ink w-5 h-5 flex items-center justify-center text-xs rounded-full hover:bg-black/5 z-10"
        >
          ✕
        </button>
      ) : (
        <span className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-ink-soft text-xs select-none z-10">
          ▼
        </span>
      )}
    </div>
  );
}

/* ════════ ImportModal ════════ */
export interface ImportResult {
  total: number;
  success: number;
  failed: number;
  errors: string[];
  warnings?: string[];
}

export function ImportModal({
  open,
  onClose,
  title,
  description,
  sampleHeaders,
  sampleRow,
  templateFilename,
  allowOverwrite = false,
  overwriteLabel,
  overwriteHint,
  onImportRows,
  onSuccess,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  sampleHeaders: string[];
  sampleRow: string[];
  templateFilename: string;
  allowOverwrite?: boolean;
  overwriteLabel?: string;
  overwriteHint?: string;
  onImportRows: (rows: string[][], options?: { overwrite?: boolean }) => Promise<ImportResult>;
  onSuccess?: () => void;
}) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [overwrite, setOverwrite] = useState(true);
  const [parsedRows, setParsedRows] = useState<string[][]>([]);
  const [detectedSheets, setDetectedSheets] = useState<DetectedSheetInfo[]>([]);
  const [parsing, setParsing] = useState(false);
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Reset state when closing or opening
  useEffect(() => {
    if (open) {
      setFile(null);
      setOverwrite(true);
      setParsedRows([]);
      setDetectedSheets([]);
      setParsing(false);
      setImporting(false);
      setResult(null);
      setErrorMsg(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }, [open]);

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = e.target.files?.[0];
    if (!selected) return;

    setFile(selected);
    setErrorMsg(null);
    setResult(null);
    setParsing(true);
    try {
      const parseRes = await parseExcelOrCsvDetailed(selected, sampleHeaders);
      if (parseRes.rows.length === 0) {
        setErrorMsg("Không tìm thấy dòng dữ liệu nào trong file được chọn.");
        setParsedRows([]);
        setDetectedSheets([]);
      } else {
        setParsedRows(parseRes.rows);
        setDetectedSheets(parseRes.sheets);
      }
    } catch (err: any) {
      setErrorMsg(err?.message || "Không thể đọc file. Vui lòng kiểm tra định dạng.");
      setParsedRows([]);
      setDetectedSheets([]);
    } finally {
      setParsing(false);
    }
  }

  function handleDownloadTemplate() {
    downloadExcelTemplate(templateFilename, "Mau_Nhap", sampleHeaders, sampleRow);
  }

  async function handleStartImport() {
    if (parsedRows.length === 0) return;
    setImporting(true);
    setErrorMsg(null);
    try {
      const res = await onImportRows(parsedRows, { overwrite });
      setResult(res);
      if (res.success > 0 && onSuccess) {
        onSuccess();
      }
    } catch (err: any) {
      setErrorMsg(err?.message || "Đã xảy ra lỗi trong quá trình nhập dữ liệu.");
    } finally {
      setImporting(false);
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      size="lg"
      footer={
        <div className="flex items-center justify-between w-full">
          <button
            type="button"
            onClick={handleDownloadTemplate}
            className="kbtn kbtn-ghost text-xs text-brand flex items-center gap-1.5"
          >
            📥 Tải file mẫu (.xlsx)
          </button>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onClose}
              disabled={importing}
              className="kbtn kbtn-secondary"
            >
              {result ? "Đóng" : "Hủy"}
            </button>
            {!result && (
              <button
                type="button"
                onClick={handleStartImport}
                disabled={parsedRows.length === 0 || importing || parsing}
                className="kbtn kbtn-primary flex items-center gap-2"
              >
                {importing && (
                  <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                )}
                {importing
                  ? "Đang nhập..."
                  : `Nhập dữ liệu (${parsedRows.length} dòng)`}
              </button>
            )}
          </div>
        </div>
      }
    >
      <div className="space-y-4">
        {description && (
          <p className="text-sm text-ink-soft">{description}</p>
        )}

        {/* Step 1: Template download instruction */}
        <div className="rounded-card border border-line bg-sunken/40 p-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
          <div>
            <div className="font-bold text-ink mb-0.5">
              Bước 1: Chuẩn bị file dữ liệu
            </div>
            <div className="text-ink-soft">
              Hỗ trợ định dạng Excel (<strong>.xlsx</strong>, <strong>.xls</strong>) hoặc <strong>.csv</strong>. Bạn có thể tải file mẫu để nhập đúng cấu trúc.
            </div>
          </div>
          <button
            type="button"
            onClick={handleDownloadTemplate}
            className="kbtn kbtn-secondary text-xs whitespace-nowrap self-start sm:self-auto shrink-0"
          >
            📄 Tải file mẫu
          </button>
        </div>

        {/* Step 2: Upload dropzone */}
        <div>
          <label className="klabel mb-1.5">Bước 2: Chọn file dữ liệu tải lên</label>
          <input
            ref={fileInputRef}
            type="file"
            accept=".xlsx,.xls,.csv,.txt"
            onChange={handleFileChange}
            className="hidden"
            id="excel-file-upload-input"
          />
          <label
            htmlFor="excel-file-upload-input"
            className="border-2 border-dashed border-line hover:border-brand rounded-card p-6 flex flex-col items-center justify-center cursor-pointer transition-colors text-center bg-white"
          >
            <div className="text-3xl mb-2">📁</div>
            <div className="text-sm font-semibold text-ink">
              {file ? file.name : "Nhấp để chọn file hoặc kéo thả vào đây"}
            </div>
            <div className="text-xs text-ink-faint mt-1">
              Hỗ trợ các định dạng .xlsx, .xls, .csv (tối đa 10MB)
            </div>
          </label>
        </div>

        {/* Overwrite option */}
        {allowOverwrite && (
          <div className="rounded-card border border-line bg-sunken/40 p-3.5 space-y-1.5 transition-colors">
            <label className="flex items-center gap-2.5 cursor-pointer text-xs font-semibold text-ink select-none">
              <input
                type="checkbox"
                checked={overwrite}
                onChange={(e) => setOverwrite(e.target.checked)}
                className="w-4 h-4 rounded border-line text-brand focus:ring-brand accent-brand cursor-pointer"
              />
              <span>{overwriteLabel || "Ghi đè dữ liệu nếu đã tồn tại"}</span>
            </label>
            <p className="text-[11px] text-ink-soft pl-6.5 leading-relaxed">
              {overwriteHint ||
                (overwrite
                  ? "Đang bật ghi đè: Nếu hệ thống phát hiện dữ liệu trùng lặp (cùng khung giờ/thông tin), dữ liệu mới từ file Excel sẽ cập nhật thay thế dữ liệu cũ."
                  : "Đang tắt ghi đè: Hệ thống sẽ giữ nguyên dữ liệu hiện có và tự động bỏ qua các dòng bị trùng trong file Excel.")}
            </p>
          </div>
        )}

        {/* Parsing state */}
        {parsing && (
          <div className="flex items-center justify-center py-4 text-xs text-ink-soft gap-2">
            <span className="inline-block w-4 h-4 border-2 border-brand border-t-transparent rounded-full animate-spin" />
            Đang phân tích file...
          </div>
        )}

        {/* Error message */}
        {errorMsg && (
          <div className="rounded-control bg-bad/10 border border-bad/30 p-3 text-xs text-bad">
            ⚠ {errorMsg}
          </div>
        )}

        {/* Preview parsed data */}
        {parsedRows.length > 0 && !result && (
          <div className="space-y-2">
            <div className="flex flex-wrap items-center justify-between gap-1 text-xs font-semibold text-ink">
              <span>Đã phát hiện {parsedRows.length} dòng dữ liệu hợp lệ</span>
              <span className="text-ink-soft font-normal">Hiển thị trước tối đa 5 dòng</span>
            </div>

            {detectedSheets.length > 1 && (
              <div className="p-2.5 rounded-control bg-sunken/60 border border-line space-y-1.5 text-xs">
                <div className="font-semibold text-ink flex items-center justify-between">
                  <span>📄 Tự động nhận diện dữ liệu từ {detectedSheets.length} sheet:</span>
                  <span className="text-ink-soft text-[11px] font-normal">Mỗi sheet được chia theo lớp</span>
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {detectedSheets.map((s, idx) => (
                    <span
                      key={idx}
                      className="px-2.5 py-1 rounded-control bg-white border border-line-strong text-ink font-semibold text-[11px] shadow-sm flex items-center gap-1.5"
                    >
                      <span className="w-1.5 h-1.5 rounded-full bg-brand" />
                      <span>{s.name}:</span>
                      <span className="text-brand-strong">{s.count} dòng</span>
                    </span>
                  ))}
                </div>
              </div>
            )}

            <div className="border border-line rounded-control overflow-x-auto max-h-48">
              <table className="w-full text-xs text-left">
                <thead className="bg-sunken font-semibold text-ink border-b border-line sticky top-0">
                  <tr>
                    <th className="px-3 py-2 w-10">#</th>
                    {sampleHeaders.map((h, i) => (
                      <th key={i} className="px-3 py-2 whitespace-nowrap">
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {parsedRows.slice(0, 5).map((row, idx) => (
                    <tr key={idx} className="hover:bg-sunken/40">
                      <td className="px-3 py-2 text-ink-faint">{idx + 1}</td>
                      {sampleHeaders.map((_, colIdx) => (
                        <td
                          key={colIdx}
                          className="px-3 py-2 whitespace-nowrap text-ink-soft"
                        >
                          {row[colIdx] || "—"}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Import Results */}
        {result && (
          <div className="rounded-card border border-line p-4 space-y-3 bg-sunken/20">
            <div className="flex items-center gap-2">
              <span className="text-xl">
                {result.failed === 0 ? "🎉" : "ℹ"}
              </span>
              <span className="font-bold text-sm text-ink">
                Kết quả nhập dữ liệu
              </span>
            </div>
            <div className="grid grid-cols-3 gap-2 text-center text-xs">
              <div className="card p-2 bg-white">
                <div className="text-ink-soft">Tổng số dòng</div>
                <div className="text-base font-bold text-ink mt-0.5">
                  {result.total}
                </div>
              </div>
              <div className="card p-2 bg-white">
                <div className="text-ok">Thành công</div>
                <div className="text-base font-bold text-ok mt-0.5">
                  {result.success}
                </div>
              </div>
              <div className="card p-2 bg-white">
                <div className="text-bad">Thất bại</div>
                <div className="text-base font-bold text-bad mt-0.5">
                  {result.failed}
                </div>
              </div>
            </div>
            {result.warnings && result.warnings.length > 0 && (
              <div className="text-xs space-y-1">
                <div className="font-semibold text-warn flex items-center gap-1">
                  <span>⚠️</span>
                  <span>Cảnh báo & Ghi chú ({result.warnings.length}):</span>
                </div>
                <div className="max-h-36 overflow-y-auto bg-warn/10 border border-warn/30 rounded p-2 text-ink space-y-1">
                  {result.warnings.map((warn, i) => (
                    <div key={i} className="text-xs">
                      • {warn}
                    </div>
                  ))}
                </div>
              </div>
            )}
            {result.errors.length > 0 && (
              <div className="text-xs space-y-1">
                <div className="font-semibold text-bad">Chi tiết lỗi ({result.errors.length}):</div>
                <div className="max-h-32 overflow-y-auto bg-bad/5 border border-bad/20 rounded p-2 text-bad space-y-1">
                  {result.errors.map((err, i) => (
                    <div key={i}>• {err}</div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}