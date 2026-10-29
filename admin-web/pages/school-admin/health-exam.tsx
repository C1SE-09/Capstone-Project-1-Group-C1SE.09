/**
 * pages/school-admin/health-exam.tsx
 * =====================================
 * Màn hình quản trị "Sổ sức khoẻ học sinh" — theo đúng pattern các trang khác
 * (Học sinh / Phụ huynh / Giáo viên / Thời khoá biểu):
 *
 *   1. Thanh tiêu đề có nút hành động: ↻ Làm mới · 📥 Xuất Excel · 📤 Nhập file · (nút phụ)
 *   2. Dải bộ lọc: tìm kiếm + chọn lớp + chọn ngày ghi nhận.
 *   3. Bảng dữ liệu các bản ghi đã ghi nhận trong sổ sức khoẻ.
 *   4. Modal nhập Excel (dùng chung `ImportModal`-style) để đẩy số liệu cả lớp.
 *
 * Luồng nhập Excel (nút 📤 Nhập file):
 *   a. Tải file mẫu .xlsx do backend sinh ra (đã điền sẵn mã HS, họ tên, ngày sinh, giới tính).
 *   b. Cơ sở y tế điền số liệu đo vào file (file KHÔNG bị khóa bảo vệ).
 *   c. Tải file kết quả lên hệ thống → backend validate từng dòng, tự tính BMI +
 *      xếp loại thể trạng, lưu bản ghi hợp lệ và báo rõ dòng nào lỗi để sửa lại.
 *
 * API: GET  /api/health-exam/records?class_id=&examination_date=
 *      GET  /api/health-exam/template?class_id=...   (trả file .xlsx)
 *      POST /api/health-exam/import  (multipart: class_id + file)
 */

import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import {
  ClassFilterSelect,
  EmptyState,
  Modal,
  Pill,
  SearchBar,
  Spinner,
  Toast,
} from "@/components/ui-school";
import { clearToken, getStoredSchoolAdmin, getToken, refreshAccessToken } from "@/lib/api";
import { exportMultiSheetToExcel, exportToExcel, ExcelSheetData } from "@/lib/excel-helper";
import {
  HealthExamImportResult,
  HealthExamRecord,
  SchoolClass,
  downloadHealthExamTemplate,
  getClasses,
  getHealthExamRecords,
  importHealthExamFile,
} from "@/lib/admin-api";

/* ════════ Hằng số ════════ */

const ACCEPTED_EXT = [".xlsx", ".xls"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB — khớp giới hạn backend

/** Nhãn tiếng Việt của phân loại thể trạng. */
const CATEGORY_TONE: Record<string, "ok" | "warn" | "bad" | "neutral"> = {
  NORMAL: "ok",
  UNDERWEIGHT: "warn",
  OVERWEIGHT: "bad",
};

/** Màu avatar theo tên học sinh (xoay vòng, giống trang học sinh). */
const AVATAR_COLORS = ["#8A5E12", "#16665a", "#4B6F8C", "#BB4A34", "#5B4B8A", "#2E7D6B"];

function avatarColor(name: string) {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  return AVATAR_COLORS[hash % AVATAR_COLORS.length];
}

/* ════════ Trang ════════ */

export default function HealthExamPage() {
  const [ready, setReady] = useState(false);
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [query, setQuery] = useState("");
  const [selectedClassId, setSelectedClassId] = useState("");
  const [examDate, setExamDate] = useState("");
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "warn" | "brand" } | null>(null);

  /* Modal nhập Excel */
  const [importOpen, setImportOpen] = useState(false);
  const [importClassId, setImportClassId] = useState("");
  const [importDate, setImportDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [importFile, setImportFile] = useState<File | null>(null);
  const [importBusy, setImportBusy] = useState(false);
  const [importResult, setImportResult] = useState<HealthExamImportResult | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  /* ── Auth guard + danh sách lớp ── */
  useEffect(() => {
    const stored = getStoredSchoolAdmin();
    if (!getToken("schoolAdmin") || !stored) {
      window.location.href = "/login";
      return;
    }
    setReady(true);

    (async () => {
      try {
        const list = await getClasses();
        setClasses(list);
      } catch (err: any) {
        setToast({ msg: err?.message || "Không tải được danh sách lớp.", tone: "bad" });
      }
    })();
  }, []);

  /* ── Dữ liệu sổ sức khoẻ ── */
  const { data, error, mutate, isLoading } = useSWR(
    ready ? ["health-exam-records", selectedClassId, examDate] : null,
    () =>
      getHealthExamRecords({
        class_id: selectedClassId || undefined,
        examination_date: examDate || undefined,
      }),
    { refreshInterval: 30000 }
  );

  useEffect(() => {
    if (error && (error as any).status === 401) {
      if (!getToken("schoolAdmin")) {
        window.location.href = "/login";
        return;
      }
      refreshAccessToken().then((token) => {
        if (!token) {
          clearToken("schoolAdmin");
          window.location.href = "/login";
        } else {
          mutate();
        }
      });
    }
  }, [error, mutate]);

  const records = useMemo(() => data?.records ?? [], [data]);

  const filtered = useMemo(() => {
    const q = query.toLowerCase().trim();
    if (!q) return records;
    return records.filter(
      (r) =>
        r.full_name.toLowerCase().includes(q) ||
        (r.class_name || "").toLowerCase().includes(q) ||
        (r.health_category_label || "").toLowerCase().includes(q) ||
        (r.general_conclusion || "").toLowerCase().includes(q)
    );
  }, [records, query]);

  const stats = data?.stats ?? { normal: 0, underweight: 0, overweight: 0 };

  /* ══ Xuất Excel (giống trang học sinh: toàn trường = mỗi lớp 1 sheet) ══ */
  function handleExportExcel() {
    if (filtered.length === 0) {
      setToast({ msg: "Không có dữ liệu để xuất.", tone: "warn" });
      return;
    }
    const headers = [
      "Họ tên",
      "Lớp",
      "Ngày sinh",
      "Giới tính",
      "Ngày ghi nhận",
      "Chiều cao (cm)",
      "Cân nặng (kg)",
      "BMI",
      "Phân loại thể trạng",
      "Kết luận chung",
    ];
    const toRow = (r: HealthExamRecord) => [
      r.full_name,
      r.class_name || "",
      r.date_of_birth || "",
      r.gender === "male" ? "Nam" : r.gender === "female" ? "Nữ" : r.gender || "",
      r.examination_date,
      String(r.height),
      String(r.weight),
      r.bmi != null ? String(r.bmi) : "",
      r.health_category_label,
      r.general_conclusion || "",
    ];
    // Toàn trường (không lọc lớp) → mỗi lớp 1 sheet
    if (!selectedClassId) {
      const sheets: ExcelSheetData[] = [];
      for (const cl of classes) {
        const classRows = filtered.filter((r) => r.class_id === cl.id);
        if (classRows.length > 0) sheets.push({ sheetName: cl.name, headers, rows: classRows.map(toRow) });
      }
      const unassigned = filtered.filter((r) => !r.class_id || !classes.some((c) => c.id === r.class_id));
      if (unassigned.length > 0) sheets.push({ sheetName: "Chưa xếp lớp", headers, rows: unassigned.map(toRow) });
      if (sheets.length === 0) {
        setToast({ msg: "Không có dữ liệu để xuất.", tone: "warn" });
        return;
      }
      exportMultiSheetToExcel("so_suc_khoe_toan_truong.xlsx", sheets);
      setToast({ msg: `Đã xuất sổ sức khoẻ toàn trường ra ${sheets.length} sheet (chia theo từng lớp)`, tone: "ok" });
      return;
    }
    const currentClass = classes.find((c) => c.id === selectedClassId);
    const sheetName = currentClass ? currentClass.name : "SoSucKhoe";
    const filename = currentClass ? `so_suc_khoe_${currentClass.name.replace(/\s+/g, "_")}.xlsx` : "so_suc_khoe.xlsx";
    exportToExcel(filename, sheetName, headers, filtered.map(toRow));
    setToast({ msg: `Đã xuất ${filtered.length} bản ghi của lớp "${sheetName}" ra file Excel`, tone: "ok" });
  }

  /* ══ Mở modal nhập Excel ══ */
  function openImportModal() {
    setImportClassId(selectedClassId || "");
    setImportDate(new Date().toISOString().slice(0, 10));
    setImportFile(null);
    setImportResult(null);
    setImportError(null);
    if (fileInputRef.current) fileInputRef.current.value = "";
    setImportOpen(true);
  }

  function closeImportModal() {
    if (importBusy) return;
    setImportOpen(false);
  }

  /* ══ Tải file mẫu (theo lớp đang chọn trong modal, trống = tất cả lớp) ══ */
  async function handleDownloadTemplate() {
    try {
      await downloadHealthExamTemplate(importClassId || undefined, importDate);
      setToast({
        msg: importClassId
          ? "Đã tải file mẫu. Nhập số liệu đo vào file rồi tải lên lại."
          : "Đã tải file mẫu toàn trường. Nhập số liệu rồi tải lên lại.",
        tone: "ok",
      });
    } catch (err: any) {
      setImportError(
        err?.status === 401
          ? "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại rồi tải file mẫu."
          : err?.message || "Không tải được file mẫu."
      );
    }
  }

  /* ══ Chọn file kết quả ══ */
  function acceptFile(candidate: File | undefined | null) {
    if (!candidate) return;
    const name = candidate.name.toLowerCase();
    if (!ACCEPTED_EXT.some((ext) => name.endsWith(ext))) {
      setImportError("Định dạng file không hợp lệ. Vui lòng chọn file Excel (.xlsx).");
      setImportFile(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }
    if (candidate.size > MAX_FILE_SIZE) {
      setImportError(
        `File quá lớn (${(candidate.size / 1024 / 1024).toFixed(1)} MB). Giới hạn tối đa là 10 MB.`
      );
      setImportFile(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }
    if (candidate.size === 0) {
      setImportError("File tải lên đang trống.");
      setImportFile(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }
    setImportError(null);
    setImportResult(null);
    setImportFile(candidate);
  }

  /* ══ Gửi file lên backend ══ */
  async function handleImport() {
    if (!importFile) return;
    setImportBusy(true);
    setImportError(null);
    try {
      const res = await importHealthExamFile(importClassId || null, importFile);
      setImportResult(res);
      mutate();
      if (res.failed_count === 0 && res.success_count > 0) {
        setToast({ msg: `Đã nhập thành công ${res.success_count} học sinh.`, tone: "ok" });
      } else if (res.success_count > 0) {
        setToast({
          msg: `Đã nhập ${res.success_count}/${res.total_rows} dòng, còn ${res.failed_count} dòng lỗi cần sửa.`,
          tone: "warn",
        });
      } else {
        setToast({ msg: "Không có dòng nào được lưu. Xem chi tiết lỗi bên dưới.", tone: "bad" });
      }
    } catch (err: any) {
      setImportError(err?.message || "Đã xảy ra lỗi trong quá trình nhập dữ liệu.");
    } finally {
      setImportBusy(false);
    }
  }

  if (!ready) return null;

  const importClass = classes.find((c) => c.id === importClassId);

  return (
    <SchoolAdminLayout
      active="features"
      pageTitle="Sổ sức khoẻ học sinh"
      pageAction={
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => {
              mutate();
              setToast({ msg: "Đã đồng bộ dữ liệu mới nhất", tone: "brand" });
            }}
            className="kbtn kbtn-secondary"
            title="Làm mới"
          >
            ↻
          </button>
          <button
            onClick={handleExportExcel}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Xuất danh sách sổ sức khoẻ ra file Excel"
          >
            📥 Xuất Excel
          </button>
          <button
            onClick={openImportModal}
            className="kbtn kbtn-primary text-sm flex items-center gap-1.5"
            title="Nhập kết quả đo vào sổ sức khoẻ từ file Excel"
          >
            📤 Nhập kết quả
          </button>
        </div>
      }
    >
      {/* ══ Thống kê nhanh ══ */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Tổng bản ghi</div>
          <div className="text-2xl font-bold text-ink mt-1">{filtered.length}</div>
        </div>
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Bình thường</div>
          <div className="text-2xl font-bold mt-1" style={{ color: "#3F8B5C" }}>
            {stats.normal ?? 0}
          </div>
        </div>
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Suy dinh dưỡng</div>
          <div className="text-2xl font-bold mt-1" style={{ color: "#8A5E12" }}>
            {stats.underweight ?? 0}
          </div>
        </div>
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Thừa cân</div>
          <div className="text-2xl font-bold mt-1" style={{ color: "#BB4A34" }}>
            {stats.overweight ?? 0}
          </div>
        </div>
      </div>

      {/* ══ Bộ lọc ══ */}
      <div className="card p-3 mb-3 flex flex-col sm:flex-row sm:items-center gap-2.5">
        <div className="flex-1 min-w-0">
          <SearchBar
            value={query}
            onChange={setQuery}
            placeholder="Tìm theo tên học sinh, lớp, thể trạng, kết luận..."
          />
        </div>
        <div className="w-full sm:w-56">
          <ClassFilterSelect
            classes={classes}
            value={selectedClassId}
            onChange={setSelectedClassId}
          />
        </div>
        <div className="w-full sm:w-44">
          <input
            type="date"
            value={examDate}
            onChange={(e) => setExamDate(e.target.value)}
            className="kinput text-sm bg-white"
            title="Lọc theo ngày ghi nhận"
          />
        </div>
        {examDate && (
          <button
            onClick={() => setExamDate("")}
            className="kbtn kbtn-secondary text-xs whitespace-nowrap"
            title="Bỏ lọc theo ngày"
          >
            ✕ Bỏ ngày
          </button>
        )}
      </div>

      {/* ══ Bảng dữ liệu ══ */}
      <div className="card overflow-hidden">
        {isLoading ? (
          <Spinner />
        ) : error ? (
          <div className="text-center py-12">
            <div className="text-bad font-semibold mb-2">
              {(error as any)?.status === 401
                ? "Phiên đăng nhập đã hết hạn. Đang chuyển về trang đăng nhập..."
                : `Không thể tải dữ liệu sổ sức khoẻ (${(error as any)?.detail || "Vui lòng thử lại"})`}
            </div>
            <button onClick={() => mutate()} className="kbtn kbtn-secondary mt-2">
              Thử lại
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            icon="📒"
            title={query ? "Không có kết quả phù hợp." : "Chưa có dữ liệu sức khoẻ"}
            description={
              query
                ? "Thử từ khoá khác hoặc bỏ bớt bộ lọc."
                : "Dùng nút “📤 Nhập kết quả” để tải file mẫu Excel điền số liệu đo cho cả lớp."
            }
            action={
              !query ? (
                <button onClick={openImportModal} className="kbtn kbtn-primary text-sm">
                  📤 Nhập kết quả từ Excel
                </button>
              ) : undefined
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead
                className="text-xs uppercase tracking-wider"
                style={{ background: "#EFECE5", color: "#605D57" }}
              >
                <tr>
                  <th className="px-4 py-3 text-left font-semibold">Học sinh</th>
                  <th className="px-4 py-3 text-left font-semibold">Lớp</th>
                  <th className="px-4 py-3 text-left font-semibold">Ngày ghi nhận</th>
                  <th className="px-4 py-3 text-right font-semibold">Chiều cao</th>
                  <th className="px-4 py-3 text-right font-semibold">Cân nặng</th>
                  <th className="px-4 py-3 text-right font-semibold">BMI</th>
                  <th className="px-4 py-3 text-left font-semibold">Thể trạng</th>                  <th className="px-4 py-3 text-left font-semibold">Kết luận chung</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r, idx) => (
                  <tr key={r.id} className={idx > 0 ? "border-t border-line" : ""}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2.5">
                        <div
                          className="w-9 h-9 flex items-center justify-center rounded-full text-white font-bold shrink-0"
                          style={{ background: avatarColor(r.full_name) }}
                        >
                          {r.full_name.charAt(0).toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <div className="font-semibold text-ink truncate">{r.full_name}</div>
                          {r.date_of_birth && (
                            <div className="text-[11px] text-ink-faint">
                              {r.date_of_birth} ·{" "}
                              {r.gender === "male" ? "Nam" : r.gender === "female" ? "Nữ" : ""}
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-ink-soft whitespace-nowrap">
                      {r.class_name || "—"}
                    </td>
                    <td className="px-4 py-3 text-ink-soft whitespace-nowrap">
                      {r.examination_date}
                    </td>
                    <td className="px-4 py-3 text-right text-ink whitespace-nowrap">
                      {r.height} cm
                    </td>
                    <td className="px-4 py-3 text-right text-ink whitespace-nowrap">
                      {r.weight} kg
                    </td>
                    <td className="px-4 py-3 text-right font-semibold text-ink whitespace-nowrap">
                      {r.bmi != null ? r.bmi.toFixed(2) : "—"}
                    </td>
                    <td className="px-4 py-3">
                      <Pill tone={CATEGORY_TONE[r.health_category] ?? "neutral"}>
                        {r.health_category_label}
                      </Pill>
                    </td>
                    <td className="px-4 py-3 text-ink-soft">
                      <div className="max-w-[280px] truncate" title={r.general_conclusion || ""}>
                        {r.general_conclusion || "—"}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ══ Modal nhập kết quả từ Excel ══ */}
      <Modal
        open={importOpen}
        onClose={closeImportModal}
        title="Nhập kết quả vào sổ sức khoẻ"
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
                onClick={closeImportModal}
                disabled={importBusy}
                className="kbtn kbtn-secondary"
              >
                {importResult ? "Đóng" : "Hủy"}
              </button>
              {!importResult && (
                <button
                  type="button"
                  onClick={handleImport}
                  disabled={!importFile || importBusy}
                  className="kbtn kbtn-primary flex items-center gap-2"
                >
                  {importBusy && (
                    <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  )}
                  {importBusy ? "Đang nhập..." : "Nhập vào sổ sức khoẻ"}
                </button>
              )}
            </div>
          </div>
        }
      >
        <div className="space-y-4">
          <p className="text-sm text-ink-soft">
            Tải file mẫu Excel đã điền sẵn danh sách học sinh của lớp → cơ sở y tế điền số
            liệu đo → tải file kết quả lên hệ thống. Hệ thống tự tính BMI và báo rõ dòng
            nào bị lỗi để sửa lại.
          </p>

          {/* Bước 1: chọn lớp + ngày */}
          <div className="rounded-card border border-line bg-sunken/40 p-3.5 space-y-3">
            <div className="font-bold text-ink text-sm">Bước 1: Chọn lớp & ngày ghi nhận</div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="klabel mb-1.5">
                  Lớp <span className="text-bad ml-0.5">*</span>
                </label>
                <select
                  value={importClassId}
                  onChange={(e) => setImportClassId(e.target.value)}
                  className="kinput text-sm font-medium bg-white"
                >
                  <option value="">Tất cả lớp</option>
                  {classes.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                      {c.grade_label ? ` · ${c.grade_label}` : ""}
                      {c.room_number ? ` (${c.room_number})` : ""}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="klabel mb-1.5">Ngày ghi nhận</label>
                <input
                  type="date"
                  value={importDate}
                  onChange={(e) => setImportDate(e.target.value)}
                  className="kinput text-sm bg-white"
                />
              </div>
            </div>
            {importClass ? (
              <div className="text-[11px] text-ink-soft">
                File mẫu sẽ chứa danh sách học sinh đang theo học của lớp{" "}
                <strong className="text-ink">{importClass.name}</strong>.
              </div>
            ) : (
              <div className="text-[11px] text-ink-soft">
                File mẫu sẽ chứa <strong className="text-ink">tất cả lớp</strong>.
              </div>
            )}
          </div>

          {/* Bước 2: chọn file */}
          <div>
            <label className="klabel mb-1.5">Bước 2: Chọn file kết quả tải lên</label>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx,.xls"
              onChange={(e) => acceptFile(e.target.files?.[0])}
              className="hidden"
              id="health-exam-file-input"
            />
            <label
              htmlFor="health-exam-file-input"
              className="border-2 border-dashed border-line hover:border-brand rounded-card p-6 flex flex-col items-center justify-center cursor-pointer transition-colors text-center bg-white"
            >
              <div className="text-3xl mb-2">📁</div>
              <div className="text-sm font-semibold text-ink truncate max-w-full">
                {importFile ? importFile.name : "Nhấp để chọn file hoặc kéo thả vào đây"}
              </div>
              <div className="text-xs text-ink-faint mt-1">
                {importFile
                  ? `${(importFile.size / 1024).toFixed(0)} KB`
                  : "Hỗ trợ định dạng .xlsx, .xls (tối đa 10MB) — dùng đúng file mẫu đã tải ở bước 1"}
              </div>
            </label>
          </div>

          {importError && (
            <div className="rounded-control bg-bad/10 border border-bad/30 p-3 text-xs text-bad">
              ⚠ {importError}
            </div>
          )}

          {/* Kết quả import */}
          {importResult && (
            <div className="space-y-3">
              <div className="grid grid-cols-2 md:grid-cols-5 gap-2 text-center">
                <div className="p-2.5 rounded-control bg-sunken/60 border border-line">
                  <div className="text-[11px] text-ink-soft">Tổng dòng</div>
                  <div className="text-lg font-bold text-ink mt-0.5">{importResult.total_rows}</div>
                </div>
                <div className="p-2.5 rounded-control bg-ok/10 border border-ok/25">
                  <div className="text-[11px] text-ok">Thành công</div>
                  <div className="text-lg font-bold text-ok mt-0.5">
                    {importResult.success_count}
                  </div>
                </div>
                <div className="p-2.5 rounded-control bg-bad/10 border border-bad/25">
                  <div className="text-[11px] text-bad">Thất bại</div>
                  <div className="text-lg font-bold text-bad mt-0.5">
                    {importResult.failed_count}
                  </div>
                </div>
                <div className="p-2.5 rounded-control bg-sunken/60 border border-line">
                  <div className="text-[11px] text-ink-soft">Bản ghi mới</div>
                  <div className="text-lg font-bold text-ink mt-0.5">
                    {importResult.created_count}
                  </div>
                </div>
                <div className="p-2.5 rounded-control bg-sunken/60 border border-line">
                  <div className="text-[11px] text-ink-soft">Đã cập nhật</div>
                  <div className="text-lg font-bold text-ink mt-0.5">
                    {importResult.updated_count}
                  </div>
                </div>
              </div>

              {importResult.errors.length > 0 && (
                <div className="space-y-2">
                  <div className="font-bold text-bad text-xs">
                    Chi tiết lỗi ({importResult.failed_count} dòng bị từ chối)
                  </div>
                  <div className="max-h-64 overflow-y-auto rounded-control border border-bad/25 bg-bad/5 divide-y divide-bad/10">
                    {importResult.errors.map((issue) => (
                      <div key={`${issue.sheet_name || "x"}-${issue.row_number}-${issue.child_id || "x"}`} className="p-3">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span
                            className={`px-2 py-0.5 rounded-full text-white text-[11px] font-bold ${
                              issue.errors.length > 0 ? "bg-bad" : "bg-warn"
                            }`}
                          >
                            {issue.sheet_name ? `${issue.sheet_name} · Dòng ${issue.row_number}` : `Dòng ${issue.row_number}`}
                          </span>
                          {issue.full_name && (
                            <span className="text-xs font-semibold text-ink">{issue.full_name}</span>
                          )}
                          {issue.errors.length === 0 && (
                            <span className="text-[11px] text-warn font-semibold">
                              ⚠ Đã lưu kèm cảnh báo
                            </span>
                          )}
                        </div>
                        {issue.errors.length > 0 && (
                          <ul className="mt-1.5 space-y-0.5">
                            {issue.errors.map((e, i) => (
                              <li key={i} className="text-[11px] text-bad">
                                • {e}
                              </li>
                            ))}
                          </ul>
                        )}
                        {issue.warnings.length > 0 && (
                          <ul className="mt-1 space-y-0.5">
                            {issue.warnings.map((w, i) => (
                              <li key={i} className="text-[11px] text-warn">
                                ⚠ {w}
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    ))}
                  </div>
                  <div className="text-[11px] text-ink-soft leading-relaxed">
                    💡 <strong>Cách xử lý:</strong> các dòng có nền đỏ bị từ chối — sửa trong
                    file Excel gốc (đúng số dòng như báo cáo) rồi tải lại file lên. Các dòng
                    chỉ có cảnh báo (màu vàng) vẫn đã được lưu, hãy kiểm tra lại số liệu để chắc
                    chắn không nhập nhầm.
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </Modal>

      {toast && <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />}
    </SchoolAdminLayout>
  );
}
