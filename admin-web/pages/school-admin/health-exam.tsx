/**
 * pages/school-admin/health-exam.tsx
 * =====================================
 * Màn hình quản trị "Sổ sức khoẻ học sinh" — Đồng bộ phong cách UI/UX SaaS chuẩn Excel
 * (Bulk Edit) tương tự trang Quản lý phụ huynh và Quản lý học sinh.
 *
 * Tính năng chính:
 *   1. Chế độ Xem (View Mode - Mặc định):
 *      - Bảng text phẳng sạch sẽ, không viền input, không rối mắt.
 *      - Cột Học sinh hiển thị Avatar chữ cái đầu, Họ tên (đậm), Biệt danh và Ngày sinh / Giới tính nhỏ mờ bên dưới.
 *      - Cột Thể trạng hiển thị Badge bo tròn (Xanh lá: Bình thường, Vàng/Đỏ: Thiếu cân/Thừa cân, Xám: Chưa có).
 *      - Cột Thao tác: Icon Sửa ✏️ (mở drawer chi tiết) và icon Xóa 🗑️ (xác nhận xóa bản ghi sức khỏe).
 *
 *   2. Chế độ Sửa (Bulk Edit - Chuẩn Excel):
 *      - Bật bằng nút "✏️ Chỉnh sửa" trên Toolbar (không dùng switch gạt).
 *      - Toàn bộ các dòng chuyển thành ô Input/Textarea viền mỏng xám mảnh (border-slate-300 rounded-md).
 *      - Nút "Đang sửa" biến mất, thay bằng icon Xóa 🗑️ (xóa trắng dữ liệu đang nhập của dòng).
 *      - Nút "💾 Lưu tất cả thay đổi" và "✕ Hủy thay đổi" trên Toolbar, kèm banner báo số dòng thay đổi chưa lưu.
 *
 *   3. Ràng buộc dữ liệu y tế mầm non (Validation & Sanitization):
 *      - Ngày ghi nhận: <input type="date"> chuẩn YYYY-MM-DD, hiển thị DD/MM/YYYY, chặn ngày tương lai (max={todayIso()}).
 *      - Chiều cao (cm): Chỉ nhập số, dải hợp lệ 40 - 150 cm. Viền đỏ cảnh báo nếu vượt dải.
 *      - Cân nặng (kg): Chỉ nhập số (cho phép số thập phân), dải hợp lệ 5 - 50 kg. Viền đỏ nếu vượt dải.
 *      - Chỉ số BMI: Read-only (không cho nhập trực tiếp), tự động tính realtime: Cân nặng / (Chiều cao/100)^2.
 *        Làm tròn và format gọn (ví dụ 15.8, loại bỏ số 0 thừa như 13.3 thay vì 13.30).
 *      - Thể trạng realtime: Tự động phân loại ngay khi gõ chiều cao/cân nặng.
 *      - Kết luận chung: Dùng <textarea rows={2}> nhiều dòng ở Edit Mode, line-clamp-2 chống tràn ở View Mode.
 *
 *   4. Xuất / Nhập Excel:
 *      - Xuất file Excel toàn trường hoặc theo lớp.
 *      - Nhập file Excel số liệu khám định kỳ từ cơ sở y tế.
 */

import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import {
  ClassFilterSelect,
  DateInput,
  Drawer,
  EmptyState,
  FormField,
  Modal,
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
} from "@/lib/excel-helper";
import {
  HealthExamImportResult,
  HealthExamRecord,
  SchoolClass,
  createHealthExamRecord,
  deleteHealthExamRecord,
  downloadHealthExamTemplate,
  getClasses,
  getHealthExamRecords,
  importHealthExamFile,
  updateHealthExamRecord,
} from "@/lib/admin-api";

/* ════════ Hằng số & Validation Y tế Mầm non ════════ */

const ACCEPTED_EXT = [".xlsx", ".xls"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

// Giới hạn hợp lệ của trẻ mầm non (1 - 6 tuổi)
const MIN_CHILD_HEIGHT = 40;  // cm
const MAX_CHILD_HEIGHT = 150; // cm
const MIN_CHILD_WEIGHT = 5;   // kg
const MAX_CHILD_WEIGHT = 50;  // kg

/** Màu avatar xoay vòng theo tên học sinh */
const AVATAR_COLORS = ["#8A5E12", "#16665a", "#4B6F8C", "#BB4A34", "#5B4B8A", "#2E7D6B"];

function avatarColor(name: string) {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  return AVATAR_COLORS[hash % AVATAR_COLORS.length];
}

/** Chuyển "DD/MM/YYYY" hoặc ISO date string → "YYYY-MM-DD" */
function toIsoDate(val: string): string {
  if (!val) return "";
  if (val.includes("T")) val = val.split("T")[0];
  const m = val.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  const isoMatch = val.match(/^(\d{4}-\d{2}-\d{2})$/);
  if (isoMatch) return isoMatch[1];
  return "";
}

/** Hôm nay theo giờ địa phương */
function todayIso() {
  return todayIsoStr();
}

/** Format số gọn gàng, loại bỏ số 0 thừa (ví dụ 13.3 thay vì 13.30, 95 thay vì 95.00) */
function formatCompactNumber(val: number | null | undefined): string {
  if (val == null || isNaN(val)) return "—";
  return parseFloat(val.toFixed(2)).toString();
}

/** Kiểm tra chiều cao có hợp lệ trong dải mầm non hay không */
function isValidHeight(val: string): boolean {
  const trimmed = val.trim();
  if (!trimmed) return true; // Cho phép để trống nếu chỉ ghi kết luận
  const num = parseFloat(trimmed);
  return !isNaN(num) && num >= MIN_CHILD_HEIGHT && num <= MAX_CHILD_HEIGHT;
}

/** Kiểm tra cân nặng có hợp lệ trong dải mầm non hay không */
function isValidWeight(val: string): boolean {
  const trimmed = val.trim();
  if (!trimmed) return true; // Cho phép để trống
  const num = parseFloat(trimmed);
  return !isNaN(num) && num >= MIN_CHILD_WEIGHT && num <= MAX_CHILD_WEIGHT;
}

/**
 * Tính toán chỉ số BMI và phân loại thể trạng theo thời gian thực (Real-time).
 * Công thức: BMI = Cân nặng (kg) / (Chiều cao (cm) / 100)^2
 */
function calculateLiveBmiAndCategory(heightStr: string, weightStr: string) {
  const h = parseFloat(heightStr.trim());
  const w = parseFloat(weightStr.trim());

  if (
    isNaN(h) ||
    isNaN(w) ||
    h < MIN_CHILD_HEIGHT ||
    h > MAX_CHILD_HEIGHT ||
    w < MIN_CHILD_WEIGHT ||
    w > MAX_CHILD_WEIGHT
  ) {
    return {
      bmi: null,
      bmiText: "—",
      category: null,
      categoryLabel: "Chưa có",
      tone: "neutral" as const,
    };
  }

  const hm = h / 100;
  const bmiVal = w / (hm * hm);
  const bmiFormatted = parseFloat(bmiVal.toFixed(2)).toString();

  // Chuẩn xếp loại sơ bộ theo dải BMI mầm non
  let category = "NORMAL";
  let categoryLabel = "Bình thường";
  let tone: "ok" | "warn" | "bad" | "neutral" = "ok";

  if (bmiVal < 14) {
    category = "UNDERWEIGHT";
    categoryLabel = "Thiếu cân";
    tone = "warn";
  } else if (bmiVal > 17) {
    category = "OVERWEIGHT";
    categoryLabel = "Thừa cân";
    tone = "bad";
  }

  return {
    bmi: bmiVal,
    bmiText: bmiFormatted,
    category,
    categoryLabel,
    tone,
  };
}

/** Lấy tone hiển thị cho badge thể trạng */
function getCategoryTone(category?: string | null): "ok" | "warn" | "bad" | "neutral" {
  if (!category) return "neutral";
  const cat = category.toUpperCase();
  if (cat === "NORMAL") return "ok";
  if (cat === "UNDERWEIGHT") return "warn";
  if (cat === "OVERWEIGHT") return "bad";
  return "neutral";
}

/* ════════ State & Interface ════════ */

interface RowEditState {
  examination_date: string;
  height: string;
  weight: string;
  general_conclusion: string;
}

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
  const fileInputRef = useRef<HTMLInputElement>(null);

  /* Chế độ Chỉnh sửa hàng loạt (Bulk Edit - Chuẩn Excel) */
  const [isEditMode, setIsEditMode] = useState(false);
  const [tableEdits, setTableEdits] = useState<Record<string, RowEditState>>({});
  const [savingTable, setSavingTable] = useState(false);

  /* Modal xác nhận xóa bản ghi sức khỏe */
  const [confirmDel, setConfirmDel] = useState<HealthExamRecord | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  /* Drawer sửa số liệu 1 dòng (khi click nút Sửa ở View Mode) */
  const [editing, setEditing] = useState<HealthExamRecord | null>(null);
  const [editHeight, setEditHeight] = useState("");
  const [editWeight, setEditWeight] = useState("");
  const [editConclusion, setEditConclusion] = useState("");
  const [editDate, setEditDate] = useState("");
  const [editBusy, setEditBusy] = useState(false);

  /* ── Auth guard & danh sách lớp ── */
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
      refreshInterval: editing || importOpen || isEditMode ? 0 : 30000,
      revalidateOnFocus: !(editing || importOpen || isEditMode),
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

  /* ════════ Helper Lấy và Kiểm Tra Dữ Liệu Dòng ════════ */

  function getRowData(r: HealthExamRecord): RowEditState {
    if (tableEdits[r.child_id]) return tableEdits[r.child_id];
    const defaultDate = examDate || todayIso();
    const origDate = r.examination_date ? toIsoDate(r.examination_date) || defaultDate : defaultDate;

    // Lọc bỏ số liệu dị dạng trong database (ví dụ 1cm hoặc 160000 BMI)
    let sanitizedHeight = "";
    if (r.height != null) {
      sanitizedHeight = formatCompactNumber(r.height);
    }

    let sanitizedWeight = "";
    if (r.weight != null) {
      sanitizedWeight = formatCompactNumber(r.weight);
    }

    return {
      examination_date: origDate,
      height: sanitizedHeight === "—" ? "" : sanitizedHeight,
      weight: sanitizedWeight === "—" ? "" : sanitizedWeight,
      general_conclusion: r.general_conclusion || "",
    };
  }

  function updateRowCell(childId: string, field: keyof RowEditState, value: string) {
    const targetRec = filtered.find((x) => x.child_id === childId);
    const base = tableEdits[childId] || (targetRec ? getRowData(targetRec) : {
      examination_date: examDate || todayIso(),
      height: "",
      weight: "",
      general_conclusion: "",
    });

    setTableEdits((prev) => ({
      ...prev,
      [childId]: {
        ...base,
        [field]: value,
      },
    }));
  }

  function clearRowEdits(r: HealthExamRecord) {
    setTableEdits((prev) => ({
      ...prev,
      [r.child_id]: {
        examination_date: examDate || todayIso(),
        height: "",
        weight: "",
        general_conclusion: "",
      },
    }));
    setToast({ msg: `Đã xóa trắng số liệu dòng của học sinh ${r.full_name}`, tone: "brand" });
  }

  function isCellDirty(r: HealthExamRecord, field: keyof RowEditState): boolean {
    if (!tableEdits[r.child_id]) return false;
    const row = tableEdits[r.child_id];

    if (field === "examination_date") {
      const orig = r.examination_date ? toIsoDate(r.examination_date) : "";
      return orig !== "" && row.examination_date !== orig;
    }
    if (field === "height") {
      const orig = r.height != null ? formatCompactNumber(r.height) : "";
      return row.height.trim() !== (orig === "—" ? "" : orig);
    }
    if (field === "weight") {
      const orig = r.weight != null ? formatCompactNumber(r.weight) : "";
      return row.weight.trim() !== (orig === "—" ? "" : orig);
    }
    if (field === "general_conclusion") {
      const orig = r.general_conclusion || "";
      return row.general_conclusion.trim() !== orig.trim();
    }
    return false;
  }

  function isRowDirty(r: HealthExamRecord): boolean {
    return (
      isCellDirty(r, "examination_date") ||
      isCellDirty(r, "height") ||
      isCellDirty(r, "weight") ||
      isCellDirty(r, "general_conclusion")
    );
  }

  const dirtyRows = useMemo(() => {
    return filtered.filter((r) => isRowDirty(r));
  }, [filtered, tableEdits]);

  function cancelAllEdits() {
    setTableEdits({});
    setIsEditMode(false);
    setToast({ msg: "Đã hủy bỏ mọi thay đổi chưa lưu", tone: "brand" });
  }

  /* ════════ Lưu Tất Cả Thay Đổi (Bulk Save) ════════ */

  async function handleSaveAllEdits() {
    if (dirtyRows.length === 0) {
      setToast({ msg: "Không có thay đổi nào để lưu", tone: "brand" });
      setIsEditMode(false);
      return;
    }

    // Validation chặt chẽ từng dòng trước khi gửi lên máy chủ
    for (const r of dirtyRows) {
      const edit = getRowData(r);

      // 1. Kiểm tra ngày ghi nhận
      if (!edit.examination_date) {
        setToast({ msg: `Vui lòng chọn ngày ghi nhận cho học sinh ${r.full_name}`, tone: "bad" });
        return;
      }
      if (edit.examination_date > todayIso()) {
        setToast({
          msg: `Ngày ghi nhận của học sinh ${r.full_name} không được là ngày tương lai`,
          tone: "bad",
        });
        return;
      }

      // 2. Kiểm tra chiều cao
      if (edit.height.trim()) {
        const hVal = parseFloat(edit.height.trim());
        if (isNaN(hVal) || hVal < MIN_CHILD_HEIGHT || hVal > MAX_CHILD_HEIGHT) {
          setToast({
            msg: `Chiều cao của học sinh ${r.full_name} không hợp lệ (phải từ ${MIN_CHILD_HEIGHT} đến ${MAX_CHILD_HEIGHT} cm)`,
            tone: "bad",
          });
          return;
        }
      }

      // 3. Kiểm tra cân nặng
      if (edit.weight.trim()) {
        const wVal = parseFloat(edit.weight.trim());
        if (isNaN(wVal) || wVal < MIN_CHILD_WEIGHT || wVal > MAX_CHILD_WEIGHT) {
          setToast({
            msg: `Cân nặng của học sinh ${r.full_name} không hợp lệ (phải từ ${MIN_CHILD_WEIGHT} đến ${MAX_CHILD_WEIGHT} kg)`,
            tone: "bad",
          });
          return;
        }
      }

      // 4. Phải có ít nhất 1 thông tin
      const hasH = edit.height.trim() !== "";
      const hasW = edit.weight.trim() !== "";
      const hasC = edit.general_conclusion.trim() !== "";
      if (!hasH && !hasW && !hasC && !r.id) {
        setToast({
          msg: `Vui lòng nhập ít nhất chiều cao, cân nặng hoặc kết luận cho học sinh ${r.full_name}`,
          tone: "bad",
        });
        return;
      }
    }

    setSavingTable(true);
    let successCount = 0;
    let failedCount = 0;

    for (const r of dirtyRows) {
      const edit = getRowData(r);
      const hVal = edit.height.trim() ? parseFloat(edit.height.trim()) : null;
      const wVal = edit.weight.trim() ? parseFloat(edit.weight.trim()) : null;
      const conclusion = edit.general_conclusion.trim() || null;

      try {
        if (r.id) {
          await updateHealthExamRecord(r.id, {
            height: hVal,
            weight: wVal,
            general_conclusion: conclusion,
          });
        } else {
          await createHealthExamRecord({
            child_id: r.child_id,
            height: hVal,
            weight: wVal,
            general_conclusion: conclusion,
            examination_date: edit.examination_date || null,
          });
        }
        successCount++;
      } catch (e) {
        failedCount++;
      }
    }

    setSavingTable(false);
    setIsEditMode(false);
    setTableEdits({});
    mutate();

    if (failedCount === 0) {
      setToast({
        msg: `Đã lưu thành công số liệu sức khỏe cho ${successCount} học sinh!`,
        tone: "ok",
      });
    } else {
      setToast({
        msg: `Đã lưu ${successCount} học sinh (${failedCount} học sinh gặp lỗi)`,
        tone: "warn",
      });
    }
  }

  /* ════════ Xóa Bản Ghi Sức Khỏe ════════ */

  async function handleDeleteRecord(r: HealthExamRecord) {
    if (!r.id) {
      clearRowEdits(r);
      setConfirmDel(null);
      return;
    }

    setDeleteBusy(true);
    try {
      await deleteHealthExamRecord(r.id);
      setToast({ msg: `Đã xóa bản ghi sức khỏe của học sinh ${r.full_name}`, tone: "ok" });
      setConfirmDel(null);
      setTableEdits((prev) => {
        const copy = { ...prev };
        delete copy[r.child_id];
        return copy;
      });
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa bản ghi sức khỏe", tone: "bad" });
    } finally {
      setDeleteBusy(false);
    }
  }

  /* ════════ Drawer Sửa 1 Bản Ghi (View Mode) ════════ */

  function openEditModal(r: HealthExamRecord) {
    setEditing(r);
    setEditHeight(r.height != null ? formatCompactNumber(r.height) : "");
    setEditWeight(r.weight != null ? formatCompactNumber(r.weight) : "");
    setEditConclusion(r.general_conclusion || "");
    setEditDate(r.examination_date ? toIsoDate(r.examination_date) : todayIso());
  }

  function closeEditModal() {
    if (editBusy) return;
    setEditing(null);
  }

  async function handleSaveEdit() {
    if (!editing) return;
    const hasHeight = editHeight.trim() !== "";
    const hasWeight = editWeight.trim() !== "";
    const hasConclusion = editConclusion.trim() !== "";

    if (!hasHeight && !hasWeight && !hasConclusion) {
      setToast({
        msg: "Vui lòng nhập ít nhất chiều cao, cân nặng hoặc kết luận chung",
        tone: "bad",
      });
      return;
    }

    let height: number | null = null;
    if (hasHeight) {
      height = parseFloat(editHeight.trim());
      if (isNaN(height) || height < MIN_CHILD_HEIGHT || height > MAX_CHILD_HEIGHT) {
        setToast({
          msg: `Chiều cao phải là số từ ${MIN_CHILD_HEIGHT} đến ${MAX_CHILD_HEIGHT} cm`,
          tone: "bad",
        });
        return;
      }
    }

    let weight: number | null = null;
    if (hasWeight) {
      weight = parseFloat(editWeight.trim());
      if (isNaN(weight) || weight < MIN_CHILD_WEIGHT || weight > MAX_CHILD_WEIGHT) {
        setToast({
          msg: `Cân nặng phải là số từ ${MIN_CHILD_WEIGHT} đến ${MAX_CHILD_WEIGHT} kg`,
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
        msg: `Đã cập nhật số liệu sức khoẻ của học sinh ${editing.full_name}.`,
        tone: "ok",
      });
    } catch (err: any) {
      setToast({ msg: err?.message || "Không lưu được số liệu. Vui lòng thử lại.", tone: "bad" });
    } finally {
      setEditBusy(false);
    }
  }

  /* ════════ Xuất Excel ════════ */

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
      r.height != null ? formatCompactNumber(r.height) : "",
      r.weight != null ? formatCompactNumber(r.weight) : "",
      r.bmi != null ? formatCompactNumber(r.bmi) : "",
      r.health_category_label || "",
      r.general_conclusion || "",
    ];

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

  /* ════════ Modal Nhập Excel ════════ */

  function openImportModal() {
    setImportClassId(selectedClassId || "");
    setImportDate(todayIso());
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
          {/* Nút Làm mới */}
          <button
            onClick={() => {
              mutate();
              setToast({ msg: "Đã đồng bộ dữ liệu mới nhất", tone: "brand" });
            }}
            className="kbtn kbtn-secondary text-sm"
            title="Làm mới"
          >
            ↻
          </button>

          {/* Nút Xuất Excel */}
          <button
            onClick={handleExportExcel}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Xuất danh sách sổ sức khoẻ ra file Excel"
          >
            📥 Xuất Excel
          </button>

          {/* Nút Nhập file */}
          <button
            onClick={openImportModal}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Nhập kết quả từ file Excel"
            disabled={isEditMode}
          >
            📤 Nhập file
          </button>

          {/* Nút Chế độ Sửa (Bulk Edit) - Bỏ switch toggle */}
          <button
            onClick={() => {
              if (isEditMode && dirtyRows.length > 0) {
                if (window.confirm(`Bạn có ${dirtyRows.length} thay đổi chưa lưu. Bạn có chắc muốn thoát mà không lưu?`)) {
                  cancelAllEdits();
                }
                return;
              }
              setIsEditMode(!isEditMode);
            }}
            className={`kbtn text-sm flex items-center gap-1.5 transition-all ${
              isEditMode
                ? "bg-brand/10 text-brand border border-brand/30 shadow-sm"
                : "kbtn-secondary hover:border-brand"
            }`}
            title="Bật/tắt chế độ chỉnh sửa trực tiếp số liệu trên bảng (Chuẩn Excel)"
          >
            <span>✏️</span>
            <span>{isEditMode ? "Đang chỉnh sửa" : "Chỉnh sửa"}</span>
          </button>

          {/* Nút Lưu và Hủy thay đổi khi ở Edit Mode */}
          {isEditMode && (
            <>
              <button
                onClick={cancelAllEdits}
                disabled={savingTable}
                className="kbtn kbtn-secondary text-xs hover:border-bad hover:text-bad transition-colors"
                title="Hủy bỏ mọi thay đổi chưa lưu"
              >
                ✕ Hủy thay đổi
              </button>
              <button
                onClick={handleSaveAllEdits}
                disabled={savingTable}
                className="kbtn text-xs font-bold text-white flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg shadow-md hover:shadow-lg transition-all"
                style={{ background: "#16665a" }}
                title="Lưu toàn bộ thay đổi của tất cả các dòng đã sửa"
              >
                {savingTable ? (
                  <>
                    <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Đang lưu...</span>
                  </>
                ) : (
                  <>
                    <span>💾</span>
                    <span>Lưu tất cả thay đổi {dirtyRows.length > 0 ? `(${dirtyRows.length})` : ""}</span>
                  </>
                )}
              </button>
            </>
          )}
        </div>
      }
    >
      {/* ══ Banner Cảnh báo Thay đổi Chưa Lưu ══ */}
      {isEditMode && dirtyRows.length > 0 && (
        <div className="mb-3 px-4 py-2.5 rounded-card bg-amber-50 border border-amber-200 text-amber-800 text-xs flex items-center justify-between shadow-sm">
          <span className="flex items-center gap-2">
            <span className="text-sm">⚠️</span>
            <span>
              Có <strong>{dirtyRows.length}</strong> học sinh có thay đổi chưa lưu. Nhấn nút <strong>“Lưu tất cả thay đổi”</strong> để cập nhật dữ liệu.
            </span>
          </span>
          <button
            onClick={handleSaveAllEdits}
            disabled={savingTable}
            className="font-bold underline text-brand hover:opacity-80 transition-opacity ml-3"
          >
            Lưu ngay
          </button>
        </div>
      )}

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
          <div className="text-2xl font-bold mt-1 text-emerald-600">
            {stats.normal ?? 0}
          </div>
        </div>
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Suy dinh dưỡng</div>
          <div className="text-2xl font-bold mt-1 text-amber-600">
            {stats.underweight ?? 0}
          </div>
        </div>
        <div className="card p-3.5">
          <div className="text-[11px] text-ink-soft font-semibold">Thừa cân</div>
          <div className="text-2xl font-bold mt-1 text-rose-600">
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
            placeholder="Tìm theo tên học sinh, biệt danh, lớp, thể trạng, kết luận..."
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

      {/* ══ Bảng dữ liệu (View / Bulk Edit) ══ */}
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
                  <th className="px-3 py-3 text-left font-semibold">Lớp</th>
                  <th className="px-3 py-3 text-left font-semibold">Ngày ghi nhận</th>
                  <th className="px-3 py-3 text-right font-semibold">Chiều cao (cm)</th>
                  <th className="px-3 py-3 text-right font-semibold">Cân nặng (kg)</th>
                  <th className="px-3 py-3 text-right font-semibold">BMI</th>
                  <th className="px-3 py-3 text-left font-semibold">Thể trạng</th>
                  <th className="px-4 py-3 text-left font-semibold">Kết luận chung</th>
                  <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {filtered.map((r) => {
                  const editData = getRowData(r);
                  const rowDirty = isRowDirty(r);

                  // Validation trạng thái các ô
                  const validH = isValidHeight(editData.height);
                  const validW = isValidWeight(editData.weight);

                  // Tính BMI và Thể trạng Real-time trong chế độ Sửa
                  const liveCalc = calculateLiveBmiAndCategory(editData.height, editData.weight);

                  // Dữ liệu hiển thị ở chế độ Xem (đã lọc các số liệu vô lý như 1cm hay 160000 BMI)
                  let viewHeight = "—";
                  if (r.height != null) {
                    if (r.height >= MIN_CHILD_HEIGHT && r.height <= MAX_CHILD_HEIGHT) {
                      viewHeight = `${formatCompactNumber(r.height)} cm`;
                    } else {
                      viewHeight = `${formatCompactNumber(r.height)} cm ⚠`;
                    }
                  }

                  let viewWeight = "—";
                  if (r.weight != null) {
                    if (r.weight >= MIN_CHILD_WEIGHT && r.weight <= MAX_CHILD_WEIGHT) {
                      viewWeight = `${formatCompactNumber(r.weight)} kg`;
                    } else {
                      viewWeight = `${formatCompactNumber(r.weight)} kg ⚠`;
                    }
                  }

                  let viewBmi = "—";
                  if (r.bmi != null && r.bmi >= 8 && r.bmi <= 40) {
                    viewBmi = formatCompactNumber(r.bmi);
                  }

                  const viewTone = getCategoryTone(r.health_category);

                  return (
                    <tr
                      key={r.child_id}
                      className={`transition-colors hover:bg-slate-50/70 ${
                        rowDirty ? "bg-amber-50/20" : ""
                      }`}
                    >
                      {/* Cột 1: Học sinh (Avatar, Tên in đậm, Biệt danh, Ngày sinh / Giới tính nhỏ mờ bên dưới) */}
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2.5">
                          <div
                            className="w-9 h-9 flex items-center justify-center rounded-full text-white font-bold text-sm shrink-0 shadow-sm"
                            style={{ background: avatarColor(r.full_name) }}
                          >
                            {r.full_name.charAt(0).toUpperCase()}
                          </div>
                          <div className="min-w-0 max-w-[200px]">
                            <div className="font-semibold text-ink truncate text-sm">
                              {r.full_name}
                              {r.nickname && (
                                <span className="font-normal text-ink-soft ml-1">({r.nickname})</span>
                              )}
                            </div>
                            <div className="text-[11px] text-ink-faint mt-0.5 truncate">
                              {r.date_of_birth ? `${r.date_of_birth}` : "Chưa có ngày sinh"}
                              {r.gender && (
                                <span> · {r.gender === "male" ? "Nam" : r.gender === "female" ? "Nữ" : r.gender}</span>
                              )}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Cột 2: Lớp */}
                      <td className="px-3 py-3 text-ink-soft whitespace-nowrap text-xs">
                        {r.class_name ? (
                          <span className="font-medium text-ink">{r.class_name}</span>
                        ) : (
                          <span className="italic text-ink-faint">Chưa xếp lớp</span>
                        )}
                      </td>

                      {/* Cột 3: Ngày ghi nhận */}
                      <td className="px-3 py-3 whitespace-nowrap">
                        {isEditMode ? (
                          <input
                            type="date"
                            max={todayIso()}
                            className={`kinput text-xs py-1.5 px-2.5 w-36 rounded-md shadow-sm transition-all ${
                              isCellDirty(r, "examination_date")
                                ? "border-amber-400 bg-amber-50/40"
                                : "border-slate-300 bg-white"
                            }`}
                            value={editData.examination_date}
                            onChange={(e) => updateRowCell(r.child_id, "examination_date", e.target.value)}
                          />
                        ) : (
                          <span className="text-ink text-xs font-medium">
                            {r.examination_date || "—"}
                          </span>
                        )}
                      </td>

                      {/* Cột 4: Chiều cao (cm) */}
                      <td className="px-3 py-3 text-right whitespace-nowrap">
                        {isEditMode ? (
                          <div className="inline-flex flex-col items-end">
                            <input
                              type="number"
                              step="0.1"
                              placeholder="cm"
                              className={`kinput text-xs py-1.5 px-2 w-20 text-right rounded-md shadow-sm transition-all ${
                                !validH
                                  ? "border-red-500 bg-red-50/50 text-red-700 focus:border-red-500 focus:ring-red-200"
                                  : isCellDirty(r, "height")
                                  ? "border-amber-400 bg-amber-50/40"
                                  : "border-slate-300 bg-white"
                              }`}
                              value={editData.height}
                              onChange={(e) => updateRowCell(r.child_id, "height", e.target.value)}
                              title={`Chiều cao hợp lệ: ${MIN_CHILD_HEIGHT} - ${MAX_CHILD_HEIGHT} cm`}
                            />
                            {!validH && (
                              <span className="text-[10px] text-red-600 mt-0.5">
                                {MIN_CHILD_HEIGHT}-{MAX_CHILD_HEIGHT}cm
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="text-ink text-xs font-medium">
                            {viewHeight}
                          </span>
                        )}
                      </td>

                      {/* Cột 5: Cân nặng (kg) */}
                      <td className="px-3 py-3 text-right whitespace-nowrap">
                        {isEditMode ? (
                          <div className="inline-flex flex-col items-end">
                            <input
                              type="number"
                              step="0.1"
                              placeholder="kg"
                              className={`kinput text-xs py-1.5 px-2 w-20 text-right rounded-md shadow-sm transition-all ${
                                !validW
                                  ? "border-red-500 bg-red-50/50 text-red-700 focus:border-red-500 focus:ring-red-200"
                                  : isCellDirty(r, "weight")
                                  ? "border-amber-400 bg-amber-50/40"
                                  : "border-slate-300 bg-white"
                              }`}
                              value={editData.weight}
                              onChange={(e) => updateRowCell(r.child_id, "weight", e.target.value)}
                              title={`Cân nặng hợp lệ: ${MIN_CHILD_WEIGHT} - ${MAX_CHILD_WEIGHT} kg`}
                            />
                            {!validW && (
                              <span className="text-[10px] text-red-600 mt-0.5">
                                {MIN_CHILD_WEIGHT}-{MAX_CHILD_WEIGHT}kg
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="text-ink text-xs font-medium">
                            {viewWeight}
                          </span>
                        )}
                      </td>

                      {/* Cột 6: Chỉ số BMI (Read-only, Real-time calculation) */}
                      <td className="px-3 py-3 text-right font-bold whitespace-nowrap">
                        {isEditMode ? (
                          <span
                            className={`text-xs px-2 py-1 rounded bg-slate-100 ${
                              liveCalc.bmi != null ? "text-brand" : "text-ink-faint"
                            }`}
                            title="Chỉ số BMI được tính tự động từ Chiều cao và Cân nặng"
                          >
                            {liveCalc.bmiText}
                          </span>
                        ) : (
                          <span className="text-xs text-ink">{viewBmi}</span>
                        )}
                      </td>

                      {/* Cột 7: Thể trạng (Badge bo tròn - Real-time) */}
                      <td className="px-3 py-3 whitespace-nowrap">
                        {isEditMode ? (
                          liveCalc.category ? (
                            <span
                              className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                                liveCalc.tone === "ok"
                                  ? "bg-emerald-50 text-emerald-700 border border-emerald-200"
                                  : liveCalc.tone === "warn"
                                  ? "bg-amber-50 text-amber-700 border border-amber-200"
                                  : liveCalc.tone === "bad"
                                  ? "bg-rose-50 text-rose-700 border border-rose-200"
                                  : "bg-slate-100 text-slate-500 border border-slate-200"
                              }`}
                            >
                              <span
                                className={`w-1.5 h-1.5 rounded-full ${
                                  liveCalc.tone === "ok"
                                    ? "bg-emerald-500"
                                    : liveCalc.tone === "warn"
                                    ? "bg-amber-500"
                                    : liveCalc.tone === "bad"
                                    ? "bg-rose-500"
                                    : "bg-slate-400"
                                }`}
                              />
                              {liveCalc.categoryLabel}
                            </span>
                          ) : (
                            <span className="text-xs text-ink-faint italic bg-slate-100 px-2 py-0.5 rounded-full border border-slate-200">
                              Chưa có
                            </span>
                          )
                        ) : r.health_category_label ? (
                          <span
                            className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                              viewTone === "ok"
                                ? "bg-emerald-50 text-emerald-700 border border-emerald-200"
                                : viewTone === "warn"
                                ? "bg-amber-50 text-amber-700 border border-amber-200"
                                : viewTone === "bad"
                                ? "bg-rose-50 text-rose-700 border border-rose-200"
                                : "bg-slate-100 text-slate-500 border border-slate-200"
                            }`}
                          >
                            <span
                              className={`w-1.5 h-1.5 rounded-full ${
                                viewTone === "ok"
                                  ? "bg-emerald-500"
                                  : viewTone === "warn"
                                  ? "bg-amber-500"
                                  : viewTone === "bad"
                                  ? "bg-rose-500"
                                  : "bg-slate-400"
                              }`}
                            />
                            {r.health_category_label}
                          </span>
                        ) : (
                          <span className="text-xs text-ink-faint italic bg-slate-100 px-2 py-0.5 rounded-full border border-slate-200">
                            Chưa có
                          </span>
                        )}
                      </td>

                      {/* Cột 8: Kết luận chung (Textarea nhiều dòng khi sửa, line-clamp-2 khi xem) */}
                      <td className="px-4 py-3">
                        {isEditMode ? (
                          <textarea
                            rows={2}
                            className={`kinput text-xs py-1.5 px-2.5 w-full min-w-[160px] max-w-sm rounded-md shadow-sm resize-y transition-all ${
                              isCellDirty(r, "general_conclusion")
                                ? "border-amber-400 bg-amber-50/40"
                                : "border-slate-300 bg-white"
                            }`}
                            value={editData.general_conclusion}
                            onChange={(e) =>
                              updateRowCell(r.child_id, "general_conclusion", e.target.value)
                            }
                            placeholder="Nhập kết luận sức khỏe..."
                          />
                        ) : (
                          <div
                            className="max-w-[220px] line-clamp-2 text-xs text-ink-soft"
                            title={r.general_conclusion || ""}
                          >
                            {r.general_conclusion || "—"}
                          </div>
                        )}
                      </td>

                      {/* Cột 9: Thao tác */}
                      <td className="px-4 py-3 text-right whitespace-nowrap">
                        {isEditMode ? (
                          <button
                            type="button"
                            onClick={() => clearRowEdits(r)}
                            className="p-1.5 text-slate-400 hover:text-bad rounded hover:bg-bad/10 transition-colors inline-flex items-center gap-1 text-xs"
                            title="Xóa trắng số liệu dòng này"
                          >
                            <span>🗑️</span>
                          </button>
                        ) : (
                          <div className="inline-flex items-center gap-1.5">
                            <button
                              type="button"
                              onClick={() => openEditModal(r)}
                              className="p-1.5 text-slate-500 hover:text-brand rounded hover:bg-brand/10 transition-colors"
                              title={r.id ? "Chỉnh sửa số liệu sức khỏe" : "Nhập số liệu sức khỏe"}
                            >
                              ✏️
                            </button>
                            <button
                              type="button"
                              onClick={() => setConfirmDel(r)}
                              className={`p-1.5 rounded transition-colors ${
                                r.id
                                  ? "text-slate-400 hover:text-bad hover:bg-bad/10"
                                  : "text-slate-300 cursor-not-allowed"
                              }`}
                              disabled={!r.id}
                              title={
                                r.id
                                  ? "Xóa bản ghi sức khỏe của học sinh này"
                                  : "Học sinh này chưa có bản ghi sức khỏe để xóa"
                              }
                            >
                              🗑️
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ══ Modal Xác nhận Xóa Bản Ghi Sức Khỏe ══ */}
      <Modal
        open={!!confirmDel}
        onClose={() => !deleteBusy && setConfirmDel(null)}
        title="Xác nhận xóa bản ghi sức khỏe"
        size="sm"
        footer={
          <div className="flex items-center justify-end gap-2 w-full">
            <button
              type="button"
              onClick={() => setConfirmDel(null)}
              disabled={deleteBusy}
              className="kbtn kbtn-secondary text-xs"
            >
              Hủy
            </button>
            <button
              type="button"
              onClick={() => confirmDel && handleDeleteRecord(confirmDel)}
              disabled={deleteBusy}
              className="kbtn text-xs font-bold text-white bg-bad hover:bg-bad/90 flex items-center gap-1.5"
            >
              {deleteBusy ? (
                <>
                  <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  <span>Đang xóa...</span>
                </>
              ) : (
                <>
                  <span>🗑️</span>
                  <span>Xác nhận xóa</span>
                </>
              )}
            </button>
          </div>
        }
      >
        <div className="py-2 text-sm text-ink-soft leading-relaxed">
          Bạn có chắc chắn muốn xóa bản ghi sức khỏe của học sinh{" "}
          <strong className="text-ink">{confirmDel?.full_name}</strong>?
          <p className="mt-2 text-xs text-bad">
            ⚠️ Thao tác này sẽ xóa toàn bộ số liệu chiều cao, cân nặng, BMI và kết luận của học sinh này khỏi hệ thống.
          </p>
        </div>
      </Modal>

      {/* ══ Modal Nhập kết quả vào sổ sức khoẻ từ Excel ══ */}
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
                  disabled={importBusy || !importFile}
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
            Hỗ trợ nhập trực tiếp số liệu khám vào bảng hoặc tải file Excel lên.
            Hệ thống tự động tính BMI và kiểm tra các số liệu hợp lệ.
          </p>

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

          {!importResult && (
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
                      <div
                        key={`${issue.sheet_name || "x"}-${issue.row_number}-${issue.child_id || "x"}`}
                        className="p-3"
                      >
                        <div className="flex items-center gap-2 flex-wrap">
                          <span
                            className={`px-2 py-0.5 rounded-full text-white text-[11px] font-bold ${
                              issue.errors.length > 0 ? "bg-bad" : "bg-warn"
                            }`}
                          >
                            {issue.sheet_name
                              ? `${issue.sheet_name} · Dòng ${issue.row_number}`
                              : `Dòng ${issue.row_number}`}
                          </span>
                          {issue.full_name && (
                            <span className="text-xs font-semibold text-ink">{issue.full_name}</span>
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
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </Modal>

      {/* ══ Drawer Chỉnh sửa số liệu 1 dòng (View Mode) ══ */}
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
              className="kbtn kbtn-secondary text-xs"
              disabled={editBusy}
            >
              Hủy
            </button>
            <button
              onClick={handleSaveEdit}
              className="kbtn text-xs font-bold text-white"
              style={{ background: "#16665a" }}
              disabled={editBusy}
            >
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
              <FormField
                label="Chiều cao (cm)"
                hint={`Dải hợp lệ: ${MIN_CHILD_HEIGHT} - ${MAX_CHILD_HEIGHT} cm`}
              >
                <input
                  className="kinput text-xs"
                  type="number"
                  step="0.1"
                  min={MIN_CHILD_HEIGHT}
                  max={MAX_CHILD_HEIGHT}
                  value={editHeight}
                  onChange={(e) => setEditHeight(e.target.value)}
                  placeholder="95.5"
                />
              </FormField>
              <FormField
                label="Cân nặng (kg)"
                hint={`Dải hợp lệ: ${MIN_CHILD_WEIGHT} - ${MAX_CHILD_WEIGHT} kg`}
              >
                <input
                  className="kinput text-xs"
                  type="number"
                  step="0.1"
                  min={MIN_CHILD_WEIGHT}
                  max={MAX_CHILD_WEIGHT}
                  value={editWeight}
                  onChange={(e) => setEditWeight(e.target.value)}
                  placeholder="14.2"
                />
              </FormField>
            </div>

            <FormField
              label="Kết luận chung"
              hint="Có thể để trống nếu đã nhập chiều cao và cân nặng"
            >
              <textarea
                className="kinput resize-y text-xs"
                value={editConclusion}
                onChange={(e) => setEditConclusion(e.target.value)}
                rows={3}
                maxLength={2000}
                placeholder="Nhập kết luận của đợt ghi nhận..."
              />
            </FormField>

            <div className="text-xs text-ink-faint leading-relaxed bg-sunken/50 p-2.5 rounded-control">
              💡 Hệ thống tự động tính chỉ số BMI và xếp loại thể trạng dựa trên tuổi và giới tính của học sinh.
            </div>
          </>
        )}
      </Drawer>

      {/* Toast thông báo */}
      {toast && <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />}
    </SchoolAdminLayout>
  );
}
