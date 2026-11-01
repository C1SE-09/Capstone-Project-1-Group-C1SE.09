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
 *   a. Tải file mẫu .xlsx do backend sinh ra (đã điền sẵn họ tên kèm biệt danh,
 *      ngày sinh, giới tính; nếu bé đã có số liệu sức khoẻ thì 3 cột chiều cao,
 *      cân nặng, kết luận chung cũng được điền sẵn).
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
import { DirectGridInput } from "@/components/DirectGridInput";
import {
  ClassFilterSelect,
  DateInput,
  Drawer,
  EmptyState,
  FormField,
  Modal,
  Pill,
  SearchBar,
  Spinner,
  Toast,
  todayIsoStr,
} from "@/components/ui-school";
import { clearToken, getStoredSchoolAdmin, getToken, refreshAccessToken } from "@/lib/api";
import {
  ExcelSheetData,
  exportMultiSheetToExcel,
  exportToExcel,
  formatDateToDmy,
  rowsToExcelFile,
} from "@/lib/excel-helper";
import {
  HealthExamImportResult,
  HealthExamRecord,
  SchoolClass,
  createHealthExamRecord,
  downloadHealthExamTemplate,
  getClasses,
  getHealthExamRecords,
  importHealthExamFile,
  updateHealthExamRecord,
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

/** Chuyển "DD/MM/YYYY" → "YYYY-MM-DD" để đưa vào input type=date. */
function toIsoDate(dmy: string) {
  const m = dmy.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (!m) return "";
  return `${m[3]}-${m[2]}-${m[1]}`;
}

/** Hôm nay theo giờ địa phương (không dùng toISOString vì lệch múi giờ UTC+7). */
function todayIso() {
  return todayIsoStr();
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
  const [importDate, setImportDate] = useState(() => todayIso());
  const [importFile, setImportFile] = useState<File | null>(null);
  const [importBusy, setImportBusy] = useState(false);
  const [importResult, setImportResult] = useState<HealthExamImportResult | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const [importMode, setImportMode] = useState<"grid" | "file">("grid");
  const [gridRows, setGridRows] = useState<string[][]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const healthExamHeaders = useMemo(
    () => [
      "Họ và tên",
      "Ngày sinh",
      "Giới tính",
      "Ngày ghi nhận",
      "Chiều cao",
      "Cân nặng",
      "Kết luận chung",
    ],
    []
  );

  const sampleHealthExamRow = useMemo(
    () => [
      "Nguyễn Bảo An (Bống)",
      "15/05/2021",
      "Nữ",
      importDate ? formatDateToDmy(importDate) : "20/10/2026",
      "102.5",
      "16.8",
      "Bình thường",
    ],
    [importDate]
  );

  const validGridRows = useMemo(
    () => gridRows.filter((r) => r.some((c) => c && c.trim().length > 0)),
    [gridRows]
  );

  /* Drawer sửa số liệu 1 dòng */
  const [editing, setEditing] = useState<HealthExamRecord | null>(null);
  const [editHeight, setEditHeight] = useState("");
  const [editWeight, setEditWeight] = useState("");
  const [editConclusion, setEditConclusion] = useState("");
  const [editDate, setEditDate] = useState("");
  const [editBusy, setEditBusy] = useState(false);

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
    {
      refreshInterval: editing || importOpen ? 0 : 30000,
      revalidateOnFocus: !(editing || importOpen),
    }
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
        (r.nickname || "").toLowerCase().includes(q) ||
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
      r.nickname ? `${r.full_name} (${r.nickname})` : r.full_name,
      r.class_name || "",
      r.date_of_birth || "",
      r.gender === "male" ? "Nam" : r.gender === "female" ? "Nữ" : r.gender || "",
      r.examination_date || "",
      r.height != null ? String(r.height) : "",
      r.weight != null ? String(r.weight) : "",
      r.bmi != null ? String(r.bmi) : "",
      r.health_category_label || "",
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
      setToast({ msg: "Đã xuất sổ sức khoẻ toàn trường ra file Excel.", tone: "ok" });
      return;
    }
    const currentClass = classes.find((c) => c.id === selectedClassId);
    const sheetName = currentClass ? currentClass.name : "SoSucKhoe";
    const filename = currentClass ? `so_suc_khoe_${currentClass.name.replace(/\s+/g, "_")}.xlsx` : "so_suc_khoe.xlsx";
    exportToExcel(filename, sheetName, headers, filtered.map(toRow));
    setToast({ msg: `Đã xuất ${filtered.length} học sinh của lớp "${sheetName}" ra file Excel.`, tone: "ok" });
  }

  /* ══ Mở modal sửa 1 dòng sổ sức khoẻ ══ */
  function openEditModal(r: HealthExamRecord) {
    setEditing(r);
    setEditHeight(r.height != null ? String(r.height) : "");
    setEditWeight(r.weight != null ? String(r.weight) : "");
    setEditConclusion(r.general_conclusion || "");
    setEditDate(
      r.examination_date
        ? toIsoDate(r.examination_date)
        : todayIso()
    );
  }

  function closeEditModal() {
    if (editBusy) return;
    setEditing(null);
  }

  async function handleSaveEdit() {
    if (!editing) return;
    // Chỉ cần có 1 trong 3 thông tin: chiều cao, cân nặng, kết luận chung.
    const hasHeight = editHeight.trim() !== "";
    const hasWeight = editWeight.trim() !== "";
    const hasConclusion = editConclusion.trim() !== "";
    if (!hasHeight && !hasWeight && !hasConclusion) {
      setToast({
        msg: "Vui lòng nhập ít nhất 1 thông tin: chiều cao, cân nặng hoặc kết luận chung",
        tone: "bad",
      });
      return;
    }
    let height: number | null = null;
    if (hasHeight) {
      height = Number(editHeight);
      if (!Number.isFinite(height) || height <= 0 || height > 200) {
        setToast({
          msg: "Chiều cao phải là số lớn hơn 0 và không vượt quá 200 cm",
          tone: "bad",
        });
        return;
      }
    }
    let weight: number | null = null;
    if (hasWeight) {
      weight = Number(editWeight);
      if (!Number.isFinite(weight) || weight <= 0 || weight > 100) {
        setToast({
          msg: "Cân nặng phải là số lớn hơn 0 và không vượt quá 100 kg",
          tone: "bad",
        });
        return;
      }
    }

    setEditBusy(true);
    try {
      if (editing.id) {
        await updateHealthExamRecord(editing.id, {
          height,
          weight,
          general_conclusion: hasConclusion ? editConclusion.trim() : null,
        });
      } else {
        await createHealthExamRecord({
          child_id: editing.child_id,
          height,
          weight,
          general_conclusion: hasConclusion ? editConclusion.trim() : null,
          examination_date: editDate || null,
        });
      }
      await mutate();
      setEditing(null);
      setToast({
        msg: `Đã cập nhật số liệu sức khoẻ của ${
          editing.nickname ? `${editing.full_name} (${editing.nickname})` : editing.full_name
        }.`,
        tone: "ok",
      });
    } catch (err: any) {
      setToast({ msg: err?.message || "Không lưu được số liệu. Vui lòng thử lại.", tone: "bad" });
    } finally {
      setEditBusy(false);
    }
  }

  /* ══ Mở modal nhập Excel ══ */
  function openImportModal() {
    setImportClassId(selectedClassId || "");
    setImportDate(todayIso());
    setImportFile(null);
    setImportResult(null);
    setImportError(null);
    const emptyRows: string[][] = [];
    for (let i = 0; i < 5; i++) {
      emptyRows.push(["", "", "", "", "", "", ""]);
    }
    setGridRows(emptyRows);
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
    let fileToUpload: File | null = importFile;
    if (importMode === "grid") {
      if (validGridRows.length === 0) {
        setImportError("Vui lòng nhập ít nhất 1 dòng số liệu vào bảng.");
        return;
      }
      fileToUpload = rowsToExcelFile(
        "so_suc_khoe_grid.xlsx",
        "SoSucKhoe",
        healthExamHeaders,
        validGridRows
      );
    }

    if (!fileToUpload) return;
    setImportBusy(true);
    setImportError(null);
    try {
      const res = await importHealthExamFile(importClassId || null, fileToUpload);
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
            onClick={() => {
              setImportMode("file");
              openImportModal();
            }}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Nhập kết quả từ file Excel"
          >
            📤 Nhập file
          </button>
          <button
            onClick={() => {
              setImportMode("grid");
              openImportModal();
            }}
            className="kbtn kbtn-primary text-sm flex items-center gap-1.5"
            title="Nhập số liệu sức khoẻ trực tiếp trên bảng tính"
          >
            <span>📊</span>
            <span>Nhập trực tiếp</span>
          </button>
        </div>
      }
    >
      {/* ══ Thống kê nhanh ══ */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-3 mb-3">
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Tổng học sinh</div>
          <div className="text-2xl font-bold text-ink mt-1">{filtered.length}</div>
        </div>
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Đã có số liệu</div>
          <div className="text-2xl font-bold text-ink mt-1">
            {filtered.filter((r) => r.has_record).length}
          </div>
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
      <div className="card p-3 mb-3 flex flex-col sm:flex-row sm:items-end gap-2.5">
        <div className="flex-1 min-w-0">
          <SearchBar
            value={query}
            onChange={setQuery}
            placeholder="Tìm theo tên học sinh, lớp, thể trạng, kết luận..."
          />
        </div>
        <div className="w-full sm:w-56">
          <label className="klabel mb-1" htmlFor="filter-class">
            Lớp
          </label>
          <ClassFilterSelect
            classes={classes}
            value={selectedClassId}
            onChange={setSelectedClassId}
          />
        </div>
        <div className="w-full sm:w-52">
          <label className="klabel mb-1" htmlFor="filter-exam-date">
            Ngày ghi nhận
          </label>
          <DateInput
            value={examDate}
            onChange={setExamDate}
            max={todayIso()}
            onInvalid={(msg) => setToast({ msg, tone: "bad" })}
          />
        </div>
        {examDate && (
          <button
            onClick={() => setExamDate("")}
            className="kbtn kbtn-secondary text-xs whitespace-nowrap self-end"
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
            title={
              query
                ? "Không có kết quả phù hợp."
                : examDate
                ? `Chưa có số liệu ghi nhận ngày ${formatDateToDmy(examDate)}`
                : "Chưa có học sinh nào"
            }
            description={
              query
                ? "Thử từ khoá khác hoặc bỏ bớt bộ lọc."
                : examDate
                ? "Chỉ hiển thị những học sinh có số liệu ghi nhận đúng ngày này. Thử ngày khác hoặc bỏ bộ lọc ngày."
                : "Dùng nút “📤 Nhập kết quả” để tải file mẫu Excel điền số liệu đo cho cả lớp."
            }
            action={
              !query && !examDate ? (
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
                  <th className="px-4 py-3 text-left font-semibold">Thể trạng</th>
                  <th className="px-4 py-3 text-left font-semibold">Kết luận chung</th>
                  <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r, idx) => (
                  <tr key={r.child_id} className={idx > 0 ? "border-t border-line" : ""}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2.5">
                        <div
                          className="w-9 h-9 flex items-center justify-center rounded-full text-white font-bold shrink-0"
                          style={{ background: avatarColor(r.full_name) }}
                        >
                          {r.full_name.charAt(0).toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <div className="font-semibold text-ink truncate">
                            {r.full_name}
                            {r.nickname && (
                              <span className="font-normal text-ink-soft"> ({r.nickname})</span>
                            )}
                          </div>
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
                      {r.examination_date || "—"}
                    </td>
                    <td className="px-4 py-3 text-right text-ink whitespace-nowrap">
                      {r.height != null ? `${r.height} cm` : "—"}
                    </td>
                    <td className="px-4 py-3 text-right text-ink whitespace-nowrap">
                      {r.weight != null ? `${r.weight} kg` : "—"}
                    </td>
                    <td className="px-4 py-3 text-right font-semibold text-ink whitespace-nowrap">
                      {r.bmi != null ? r.bmi.toFixed(2) : "—"}
                    </td>
                    <td className="px-4 py-3">
                      {r.health_category_label ? (
                        <Pill tone={CATEGORY_TONE[r.health_category || ""] ?? "neutral"}>
                          {r.health_category_label}
                        </Pill>
                      ) : (
                        <span className="text-[11px] text-ink-faint italic">Chưa có</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-ink-soft">
                      <div className="max-w-[280px] truncate" title={r.general_conclusion || ""}>
                        {r.general_conclusion || "—"}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => openEditModal(r)}
                        className="kbtn kbtn-ghost text-xs"
                        title={
                          r.id
                            ? "Sửa chiều cao, cân nặng và kết luận chung"
                            : "Nhập số liệu sức khoẻ cho học sinh này"
                        }
                      >
                        Sửa
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

            {/* ══ Modal nhập kết quả vào sổ sức khoẻ (Grid + Excel) ══ */}
      <Modal
        open={importOpen}
        onClose={closeImportModal}
        title="Nhập kết quả vào sổ sức khoẻ"
        size="xl"
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
                  disabled={
                    importBusy ||
                    (importMode === "grid" ? validGridRows.length === 0 : !importFile)
                  }
                  className="kbtn kbtn-primary flex items-center gap-2"
                >
                  {importBusy && (
                    <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  )}
                  {importBusy
                    ? "Đang nhập..."
                    : importMode === "grid"
                    ? `Nhập vào sổ sức khoẻ (${validGridRows.length} dòng)`
                    : "Nhập vào sổ sức khoẻ"}
                </button>
              )}
            </div>
          </div>
        }
      >
        <div className="space-y-4">
          <p className="text-sm text-ink-soft">
            Hỗ trợ nhập trực tiếp số liệu khám vào bảng bên dưới hoặc tải file Excel lên.
            Hệ thống tự tính BMI và báo rõ dòng nào bị lỗi để chỉnh sửa.
          </p>

          {/* Tab switcher: Nhập trực tiếp vs Tải file */}
          {!importResult && (
            <div className="flex border-b border-line gap-2">
              <button
                type="button"
                onClick={() => setImportMode("grid")}
                className={`px-4 py-2 text-xs font-semibold border-b-2 flex items-center gap-2 transition-all ${
                  importMode === "grid"
                    ? "border-brand text-brand bg-brand/5 rounded-t-sm"
                    : "border-transparent text-ink-soft hover:text-ink hover:border-line"
                }`}
              >
                <span>📊</span>
                <span>Bảng nhập trực tiếp (Web Grid)</span>
                {validGridRows.length > 0 && (
                  <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-brand text-white font-bold">
                    {validGridRows.length}
                  </span>
                )}
              </button>
              <button
                type="button"
                onClick={() => setImportMode("file")}
                className={`px-4 py-2 text-xs font-semibold border-b-2 flex items-center gap-2 transition-all ${
                  importMode === "file"
                    ? "border-brand text-brand bg-brand/5 rounded-t-sm"
                    : "border-transparent text-ink-soft hover:text-ink hover:border-line"
                }`}
              >
                <span>📁</span>
                <span>Tải file Excel</span>
                {importFile && (
                  <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-brand text-white font-bold">
                    1
                  </span>
                )}
              </button>
            </div>
          )}

          {/* Bước chọn lớp & ngày ghi nhận (dùng chung cho cả 2 tab) */}
          <div className="rounded-card border border-line bg-sunken/40 p-3.5 space-y-3">
            <div className="font-bold text-ink text-sm">Chọn lớp & ngày ghi nhận</div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="klabel mb-1.5">
                  Lớp <span className="text-bad ml-0.5">*</span>
                </label>
                <ClassFilterSelect
                  classes={classes}
                  value={importClassId}
                  onChange={setImportClassId}
                  placeholder="Tất cả lớp"
                  className="w-full"
                />
              </div>
              <div>
                <label className="klabel mb-1.5">Ngày ghi nhận</label>
                <DateInput
                  value={importDate}
                  max={todayIso()}
                  onChange={setImportDate}
                  onInvalid={(msg) => setToast({ msg, tone: "bad" })}
                />
              </div>
            </div>
            {importClass ? (
              <div className="text-[11px] text-ink-soft">
                Đang chọn lớp <strong className="text-ink">{importClass.name}</strong>.
              </div>
            ) : (
              <div className="text-[11px] text-ink-soft">
                Đang chọn <strong className="text-ink">tất cả lớp</strong>.
              </div>
            )}
          </div>

          {/* Nội dung Tab 1: Grid nhập trực tiếp */}
          {importMode === "grid" && !importResult && (
            <div className="space-y-3">
              <DirectGridInput
                headers={healthExamHeaders}
                sampleRow={sampleHealthExamRow}
                rows={gridRows}
                onChange={setGridRows}
                disabled={importBusy}
              />
            </div>
          )}

          {/* Nội dung Tab 2: Bước 2 chọn file Excel */}
          {importMode === "file" && !importResult && (
            <div>
              <label className="klabel mb-1.5">Chọn file kết quả tải lên</label>
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
                    : "Hỗ trợ định dạng .xlsx, .xls (tối đa 10MB)"}
                </div>
              </label>
            </div>
          )}

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

      {/* ══ Drawer chỉnh sửa số liệu 1 dòng ══ */}
      <Drawer
        open={!!editing}
        onClose={closeEditModal}
        title={
          editing
            ? editing.id
              ? "Chỉnh sửa số liệu sức khoẻ"
              : "Nhập số liệu sức khoẻ"
            : "Chỉnh sửa số liệu sức khoẻ"
        }
        footer={
          <>
            <button
              onClick={closeEditModal}
              className="kbtn kbtn-secondary"
              disabled={editBusy}
            >
              Hủy
            </button>
            <button onClick={handleSaveEdit} className="kbtn kbtn-primary" disabled={editBusy}>
              {editBusy ? "Đang lưu..." : editing?.id ? "Lưu thay đổi" : "Lưu số liệu"}
            </button>
          </>
        }
      >
        {editing && (
          <>
            <div className="text-xs text-ink-soft mb-3">
              Học sinh:{" "}
              <strong className="text-ink">
                {editing.nickname
                  ? `${editing.full_name} (${editing.nickname})`
                  : editing.full_name}
              </strong>
              {editing.class_name && (
                <>
                  {" · "}
                  Lớp {editing.class_name}
                </>
              )}
            </div>

            {!editing.id && (
              <FormField
                label="Ngày ghi nhận"
                hint={
                  editDate
                    ? `Đã chọn: ${formatDateToDmy(editDate)}`
                    : "Nhập theo định dạng dd/mm/yyyy"
                }
              >
                <DateInput
                  value={editDate}
                  max={todayIso()}
                  onChange={setEditDate}
                  onInvalid={(msg) => setToast({ msg, tone: "bad" })}
                />
              </FormField>
            )}

            <div className="grid grid-cols-2 gap-3">
              <FormField label="Chiều cao (cm)" hint="Có thể để trống nếu chỉ nhập kết luận">
                <input
                  className="kinput"
                  type="number"
                  step="0.1"
                  min="1"
                  max="200"
                  value={editHeight}
                  onChange={(e) => setEditHeight(e.target.value)}
                  placeholder="95.5"
                />
              </FormField>
              <FormField label="Cân nặng (kg)" hint="Có thể để trống nếu chỉ nhập kết luận">
                <input
                  className="kinput"
                  type="number"
                  step="0.1"
                  min="1"
                  max="100"
                  value={editWeight}
                  onChange={(e) => setEditWeight(e.target.value)}
                  placeholder="14.2"
                />
              </FormField>
            </div>

            <FormField label="Kết luận chung" hint="Có thể để trống nếu đã nhập chiều cao và cân nặng">
              <textarea
                className="kinput resize-y"
                value={editConclusion}
                onChange={(e) => setEditConclusion(e.target.value)}
                rows={4}
                maxLength={2000}
                placeholder="Nhập kết luận của đợt ghi nhận..."
              />
            </FormField>

            <div className="text-xs text-ink-faint">
              💡 Hệ thống tự tính BMI và xếp loại thể trạng theo chuẩn WHO dựa trên tuổi và
              giới tính của học sinh.
            </div>
          </>
        )}
      </Drawer>

      {toast && <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />}
    </SchoolAdminLayout>
  );
}
