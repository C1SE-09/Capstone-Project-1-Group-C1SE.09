/**
 * pages/school-admin/students.tsx
 * ===============================
 * CRUD học sinh — UI y hệt Flutter app:
 *   - Search + Add + Refresh.
 *   - Bảng danh sách học sinh.
 *   - Drawer: Họ tên, biệt danh, lớp, phụ huynh liên kết (multi), giới tính, ngày sinh, dị ứng.
 */

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/router";
import useSWR from "swr";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import {
  ClassFilterSelect,
  ConfirmDialog,
  DateInput,
  Drawer,
  FormField,
  ImportModal,
  ImportResult,
  Modal,
  Pill,
  SearchBar,
  SearchableSelect,
  SelectOption,
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
  normalizeHeader,
  parseDateToIso,
} from "@/lib/excel-helper";
import {
  Child,
  ChildPayload,
  Parent,
  SchoolClass,
  createChild,
  createParent,
  deleteChild,
  deleteChildrenBatch,
  getChildren,
  getClasses,
  getParents,
  updateChild,
} from "@/lib/admin-api";

interface FormState {
  full_name: string;
  nickname: string;
  class_id: string | null;
  parent_ids: string[];
  primary_parent_id: string | null;
  date_of_birth: string;
  gender: string;
  medical_allergies: string;
  allergy_status: string;
  care_notes: string;
  status: string;
}

const EMPTY: FormState = {
  full_name: "",
  nickname: "",
  class_id: null,
  parent_ids: [],
  primary_parent_id: null,
  date_of_birth: "",
  gender: "male",
  medical_allergies: "",
  allergy_status: "unknown",
  care_notes: "",
  status: "enrolled",
};

interface AgeDetail {
  years: number;
  months: number;
  birthYear: string;
  formattedDob: string;
  timestamp: number | null;
}

interface DuplicateKidItem {
  id?: string;
  isNew: boolean;
  full_name: string;
  current_nickname: string;
  suggested_nickname: string;
  custom_nickname: string;
  date_of_birth: string;
  ageInfo: AgeDetail;
  rankIndex: number;
  rankLabel: string;
}

interface DuplicateStudentAlert {
  targetClassName: string;
  totalDuplicates: number;
  items: DuplicateKidItem[];
  payload: ChildPayload;
  editingChildId?: string | null;
}


function extractLastName(fullName: string): string {
  const parts = fullName.trim().split(/\s+/);
  if (parts.length >= 2) {
    return parts.slice(-2).join(" ");
  }
  return parts[0] || fullName;
}

/**
 * Trích xuất chi tiết ngày sinh, năm sinh và tính tuổi theo năm/tháng hiện tại:
 */
function getAgeDetail(dob?: string | null): AgeDetail {
  if (!dob) {
    return {
      years: 0,
      months: 0,
      birthYear: "—",
      formattedDob: "Chưa rõ",
      timestamp: null,
    };
  }
  const cleaned = dob.split("T")[0].trim();
  let d = 0,
    m = 0,
    y = 0;
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(cleaned)) {
    const parts = cleaned.split("/").map(Number);
    d = parts[0];
    m = parts[1];
    y = parts[2];
  } else if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(cleaned)) {
    const parts = cleaned.split("-").map(Number);
    y = parts[0];
    m = parts[1];
    d = parts[2];
  }

  if (!y || isNaN(y)) {
    const parsed = Date.parse(cleaned);
    if (!isNaN(parsed)) {
      const dt = new Date(parsed);
      y = dt.getFullYear();
      m = dt.getMonth() + 1;
      d = dt.getDate();
    } else {
      return {
        years: 0,
        months: 0,
        birthYear: "—",
        formattedDob: cleaned,
        timestamp: null,
      };
    }
  }

  const birthDate = new Date(y, m - 1, d);
  const now = new Date();
  let years = now.getFullYear() - birthDate.getFullYear();
  let months = now.getMonth() - birthDate.getMonth();
  if (now.getDate() < birthDate.getDate()) {
    months--;
  }
  if (months < 0) {
    years--;
    months += 12;
  }

  const formattedDob = `${String(d).padStart(2, "0")}/${String(m).padStart(2, "0")}/${y}`;
  return {
    years: Math.max(0, years),
    months: Math.max(0, months),
    birthYear: String(y),
    formattedDob,
    timestamp: birthDate.getTime(),
  };
}

/**
 * So sánh độ tuổi dựa trên ngày sinh (xét toàn diện năm, tháng, ngày):
 * - Nếu dob1 sinh trước dob2 (năm nhỏ hơn hoặc cùng năm nhưng tháng/ngày nhỏ hơn):
 *   -> Bé 1 lớn tuổi hơn -> trả về -1 (Bé 1: Lớn, Bé 2: Nhỏ)
 * - Nếu dob1 sinh sau dob2 (năm lớn hơn hoặc cùng năm nhưng tháng/ngày lớn hơn):
 *   -> Bé 1 nhỏ tuổi hơn -> trả về 1 (Bé 1: Nhỏ, Bé 2: Lớn)
 * - Cùng ngày tháng năm hoặc thiếu dữ liệu -> trả về 0
 */
function compareAges(dob1?: string | null, dob2?: string | null): number {
  const p1 = getAgeDetail(dob1);
  const p2 = getAgeDetail(dob2);
  if (p1.timestamp === null && p2.timestamp === null) return 0;
  if (p1.timestamp === null) return 1;
  if (p2.timestamp === null) return -1;
  if (p1.timestamp < p2.timestamp) return -1;
  if (p1.timestamp > p2.timestamp) return 1;
  return 0;
}

function cleanNickname(nick?: string | null, fullName?: string): string {
  if (nick && nick.trim()) {
    return nick.replace(/\s*\((lớn|nhỏ|lon|nho|\d+|a|b)\)$/i, "").trim();
  }
  return extractLastName(fullName || "");
}

/**
 * Kiểm tra xem 2 học sinh có bị trùng cả họ tên LẪN biệt danh trong cùng lớp hay không.
 * - Khác họ tên -> false
 * - Khác biệt danh (ví dụ 1 bé "Bống", 1 bé "Bắp") -> false (không cần Lớn/Nhỏ)
 * - Một bé có biệt danh riêng khác biệt hoàn toàn với bé kia -> false
 * - Trùng cả họ tên VÀ (cả 2 đều chưa có biệt danh, hoặc cả 2 có biệt danh gốc giống nhau) -> true (cần Lớn/Nhỏ)
 */
function hasDuplicateNickname(
  name1: string,
  nick1: string | null | undefined,
  name2: string,
  nick2: string | null | undefined
): boolean {
  if (name1.trim().toLowerCase() !== name2.trim().toLowerCase()) {
    return false;
  }
  const clean1 = (nick1 || "").trim();
  const clean2 = (nick2 || "").trim();

  // Nếu cả 2 đều bỏ trống biệt danh -> trùng hoàn toàn họ tên mà không có biệt danh phân biệt -> Cần Lớn/Nhỏ
  if (!clean1 && !clean2) {
    return true;
  }

  // Nếu cả 2 đều có biệt danh -> so sánh biệt danh gốc (sau khi đã bỏ hậu tố (Lớn), (Nhỏ), (1), (2))
  if (clean1 && clean2) {
    const base1 = cleanNickname(clean1, name1).toLowerCase().trim();
    const base2 = cleanNickname(clean2, name2).toLowerCase().trim();
    return base1 === base2;
  }

  // Một bé có biệt danh (VD: "Bống"), một bé không có biệt danh -> khác biệt danh -> Không cần Lớn/Nhỏ
  return false;
}

interface DuplicateCandidate {
  id?: string;
  isNew: boolean;
  full_name: string;
  current_nickname?: string | null;
  date_of_birth?: string | null;
}

/**
 * Tính toán biệt danh phân biệt cho danh sách các bé trùng họ tên & biệt danh trong một lớp.
 * - 2 bé: Bé lớn nhận "(Lớn)", bé nhỏ nhận "(Nhỏ)". Cùng ngày sinh thì bé có trước là "(Lớn)", bé mới là "(Nhỏ)".
 * - >= 3 bé: Đánh số thứ tự "(1)", "(2)", "(3)"... theo độ tuổi từ lớn đến nhỏ. Cùng ngày sinh thì ưu tiên bé có trước.
 */
function resolveDuplicateNicknames(
  candidates: DuplicateCandidate[],
  baseNickName: string
): DuplicateKidItem[] {
  const sorted = [...candidates].sort((a, b) => {
    const cmp = compareAges(a.date_of_birth, b.date_of_birth);
    if (cmp !== 0) return cmp;
    if (!a.isNew && b.isNew) return -1;
    if (a.isNew && !b.isNew) return 1;
    return 0;
  });

  const total = sorted.length;
  const base = baseNickName.trim();

  return sorted.map((cand, idx) => {
    const ageInfo = getAgeDetail(cand.date_of_birth);
    let suffix = "";
    let rankLabel = "";

    if (total === 2) {
      if (idx === 0) {
        suffix = "(Lớn)";
        rankLabel = "Sinh trước · Đề xuất (Lớn)";
      } else {
        suffix = "(Nhỏ)";
        rankLabel = "Sinh sau · Đề xuất (Nhỏ)";
      }
    } else {
      suffix = `(${idx + 1})`;
      rankLabel = `Thứ tự ${idx + 1}/${total} · Đề xuất (${idx + 1})`;
    }

    const suggested = `${base} ${suffix}`.trim();
    return {
      id: cand.id,
      isNew: cand.isNew,
      full_name: cand.full_name,
      current_nickname: cand.current_nickname || "(Chưa có)",
      suggested_nickname: suggested,
      custom_nickname: suggested,
      date_of_birth: cand.date_of_birth || "",
      ageInfo,
      rankIndex: idx,
      rankLabel,
    };
  });
}


/**
 * Tìm lớp học linh hoạt dựa trên ID, tên lớp hoặc tên sheet (hỗ trợ cả có hoặc không có tiền tố "Lớp")
 */
function findClassFlexible(classNameOrId: string, classes: SchoolClass[]): SchoolClass | undefined {
  if (!classNameOrId) return undefined;
  const target = classNameOrId.trim();
  const lowerTarget = target.toLowerCase();

  // 1. Khớp chính xác ID hoặc tên
  let found = classes.find((c) => c.id === classNameOrId || c.name.toLowerCase() === lowerTarget);
  if (found) return found;

  // 2. Thử thêm hoặc bỏ tiền tố "Lớp " / "Lop "
  const withoutLop = lowerTarget.replace(/^(lớp|lop)\s+/i, "").trim();
  const withLop = `lớp ${withoutLop}`;

  found = classes.find((c) => {
    const cLower = c.name.toLowerCase().trim();
    const cWithoutLop = cLower.replace(/^(lớp|lop)\s+/i, "").trim();
    return cLower === withoutLop || cWithoutLop === withoutLop || cLower === withLop;
  });
  if (found) return found;

  // 3. Chuẩn hóa bỏ dấu tiếng Việt để so sánh (VD: "Mam 1" khớp "Lớp Mầm 1")
  const normTarget = normalizeHeader(target);
  const normWithoutLop = normalizeHeader(withoutLop);

  found = classes.find((c) => {
    const normC = normalizeHeader(c.name);
    const normCWithoutLop = normalizeHeader(c.name.replace(/^(lớp|lop)\s+/i, ""));
    return (
      normC === normTarget ||
      normCWithoutLop === normWithoutLop ||
      normC === normWithoutLop ||
      normC.includes(normWithoutLop)
    );
  });
  return found;
}

export default function SchoolAdminStudentsPage() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [selectedClassId, setSelectedClassId] = useState("");
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [parents, setParents] = useState<Parent[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  // Chế độ Chỉnh sửa hàng loạt (Bulk Edit) & Dropdown Multi-select Phụ huynh
  interface RowEditState {
    full_name: string;
    nickname: string;
    class_id: string | null;
    parent_ids: string[];
    date_of_birth: string;
    gender: string;
    medical_allergies: string;
  }
  const [isEditMode, setIsEditMode] = useState(false);
  const [tableEdits, setTableEdits] = useState<Record<string, RowEditState>>({});
  const [savingTable, setSavingTable] = useState(false);
  const [openParentDropdownId, setOpenParentDropdownId] = useState<string | null>(null);
  const [parentSearchQuery, setParentSearchQuery] = useState("");
  const [editing, setEditing] = useState<Child | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Child | null>(null);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [confirmBulkDel, setConfirmBulkDel] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const [duplicateAlert, setDuplicateAlert] = useState<DuplicateStudentAlert | null>(null);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "brand" | "warn" } | null>(null);

  useEffect(() => {
    if (!router.isReady) return;
    const cls = router.query.class;
    if (typeof cls === "string" && cls) setSelectedClassId(cls);
  }, [router.isReady, router.query.class]);

  useEffect(() => {
    if (!getToken() || !getStoredSchoolAdmin()) {
      window.location.href = "/login";
      return;
    }
    setReady(true);
    Promise.all([getClasses().catch(() => []), getParents().catch(() => [])]).then(
      ([c, p]) => {
        setClasses(c);
        setParents(p);
      },
    );
  }, []);

  const { data: children, error: childrenError, mutate } = useSWR<Child[]>(
    ready ? "students" : null,
    () => getChildren(),
    {
      refreshInterval: drawerOpen || importOpen || !!duplicateAlert ? 0 : 30000,
      revalidateOnFocus: !(drawerOpen || importOpen || !!duplicateAlert),
    },
  );

  useEffect(() => {
    if (!childrenError) return;
    const status = (childrenError as any)?.status;
    if (status !== 401) return;

    // 401: thử làm mới token 1 lần trước khi kết luận phiên đã hết hạn.
    // Trước đây trang này xoá token + chuyển về /login ngay lập tức, nên chỉ 1
    // lần refresh hỏng (do race condition giữa các request song song) cũng khiến
    // người dùng bị đăng xuất oan.
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
  }, [childrenError, mutate]);

  const filtered = useMemo(() => {
    let list = children ?? [];
    if (selectedClassId) {
      list = list.filter((c) => c.class_id === selectedClassId);
    }
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter(
      (c) =>
        c.full_name.toLowerCase().includes(q) ||
        (c.nickname || "").toLowerCase().includes(q) ||
        (c.class_name || "").toLowerCase().includes(q) ||
        (c.parents_summary || "").toLowerCase().includes(q) ||
        (c.note || "").toLowerCase().includes(q) ||
        (c.care_notes || "").toLowerCase().includes(q),
    );
  }, [children, query, selectedClassId]);

  // Lớp đang chọn trong form — dùng để cảnh báo sắp đầy sĩ số.
  const selectedClass = useMemo(
    () => classes.find((c) => c.id === form.class_id) ?? null,
    [classes, form.class_id],
  );
  const selectedClassCount = selectedClass?.student_count ?? 0;
  const selectedClassCapacity = selectedClass?.capacity ?? null;
  // Bé đang sửa đã nằm sẵn ở lớp đó → giữ nguyên lớp không làm vượt sĩ số.
  const stayingInSameClass = editing?.class_id === form.class_id;
  const selectedClassIsFull =
    selectedClassCapacity != null &&
    selectedClassCount >= selectedClassCapacity &&
    !stayingInSameClass;

  const classFormOptions = useMemo<SelectOption[]>(() => {
    return [
      { value: "", label: "-- Chọn lớp --" },
      ...classes.map((c) => ({
        value: c.id,
        label: `${c.name}${c.grade_label ? ` (${c.grade_label})` : ""}`,
        sublabel:
          c.capacity != null
            ? `${c.student_count ?? 0}/${c.capacity} bé`
            : c.room_number
            ? c.room_number
            : undefined,
      })),
    ];
  }, [classes]);

  function handleExportExcel() {
    if (!children || children.length === 0) {
      setToast({ msg: "Không có dữ liệu học sinh để xuất", tone: "warn" });
      return;
    }
    const headers = [
      "Họ và tên",
      "Biệt danh",
      "Tên lớp",
      "Phụ huynh",
      "Ngày sinh",
      "Giới tính",
      "Ghi chú / Dị ứng",
      "Trạng thái",
    ];

    // Nếu đang chọn toàn trường (không lọc theo lớp) -> tự động xuất toàn trường và chia theo từng sheet
    if (!selectedClassId) {
      const sheets: ExcelSheetData[] = [];

      for (const cl of classes) {
        const classStudents = (children || []).filter((c) => c.class_id === cl.id);
        if (classStudents.length > 0) {
          const cRows = classStudents.map((c) => [
            c.full_name,
            c.nickname || "",
            cl.name,
            c.parents_summary || "Chưa liên kết",
            c.date_of_birth ? formatDateToDmy(c.date_of_birth) : "",
            c.gender === "female" ? "Nữ" : "Nam",
            c.note || "",
            c.status === "enrolled" ? "Đang học" : c.status,
          ]);
          sheets.push({
            sheetName: cl.name,
            headers,
            rows: cRows,
          });
        }
      }

      // Học sinh chưa phân lớp (nếu có)
      const unassigned = (children || []).filter(
        (c) => !c.class_id || !classes.some((cl) => cl.id === c.class_id),
      );
      if (unassigned.length > 0) {
        const uRows = unassigned.map((c) => [
          c.full_name,
          c.nickname || "",
          "Chưa xếp lớp",
          c.parents_summary || "Chưa liên kết",
          c.date_of_birth ? formatDateToDmy(c.date_of_birth) : "",
          c.gender === "female" ? "Nữ" : "Nam",
          c.note || "",
          c.status === "enrolled" ? "Đang học" : c.status,
        ]);
        sheets.push({
          sheetName: "Chưa xếp lớp",
          headers,
          rows: uRows,
        });
      }

      if (sheets.length === 0) {
        setToast({ msg: "Không có dữ liệu học sinh để xuất", tone: "warn" });
        return;
      }

      exportMultiSheetToExcel("danh_sach_hoc_sinh_toan_truong.xlsx", sheets);
      setToast({
        msg: `Đã xuất danh sách học sinh toàn trường ra ${sheets.length} sheet (chia theo từng lớp)`,
        tone: "ok",
      });
      return;
    }

    // Nếu đang chọn một lớp cụ thể
    const currentClass = classes.find((cl) => cl.id === selectedClassId);
    const targetStudents = filtered;
    if (targetStudents.length === 0) {
      setToast({ msg: "Lớp này chưa có học sinh nào để xuất", tone: "warn" });
      return;
    }

    const rows = targetStudents.map((c) => [
      c.full_name,
      c.nickname || "",
      currentClass ? currentClass.name : (c.class_name || "Chưa xếp lớp"),
      c.parents_summary || "Chưa liên kết",
      c.date_of_birth ? formatDateToDmy(c.date_of_birth) : "",
      c.gender === "female" ? "Nữ" : "Nam",
      c.note || "",
      c.status === "enrolled" ? "Đang học" : c.status,
    ]);

    const sheetName = currentClass ? currentClass.name : "HocSinh";
    const filename = currentClass
      ? `danh_sach_hoc_sinh_${currentClass.name.replace(/\s+/g, "_")}.xlsx`
      : "danh_sach_hoc_sinh.xlsx";

    exportToExcel(filename, sheetName, headers, rows);
    setToast({
      msg: `Đã xuất ${rows.length} học sinh của lớp "${sheetName}" ra file Excel`,
      tone: "ok",
    });
  }

  async function handleImportRows(rows: string[][]): Promise<ImportResult> {
    let success = 0;
    let failed = 0;
    const errors: string[] = [];
    const warnings: string[] = [];

    // Theo dõi danh sách học sinh để phát hiện trùng tên trong cùng lớp (cả từ DB lẫn trong file import)
    const workingChildren: {
      id: string;
      full_name: string;
      nickname: string | null;
      class_id: string | null;
      date_of_birth: string | null;
    }[] = (children || []).map((c) => ({
      id: c.id,
      full_name: c.full_name,
      nickname: c.nickname || null,
      class_id: c.class_id,
      date_of_birth: c.date_of_birth,
    }));

    // Theo dõi số bé theo từng lớp để chặn khi lớp đầy sĩ số (cộng dồn trong file).
    const classCounts = new Map<string, number>();
    for (const cl of classes) {
      classCounts.set(cl.id, cl.student_count ?? 0);
    }

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const fullName = row[0]?.trim();
      let nickname = row[1]?.trim() || null;
      const classNameOrId = row[2]?.trim();
      const dob = row[3]?.trim() || null;
      const genderStr = (row[4]?.trim() || "").toLowerCase();
      let parentContact = "";
      let note = "";

      if (row.length >= 7) {
        parentContact = row[5]?.trim() || "";
        note = row[6]?.trim() || "";
      } else {
        const col5 = row[5]?.trim() || "";
        if (/^0\d{9}$/.test(col5) || /^0\d+$/.test(col5)) {
          parentContact = col5;
          note = "";
        } else {
          parentContact = "";
          note = col5;
        }
      }

      if (!fullName) {
        failed++;
        errors.push(`Dòng ${i + 1}: Thiếu họ tên học sinh.`);
        continue;
      }

      let isoDob: string | null = null;
      if (dob) {
        isoDob = parseDateToIso(dob);
        if (!isoDob) {
          failed++;
          errors.push(
            `Dòng ${i + 1} (${fullName}): Ngày sinh ("${dob}") không đúng định dạng DD/MM/YYYY.`,
          );
          continue;
        }
        const today = new Date().toISOString().split("T")[0];
        if (isoDob > today) {
          failed++;
          errors.push(
            `Dòng ${i + 1} (${fullName}): Ngày sinh (${dob}) không thể là ngày trong tương lai.`,
          );
          continue;
        }
      }

      let matchedClassId: string | null = null;
      if (classNameOrId) {
        const found = findClassFlexible(classNameOrId, classes);
        if (found) {
          matchedClassId = found.id;
        }
      }
      if (!matchedClassId && selectedClassId) {
        matchedClassId = selectedClassId;
      }
      if (!matchedClassId && classes.length > 0) {
        matchedClassId = classes[0].id;
      }

      // Chặn nếu lớp đích đã đầy sĩ số (kể cả khi vừa thêm trong file này).
      if (matchedClassId) {
        const targetClass = classes.find((cl) => cl.id === matchedClassId);
        const capacity = targetClass?.capacity ?? null;
        const currentCount = classCounts.get(matchedClassId) ?? 0;
        if (capacity != null && currentCount >= capacity) {
          failed++;
          errors.push(
            `Dòng ${i + 1} (${fullName}): Lớp "${targetClass?.name}" đã đầy sĩ số (${currentCount}/${capacity}). Vui lòng chia sang lớp khác hoặc tăng sĩ số tối đa.`,
          );
          continue;
        }
      }

      // Phát hiện trùng cả họ tên VÀ biệt danh trong cùng lớp học
      if (matchedClassId) {
        const matchingExisting = workingChildren.filter(
          (c) =>
            c.class_id === matchedClassId &&
            hasDuplicateNickname(fullName, nickname, c.full_name, c.nickname)
        );

        if (matchingExisting.length > 0) {
          const baseNick = cleanNickname(nickname, fullName);
          const candidates: DuplicateCandidate[] = [
            ...matchingExisting.map((c) => ({
              id: c.id,
              isNew: false,
              full_name: c.full_name,
              current_nickname: c.nickname,
              date_of_birth: c.date_of_birth,
            })),
            {
              id: "",
              isNew: true,
              full_name: fullName,
              current_nickname: nickname,
              date_of_birth: isoDob,
            },
          ];

          const resolved = resolveDuplicateNicknames(candidates, baseNick);

          // Cập nhật biệt danh cho các bé có sẵn
          for (const resItem of resolved) {
            if (!resItem.isNew && resItem.id) {
              const existMatch = matchingExisting.find((m) => m.id === resItem.id);
              if (existMatch && existMatch.nickname !== resItem.suggested_nickname) {
                try {
                  await updateChild(existMatch.id, { nickname: resItem.suggested_nickname });
                  existMatch.nickname = resItem.suggested_nickname;
                } catch (e) {
                  console.error("Lỗi cập nhật biệt danh bé cũ:", e);
                }
              }
            }
          }

          // Gán biệt danh cho bé mới đang import
          const newResolved = resolved.find((r) => r.isNew);
          if (newResolved) {
            nickname = newResolved.suggested_nickname;
          }

          const targetClass = classes.find((cl) => cl.id === matchedClassId);
          const targetClassName = targetClass ? targetClass.name : "lớp";
          const totalCount = resolved.length;

          warnings.push(
            totalCount === 2
              ? `Dòng ${i + 1} (${fullName}): Trùng họ tên và biệt danh trong lớp "${targetClassName}" (2 bé). Tự động gán: (Lớn) và (Nhỏ) theo tuổi.`
              : `Dòng ${i + 1} (${fullName}): Trùng họ tên và biệt danh trong lớp "${targetClassName}" (tổng cộng ${totalCount} bé). Tự động đánh số thứ tự theo độ tuổi: (1), (2), (3)...`
          );
        }
      }

      const gender = genderStr.includes("nữ") || genderStr === "female" ? "female" : "male";

      // Xử lý liên kết phụ huynh
      let matchedParentId: string | null = null;
      if (parentContact) {
        const foundP = (parents || []).find(
          (p) => p.phone === parentContact || p.full_name.trim().toLowerCase() === parentContact.toLowerCase()
        );
        if (foundP) {
          matchedParentId = foundP.id;
        } else if (/^0\d{9}$/.test(parentContact)) {
          // Tự động tạo phụ huynh mới nếu số điện thoại hợp lệ
          try {
            const pRes = await createParent({
              full_name: `Phụ huynh bé ${fullName}`,
              phone: parentContact,
              relationship: "Phụ huynh",
              username: parentContact,
              password: "123456",
              status: "active",
            });
            if ((pRes as any)?.id) {
              matchedParentId = (pRes as any).id;
              const newParent: Parent = {
                id: matchedParentId!,
                full_name: `Phụ huynh bé ${fullName}`,
                phone: parentContact,
                email: "",
                username: parentContact,
                relationship: "Phụ huynh",
                status: "active",
                children_summary: fullName,
                child_id: null,
                child_ids: [],
                children: [],
              };
              setParents((prev) => [...prev, newParent]);
            }
          } catch (e: any) {
            warnings.push(
              `Dòng ${i + 1} (${fullName}): Không thể tự động tạo phụ huynh với SĐT ${parentContact}: ${e?.message || "Lỗi tạo phụ huynh"}`
            );
          }
        } else {
          warnings.push(
            `Dòng ${i + 1} (${fullName}): SĐT phụ huynh "${parentContact}" không đúng định dạng 10 số bắt đầu bằng 0.`
          );
        }
      }

      try {
        const res = await createChild({
          full_name: fullName,
          nickname,
          class_id: matchedClassId,
          date_of_birth: isoDob,
          gender,
          parent_id: matchedParentId || undefined,
          parent_ids: matchedParentId ? [matchedParentId] : undefined,
          medical_allergies: note,
          status: "enrolled",
        });
        workingChildren.push({
          id: (res as any)?.id || "",
          full_name: fullName,
          nickname,
          class_id: matchedClassId,
          date_of_birth: isoDob,
        });
        if (matchedClassId) {
          classCounts.set(
            matchedClassId,
            (classCounts.get(matchedClassId) ?? 0) + 1,
          );
        }
        success++;
      } catch (err: any) {
        failed++;
        errors.push(`Dòng ${i + 1} (${fullName}): ${err?.message || "Lỗi tạo học sinh"}`);
      }
    }

    if (success > 0) {
      mutate();
      getParents().then(setParents).catch(() => {});
    }
    return { total: rows.length, success, failed, errors, warnings };
  }

  // Lấy danh sách ID phụ huynh ban đầu của học sinh
  function getOriginalParentIds(c: Child): string[] {
    const ids: string[] = [];
    if (c.parent_ids && Array.isArray(c.parent_ids)) {
      ids.push(...c.parent_ids);
    } else if (c.parent_id) {
      ids.push(c.parent_id);
    } else if (parents && parents.length > 0) {
      const matched = parents.filter(
        (p) =>
          (p.child_ids && p.child_ids.includes(c.id)) ||
          (p.children && p.children.some((k: any) => k.id === c.id)),
      );
      ids.push(...matched.map((p) => p.id));
    }
    return Array.from(new Set(ids));
  }

  // Lấy dữ liệu hiện tại của dòng
  function getRowData(c: Child): RowEditState {
    if (tableEdits[c.id]) return tableEdits[c.id];
    let dob = c.date_of_birth || "";
    if (dob.includes("T")) {
      dob = dob.split("T")[0];
    }
    return {
      full_name: c.full_name || "",
      nickname: c.nickname || "",
      class_id: c.class_id || null,
      parent_ids: getOriginalParentIds(c),
      date_of_birth: dob,
      gender: c.gender || "male",
      medical_allergies: c.note || "",
    };
  }

  // Lấy danh sách đối tượng phụ huynh của học sinh
  function getChildParentObjects(c: Child, currentParentIds?: string[]): Parent[] {
    const ids = currentParentIds || getRowData(c).parent_ids;
    if (!parents || parents.length === 0) return [];
    return parents.filter((p) => ids.includes(p.id));
  }

  // Cập nhật giá trị ô input
  function updateCell(c: Child, field: keyof RowEditState, val: any) {
    setTableEdits((prev) => {
      const current = prev[c.id] || getRowData(c);
      return {
        ...prev,
        [c.id]: {
          ...current,
          [field]: val,
        },
      };
    });
  }

  // Thêm / Bớt phụ huynh trong Dropdown Multi-select
  function toggleParentSelection(c: Child, parentId: string) {
    const current = getRowData(c);
    const exists = current.parent_ids.includes(parentId);
    const nextIds = exists
      ? current.parent_ids.filter((id) => id !== parentId)
      : [...current.parent_ids, parentId];
    updateCell(c, "parent_ids", nextIds);
  }

  // Kiểm tra ô có bị sửa đổi so với dữ liệu gốc không
  function isCellDirty(c: Child, field: keyof RowEditState): boolean {
    if (!tableEdits[c.id]) return false;
    const row = tableEdits[c.id];
    if (field === "full_name") return row.full_name.trim() !== (c.full_name || "").trim();
    if (field === "nickname") return row.nickname.trim() !== (c.nickname || "").trim();
    if (field === "class_id") return row.class_id !== (c.class_id || null);
    if (field === "gender") return row.gender !== (c.gender || "male");
    if (field === "medical_allergies") return row.medical_allergies.trim() !== (c.note || "").trim();
    if (field === "date_of_birth") {
      let origDob = c.date_of_birth || "";
      if (origDob.includes("T")) origDob = origDob.split("T")[0];
      return row.date_of_birth !== origDob;
    }
    if (field === "parent_ids") {
      const origIds = getOriginalParentIds(c);
      const curIds = row.parent_ids;
      if (origIds.length !== curIds.length) return true;
      const setOrig = new Set(origIds);
      return curIds.some((id) => !setOrig.has(id));
    }
    return false;
  }

  // Kiểm tra xem dòng có bất kỳ ô nào bị thay đổi hay không
  function isRowDirty(c: Child): boolean {
    if (!tableEdits[c.id]) return false;
    return (
      isCellDirty(c, "full_name") ||
      isCellDirty(c, "nickname") ||
      isCellDirty(c, "class_id") ||
      isCellDirty(c, "parent_ids") ||
      isCellDirty(c, "date_of_birth") ||
      isCellDirty(c, "gender") ||
      isCellDirty(c, "medical_allergies")
    );
  }

  // Danh sách các dòng đang có thay đổi chưa lưu
  const dirtyRows = useMemo(() => {
    return filtered.filter((c) => isRowDirty(c));
  }, [filtered, tableEdits, parents]);

  // Hủy toàn bộ thay đổi chưa lưu
  function cancelAllEdits() {
    setTableEdits({});
    setIsEditMode(false);
    setOpenParentDropdownId(null);
    setToast({ msg: "Đã hủy bỏ mọi thay đổi chưa lưu", tone: "brand" });
  }

  // Lưu hàng loạt tất cả các dòng đã thay đổi (Bulk Save)
  async function handleSaveAllEdits() {
    if (dirtyRows.length === 0) {
      setToast({ msg: "Không có thay đổi nào để lưu", tone: "brand" });
      setIsEditMode(false);
      return;
    }

    for (const c of dirtyRows) {
      const edit = getRowData(c);
      if (!edit.full_name.trim()) {
        setToast({ msg: "Họ tên học sinh không được để trống", tone: "bad" });
        return;
      }
    }

    setSavingTable(true);
    let success = 0;
    let failed = 0;

    for (const c of dirtyRows) {
      const edit = getRowData(c);
      const payload: Partial<ChildPayload> = {
        full_name: edit.full_name.trim(),
        nickname: edit.nickname.trim() || null,
        class_id: edit.class_id,
        date_of_birth: edit.date_of_birth || null,
        gender: edit.gender,
        medical_allergies: edit.medical_allergies.trim() || null,
        parent_ids: edit.parent_ids,
        parent_id: edit.parent_ids[0] || null,
      };

      try {
        await updateChild(c.id, payload);
        success++;
      } catch (e) {
        failed++;
      }
    }

    setSavingTable(false);
    setTableEdits({});
    setIsEditMode(false);
    setOpenParentDropdownId(null);
    mutate();

    if (failed === 0) {
      setToast({ msg: `Đã lưu thành công ${success} học sinh!`, tone: "ok" });
    } else {
      setToast({ msg: `Đã lưu ${success} học sinh (${failed} học sinh bị lỗi)`, tone: "warn" });
    }
  }

  function openCreate() {
    setEditing(null);
    setForm({ ...EMPTY, class_id: classes[0]?.id ?? null });
    setDrawerOpen(true);
  }

  function openEdit(c: Child) {
    setEditing(c);
    setForm({
      full_name: c.full_name,
      nickname: c.nickname,
      class_id: c.class_id,
      parent_ids: c.parent_ids,
      primary_parent_id: c.parent_id,
      date_of_birth: c.date_of_birth || "",
      gender: c.gender || "male",
      medical_allergies: c.note || "",
      allergy_status: c.allergy_status || "unknown",
      care_notes: c.care_notes || "",
      status: c.status,
    });
    setDrawerOpen(true);
  }

  async function handleSave() {
    if (!form.full_name.trim()) {
      setToast({ msg: "Vui lòng nhập họ tên học sinh", tone: "bad" });
      return;
    }
    if (form.date_of_birth) {
      const today = todayIsoStr();
      if (form.date_of_birth > today) {
        setToast({
          msg: `Ngày sinh không thể là ngày trong tương lai (tối đa ${formatDateToDmy(today)})`,
          tone: "bad",
        });
        return;
      }
    }
    if (form.allergy_status === "present" && !form.medical_allergies.trim()) {
      setToast({ msg: "Vui lòng nhập mô tả dị ứng của bé", tone: "bad" });
      return;
    }
    // Chặn sớm lớp đã đầy sĩ số (backend cũng chặn lại để chắc chắn).
    if (selectedClassIsFull) {
      setToast({
        msg: `Lớp "${selectedClass?.name}" đã đầy sĩ số (${selectedClassCount}/${selectedClassCapacity}). Vui lòng chọn lớp khác hoặc tăng sĩ số tối đa.`,
        tone: "bad",
      });
      return;
    }
    setSaving(true);
    try {
      const parent_items = form.parent_ids.map((pid) => ({
        parent_id: pid,
        relationship:
          parents.find((p) => p.id === pid)?.relationship || "Phụ huynh",
        is_primary: pid === form.primary_parent_id,
        can_pickup: true,
      }));
      const payload: ChildPayload = {
        full_name: form.full_name.trim(),
        nickname: form.nickname.trim() || null,
        class_id: form.class_id,
        parent_id: form.primary_parent_id,
        parent_ids: form.parent_ids,
        parent_items,
        date_of_birth: form.date_of_birth || null,
        gender: form.gender,
        medical_allergies: form.medical_allergies.trim() || null,
        allergy_status: form.allergy_status,
        care_notes: form.care_notes.trim() || null,
        status: form.status,
      };
      // Cảnh báo trùng cả họ tên VÀ biệt danh trong cùng một lớp (áp dụng cho cả tạo mới lẫn sửa đổi/chuyển lớp)
      if (form.class_id) {
        const matchingExisting = (children || []).filter(
          (c) =>
            c.id !== (editing?.id ?? "") &&
            c.class_id === form.class_id &&
            hasDuplicateNickname(form.full_name, form.nickname, c.full_name, c.nickname)
        );

        if (matchingExisting.length > 0) {
          setSaving(false);
          const targetClassName = classes.find((cl) => cl.id === form.class_id)?.name || "lớp";
          const baseNick = cleanNickname(form.nickname, form.full_name);

          const candidates: DuplicateCandidate[] = [
            ...matchingExisting.map((c) => ({
              id: c.id,
              isNew: false,
              full_name: c.full_name,
              current_nickname: c.nickname,
              date_of_birth: c.date_of_birth,
            })),
            {
              id: editing?.id,
              isNew: true,
              full_name: form.full_name.trim(),
              current_nickname: form.nickname.trim(),
              date_of_birth: form.date_of_birth,
            },
          ];

          const items = resolveDuplicateNicknames(candidates, baseNick);

          setDuplicateAlert({
            targetClassName,
            totalDuplicates: items.length,
            items,
            payload,
            editingChildId: editing?.id ?? null,
          });
          return;
        }
      }

      if (editing) {
        await updateChild(editing.id, payload);
        setToast({ msg: "Đã cập nhật học sinh", tone: "ok" });
      } else {
        await createChild(payload);
        setToast({ msg: "Đã thêm học sinh mới", tone: "ok" });
      }
      setDrawerOpen(false);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể lưu học sinh", tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  async function confirmSaveStudent(payload: ChildPayload, applyNicknames: boolean) {
    if (!duplicateAlert) return;
    setSaving(true);
    const alertData = duplicateAlert;
    setDuplicateAlert(null);
    try {
      if (applyNicknames) {
        // 1. Cập nhật biệt danh mới cho các bé đã có sẵn trong lớp trên DB
        for (const item of alertData.items) {
          if (!item.isNew && item.id) {
            const finalNick = item.custom_nickname.trim() || item.suggested_nickname;
            if (finalNick !== item.current_nickname) {
              try {
                await updateChild(item.id, {
                  nickname: finalNick,
                });
              } catch (e) {
                console.error("Lỗi cập nhật biệt danh bé cũ:", item.id, e);
              }
            }
          }
        }

        // 2. Gán biệt danh cho bé đang tạo/cập nhật
        const newItem = alertData.items.find((it) => it.isNew);
        if (newItem) {
          payload.nickname = newItem.custom_nickname.trim() || newItem.suggested_nickname;
        }
      }

      if (alertData.editingChildId) {
        await updateChild(alertData.editingChildId, payload);
        setToast({
          msg: applyNicknames
            ? `Đã cập nhật học sinh "${payload.full_name}" (${payload.nickname}) và đồng bộ biệt danh ${alertData.items.length - 1} bé trong lớp.`
            : `Đã cập nhật học sinh "${payload.full_name}"`,
          tone: "ok",
        });
      } else {
        await createChild(payload);
        setToast({
          msg: applyNicknames
            ? `Đã thêm học sinh "${payload.full_name}" (${payload.nickname}) và đồng bộ biệt danh ${alertData.items.length - 1} bé trong lớp.`
            : `Đã thêm học sinh "${payload.full_name}"`,
          tone: "ok",
        });
      }
      setDrawerOpen(false);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể lưu học sinh", tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(c: Child) {
    try {
      await deleteChild(c.id);
      setToast({ msg: `Đã xóa ${c.full_name}`, tone: "ok" });
      setSelectedIds((prev) => prev.filter((id) => id !== c.id));
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
  }

  const allSelected =
    filtered.length > 0 && filtered.every((c) => selectedIds.includes(c.id));
  const someSelected =
    selectedIds.length > 0 && !allSelected;

  function toggleSelectAll() {
    if (allSelected) {
      setSelectedIds([]);
    } else {
      setSelectedIds(filtered.map((c) => c.id));
    }
  }

  function toggleSelect(id: string) {
    setSelectedIds((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    );
  }

  async function handleBulkDelete() {
    if (selectedIds.length === 0) return;
    setBulkDeleting(true);
    try {
      const res = await deleteChildrenBatch(selectedIds);
      setToast({
        msg: res.message || `Đã xóa ${selectedIds.length} học sinh`,
        tone: "ok",
      });
      setSelectedIds([]);
      mutate();
    } catch (err: any) {
      setToast({
        msg: err?.message || "Không thể xóa hàng loạt học sinh",
        tone: "bad",
      });
    } finally {
      setBulkDeleting(false);
      setConfirmBulkDel(false);
    }
  }

  function toggleParent(pid: string) {
    setForm((f) => {
      const exists = f.parent_ids.includes(pid);
      const next = exists
        ? f.parent_ids.filter((x) => x !== pid)
        : [...f.parent_ids, pid];
      const primary = f.primary_parent_id && next.includes(f.primary_parent_id)
        ? f.primary_parent_id
        : next[0] ?? null;
      return { ...f, parent_ids: next, primary_parent_id: primary };
    });
  }

  if (!ready) return null;

  return (
    <SchoolAdminLayout
      active="students"
      pageTitle="Quản lý Học sinh"
      pageAction={
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => {
              mutate();
              setToast({ msg: "Đã đồng bộ dữ liệu mới nhất", tone: "brand" });
            }}
            className="px-3 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] font-bold text-xs transition"
            title="Làm mới"
          >
            ↻
          </button>
          <button
            onClick={handleExportExcel}
            className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] font-bold text-xs flex items-center gap-1.5 transition"
            title={
              selectedClassId
                ? `Xuất danh sách học sinh của lớp đang lọc ra file Excel`
                : "Xuất danh sách học sinh toàn trường ra file Excel (tự động chia theo từng sheet theo lớp)"
            }
          >
            📥 Xuất Excel
          </button>
          <button
            onClick={() => setImportOpen(true)}
            className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] font-bold text-xs flex items-center gap-1.5 transition"
            title="Nhập dữ liệu từ file Excel / CSV"
          >
            📤 Nhập file
          </button>
          {/* Nút Chỉnh sửa */}
          <button
            onClick={() => {
              if (isEditMode && dirtyRows.length > 0) {
                if (window.confirm("Bạn đang có thay đổi chưa lưu. Bạn có muốn thoát chế độ sửa và hủy thay đổi không?")) {
                  cancelAllEdits();
                }
                return;
              }
              setIsEditMode(!isEditMode);
              setOpenParentDropdownId(null);
            }}
            className={`px-4 py-2 rounded-full border border-[#E5E8EB] text-xs font-bold flex items-center gap-1.5 transition ${
              isEditMode
                ? "bg-[#FFF0D9] text-[#B0791B] border-[#B0791B]"
                : "bg-white text-[#087F70] hover:bg-[#E6F3EB]"
            }`}
            title="Bật/tắt chế độ chỉnh sửa trực tiếp trên bảng"
          >
            <span>✏️</span>
            <span>{isEditMode ? "Đang chỉnh sửa" : "Chỉnh sửa"}</span>
          </button>

          {/* Nút Lưu tất cả thay đổi khi ở Edit Mode */}
          {isEditMode && (
            <>
              <button
                onClick={cancelAllEdits}
                disabled={savingTable}
                className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#65727D] hover:bg-[#F6F7F8] font-bold text-xs transition"
                title="Hủy bỏ mọi thay đổi chưa lưu"
              >
                ✕ Hủy thay đổi
              </button>
              <button
                onClick={handleSaveAllEdits}
                disabled={savingTable}
                className="px-4 py-2 rounded-full bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-xs flex items-center gap-1.5 shadow-sm transition"
                title="Lưu tất cả thay đổi trên mọi dòng"
              >
                {savingTable ? (
                  <>
                    <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Đang lưu ({dirtyRows.length})...</span>
                  </>
                ) : (
                  <>
                    <span>💾</span>
                    <span>Lưu tất cả thay đổi</span>
                    {dirtyRows.length > 0 && (
                      <span className="bg-white/20 text-white text-[10px] px-1.5 py-0.2 rounded-full font-bold ml-1">
                        {dirtyRows.length}
                      </span>
                    )}
                  </>
                )}
              </button>
            </>
          )}

          <button
            onClick={openCreate}
            className="px-4 py-2 rounded-full bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-xs shadow-sm flex items-center gap-1.5 transition"
          >
            + Thêm học sinh
          </button>
        </div>
      }
    >
      <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-4 mb-4 shadow-soft flex flex-col sm:flex-row gap-3 items-stretch sm:items-center">
        <div className="flex-1">
          <SearchBar
            value={query}
            onChange={setQuery}
            placeholder="Tìm học sinh, lớp, dị ứng, phụ huynh..."
          />
        </div>
        <div className="w-full sm:w-64">
          <ClassFilterSelect
            classes={classes}
            value={selectedClassId}
            onChange={setSelectedClassId}
          />
        </div>
      </div>

      {/* Banner thông báo các dòng có thay đổi chưa lưu */}
      {isEditMode && dirtyRows.length > 0 && (
        <div className="mb-3 px-4 py-2.5 bg-amber-50 border border-amber-200 text-amber-900 rounded-lg flex items-center justify-between shadow-sm animate-fadeIn">
          <div className="flex items-center gap-2 text-xs sm:text-sm">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse shrink-0" />
            <span className="font-semibold">Đang có {dirtyRows.length} học sinh có chỉnh sửa chưa lưu.</span>
            <span className="text-xs text-amber-700 hidden sm:inline">(Các ô có viền vàng là các trường đã thay đổi)</span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={cancelAllEdits}
              disabled={savingTable}
              className="text-xs px-2.5 py-1 text-amber-800 hover:text-bad hover:underline font-medium"
            >
              Hủy bỏ
            </button>
            <button
              onClick={handleSaveAllEdits}
              disabled={savingTable}
              className="kbtn text-xs font-bold text-white py-1 px-3 shadow"
              style={{ background: "#16665a" }}
            >
              {savingTable ? "Đang lưu..." : `Lưu tất cả (${dirtyRows.length})`}
            </button>
          </div>
        </div>
      )}

      <div className="bg-white rounded-[24px] border border-[#E5E8EB] overflow-hidden shadow-soft">
        {!children && !childrenError ? (
          <Spinner />
        ) : childrenError ? (
          <div className="text-center py-12">
            <div className="text-bad font-semibold mb-2">
              {(childrenError as any)?.status === 401
                ? "Phiên đăng nhập đã hết hạn. Đang chuyển về trang đăng nhập..."
                : `Không thể tải danh sách học sinh (${(childrenError as any)?.detail || "Vui lòng thử lại"})`}
            </div>
            <button onClick={() => mutate()} className="kbtn kbtn-secondary mt-2">
              Thử lại
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-5xl mb-2">🧒</div>
            <div className="text-ink font-semibold">
              {query ? "Không có kết quả phù hợp." : "Chưa có học sinh nào"}
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead
                className="text-xs uppercase tracking-wider transition-colors duration-200"
                style={{
                  background: selectedIds.length > 0 ? "#FDF8F6" : "#EFECE5",
                  color: selectedIds.length > 0 ? "#BB4A34" : "#605D57",
                }}
              >
                {selectedIds.length > 0 ? (
                  <tr className="border-b border-[#F2D5CE]">
                    <th className="px-3 py-2.5 text-center w-10">
                      <input
                        type="checkbox"
                        className="rounded cursor-pointer"
                        checked={allSelected}
                        ref={(el) => {
                          if (el) el.indeterminate = someSelected;
                        }}
                        onChange={toggleSelectAll}
                        title="Bỏ chọn tất cả"
                      />
                    </th>
                    <th colSpan={4} className="px-4 py-2.5 text-left font-semibold normal-case text-xs">
                      <div className="flex items-center gap-2">
                        <span className="w-5 h-5 rounded-full flex items-center justify-center text-[10px] text-white font-bold bg-[#BB4A34]">
                          {selectedIds.length}
                        </span>
                        <span className="text-[#BB4A34] font-bold">
                          Đã chọn {selectedIds.length} học sinh
                        </span>
                      </div>
                    </th>
                    <th colSpan={2} className="px-4 py-2.5 text-right font-semibold normal-case">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => setSelectedIds([])}
                          className="kbtn kbtn-secondary text-[11px] py-1 px-2.5 h-auto leading-none"
                          disabled={bulkDeleting}
                        >
                          Bỏ chọn
                        </button>
                        <button
                          onClick={() => setConfirmBulkDel(true)}
                          className="kbtn text-[11px] py-1 px-2.5 h-auto leading-none text-white font-medium flex items-center gap-1.5"
                          style={{ background: "#BB4A34" }}
                          disabled={bulkDeleting}
                        >
                          <span>🗑️</span>
                          <span>Xóa đã chọn ({selectedIds.length})</span>
                        </button>
                      </div>
                    </th>
                  </tr>
                ) : (
                  <tr>
                    <th className="px-3 py-3 text-center w-10">
                      <input
                        type="checkbox"
                        className="rounded cursor-pointer"
                        checked={allSelected}
                        ref={(el) => {
                          if (el) el.indeterminate = someSelected;
                        }}
                        onChange={toggleSelectAll}
                        title="Chọn tất cả học sinh hiển thị"
                      />
                    </th>
                    <th className="px-4 py-3 text-left font-semibold">Họ tên</th>
                    <th className="px-4 py-3 text-left font-semibold">Lớp</th>
                    <th className="px-4 py-3 text-left font-semibold">Phụ huynh</th>
                    <th className="px-4 py-3 text-left font-semibold">Ngày sinh</th>
                    <th className="px-4 py-3 text-left font-semibold">Ghi chú</th>
                    <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                  </tr>
                )}
              </thead>
              <tbody>
                {filtered.map((c, idx) => {
                  const isSelected = selectedIds.includes(c.id);
                  const isDirty = isRowDirty(c);
                  const rowData = getRowData(c);
                  const parentObjects = getChildParentObjects(c, rowData.parent_ids);

                  // Lọc danh sách phụ huynh trong dropdown
                  const qParent = parentSearchQuery.trim().toLowerCase();
                  const filteredParentsForDropdown = (parents || []).filter((p) => {
                    if (!qParent) return true;
                    const pName = (p.full_name || "").toLowerCase();
                    const pPhone = (p.phone || "").toLowerCase();
                    const pRel = (p.relationship || "").toLowerCase();
                    return pName.includes(qParent) || pPhone.includes(qParent) || pRel.includes(qParent);
                  });

                  // Class ô input ở Chế độ Sửa: viền mỏng xám nhạt, padding thoải mái
                  const editInputBase =
                    "w-full bg-white border border-slate-300 rounded px-2.5 py-1.5 text-xs text-slate-800 transition-all focus:border-[#4B6F8C] focus:ring-1 focus:ring-[#4B6F8C]/30 focus:outline-none";

                  return (
                    <tr
                      key={c.id}
                      className={`${idx > 0 ? "border-t border-slate-100" : ""} transition-colors ${
                        isSelected
                          ? "bg-[#FDF8F6]"
                          : isDirty
                          ? "bg-amber-50/25"
                          : "hover:bg-slate-50/80"
                      }`}
                    >
                      {/* Checkbox chọn dòng + Chấm tròn báo dirty */}
                      <td className="px-3 py-3 text-center">
                        <div className="flex items-center justify-center gap-1.5">
                          {isDirty ? (
                            <span
                              className="w-2 h-2 rounded-full bg-amber-500 animate-pulse shrink-0"
                              title="Dòng này có thay đổi chưa lưu"
                            />
                          ) : (
                            <span className="w-2 h-2 shrink-0" />
                          )}
                          <input
                            type="checkbox"
                            className="rounded cursor-pointer text-brand focus:ring-brand/30"
                            checked={isSelected}
                            onChange={() => toggleSelect(c.id)}
                            title="Chọn dòng"
                          />
                        </div>
                      </td>

                      {/* Cột Họ tên: Avatar + Tên (đậm) + Biệt danh */}
                      <td className="px-3.5 py-3">
                        <div className="flex items-center gap-2.5">
                          <div
                            className="w-8 h-8 flex items-center justify-center rounded-full text-white text-xs font-semibold shrink-0 shadow-2xs"
                            style={{ background: "#8A5E12" }}
                          >
                            {(rowData.full_name || "B").charAt(0).toUpperCase()}
                          </div>
                          {isEditMode ? (
                            <div className="flex flex-col gap-2 flex-1 min-w-[160px]">
                              <input
                                type="text"
                                className={`${editInputBase} font-semibold ${
                                  isCellDirty(c, "full_name")
                                    ? "bg-amber-50 border-amber-400 text-amber-950"
                                    : ""
                                }`}
                                value={rowData.full_name}
                                onChange={(e) => updateCell(c, "full_name", e.target.value)}
                                placeholder="Họ và tên học sinh..."
                              />
                              <input
                                type="text"
                                className={`${editInputBase} text-[11px] text-slate-500 py-1 ${
                                  isCellDirty(c, "nickname")
                                    ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                    : ""
                                }`}
                                value={rowData.nickname}
                                onChange={(e) => updateCell(c, "nickname", e.target.value)}
                                placeholder="Biệt danh (ở nhà)..."
                              />
                            </div>
                          ) : (
                            <div className="max-w-[170px] truncate">
                              <div className="font-semibold text-slate-800 text-sm truncate">
                                {c.full_name}
                                {isDirty && (
                                  <span className="ml-1.5 text-[10px] text-amber-700 bg-amber-100 px-1.5 py-0.2 rounded font-normal">
                                    chưa lưu
                                  </span>
                                )}
                              </div>
                              <div className="text-xs text-slate-500 font-normal mt-0.5 truncate">
                                {c.nickname ? `Biệt danh: ${c.nickname}` : "—"}
                              </div>
                            </div>
                          )}
                        </div>
                      </td>

                      {/* Cột Lớp: Tag/Pill ở View Mode vs Select ở Edit Mode */}
                      <td className="px-3.5 py-3">
                        {isEditMode ? (
                          <select
                            className={`${editInputBase} min-w-[130px] ${
                              isCellDirty(c, "class_id")
                                ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                : ""
                            }`}
                            value={rowData.class_id ?? ""}
                            onChange={(e) => updateCell(c, "class_id", e.target.value || null)}
                          >
                            <option value="">-- Chưa xếp lớp --</option>
                            {classes.map((cls) => (
                              <option key={cls.id} value={cls.id}>
                                {cls.name}
                              </option>
                            ))}
                          </select>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium bg-amber-50 text-amber-800 border border-amber-200 shadow-2xs truncate max-w-[120px]">
                            {c.class_name || "Chưa xếp lớp"}
                          </span>
                        )}
                      </td>

                      {/* Cột Phụ huynh: Dropdown Multi-select ở Edit Mode vs Tag Badge ở View Mode */}
                      <td className="px-3.5 py-3 relative">
                        {isEditMode ? (
                          <div className="min-w-[190px] relative">
                            {/* Nút mở Dropdown chọn Phụ huynh */}
                            <button
                              type="button"
                              onClick={() => {
                                setOpenParentDropdownId(openParentDropdownId === c.id ? null : c.id);
                                setParentSearchQuery("");
                              }}
                              className={`w-full text-left bg-white border rounded px-2.5 py-1.5 text-xs flex items-center justify-between gap-1 transition-all ${
                                isCellDirty(c, "parent_ids")
                                  ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                  : "border-slate-300 hover:border-[#4B6F8C] focus:ring-1 focus:ring-[#4B6F8C]/30 text-slate-800"
                              }`}
                              title="Click để chọn danh sách phụ huynh liên kết"
                            >
                              <div className="truncate flex-1">
                                {parentObjects.length === 0 ? (
                                  <span className="text-slate-400 italic text-xs">Chọn phụ huynh...</span>
                                ) : parentObjects.length === 1 ? (
                                  <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-slate-100 text-slate-700 border border-slate-200 truncate max-w-[140px]">
                                    {parentObjects[0].full_name}
                                  </span>
                                ) : (
                                  <div className="flex items-center gap-1">
                                    <span
                                      className="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-slate-100 text-slate-700 border border-slate-200 truncate max-w-[105px]"
                                      title={parentObjects[0].full_name}
                                    >
                                      {parentObjects[0].full_name}
                                    </span>
                                    <span
                                      className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold bg-brand/10 text-brand border border-brand/20 shrink-0"
                                      title={parentObjects.map((p) => `${p.full_name} (${p.phone})`).join(", ")}
                                    >
                                      +{parentObjects.length - 1}
                                    </span>
                                  </div>
                                )}
                              </div>
                              <span className="text-slate-400 text-[10px] shrink-0 ml-1.5">▼</span>
                            </button>

                            {/* Dropdown Multi-select Box Phụ huynh */}
                            {openParentDropdownId === c.id && (
                              <>
                                <div
                                  className="fixed inset-0 z-40"
                                  onClick={() => setOpenParentDropdownId(null)}
                                />
                                <div
                                  className="absolute left-0 top-full mt-1.5 w-76 bg-white rounded-lg shadow-xl border border-slate-200 z-50 p-2.5 space-y-2 animate-fadeIn"
                                  onClick={(e) => e.stopPropagation()}
                                >
                                  {/* Thanh tìm kiếm phụ huynh */}
                                  <div className="relative">
                                    <input
                                      type="text"
                                      value={parentSearchQuery}
                                      onChange={(e) => setParentSearchQuery(e.target.value)}
                                      placeholder="Tìm tên phụ huynh, SĐT..."
                                      className="w-full text-xs px-2.5 py-1.5 border border-slate-200 rounded focus:border-[#4B6F8C] focus:outline-none"
                                      autoFocus
                                    />
                                    {parentSearchQuery && (
                                      <button
                                        type="button"
                                        onClick={() => setParentSearchQuery("")}
                                        className="absolute right-2 top-1.5 text-xs text-slate-400 hover:text-slate-600"
                                      >
                                        ✕
                                      </button>
                                    )}
                                  </div>

                                  {/* Danh sách phụ huynh kèm checkbox */}
                                  <div className="max-h-48 overflow-y-auto space-y-0.5 divide-y divide-slate-50">
                                    {filteredParentsForDropdown.length === 0 ? (
                                      <div className="text-center py-3 text-xs text-slate-400">
                                        Không tìm thấy phụ huynh nào
                                      </div>
                                    ) : (
                                      filteredParentsForDropdown.map((p) => {
                                        const isChecked = rowData.parent_ids.includes(p.id);
                                        return (
                                          <label
                                            key={p.id}
                                            className="flex items-center gap-2 px-2 py-1.5 hover:bg-slate-50 rounded cursor-pointer text-xs"
                                          >
                                            <input
                                              type="checkbox"
                                              checked={isChecked}
                                              onChange={() => toggleParentSelection(c, p.id)}
                                              className="rounded text-brand focus:ring-brand/30 cursor-pointer"
                                            />
                                            <div className="flex-1 min-w-0">
                                              <div className="font-medium text-slate-800 truncate">
                                                {p.full_name}
                                                {p.relationship && (
                                                  <span className="text-slate-500 text-[11px] ml-1">({p.relationship})</span>
                                                )}
                                              </div>
                                              <div className="text-[11px] text-slate-400">{p.phone}</div>
                                            </div>
                                          </label>
                                        );
                                      })
                                    )}
                                  </div>

                                  {/* Footer Dropdown */}
                                  <div className="flex items-center justify-between pt-1.5 border-t border-slate-100 text-[11px]">
                                    <span className="text-slate-500">
                                      Đã chọn: <strong className="text-slate-700">{rowData.parent_ids.length}</strong> PH
                                    </span>
                                    <button
                                      type="button"
                                      onClick={() => setOpenParentDropdownId(null)}
                                      className="text-brand font-semibold hover:underline"
                                    >
                                      Xong
                                    </button>
                                  </div>
                                </div>
                              </>
                            )}
                          </div>
                        ) : (
                          /* View Mode: Hiển thị Phụ huynh dạng text + tag sạch sẽ */
                          <div className="max-w-xs">
                            {parentObjects.length === 0 ? (
                              <div className="text-ink line-clamp-1">
                                {c.parents_summary || <span className="text-slate-400 italic text-xs">Chưa liên kết</span>}
                              </div>
                            ) : parentObjects.length === 1 ? (
                              <div className="truncate">
                                <div className="font-semibold text-slate-800 text-xs truncate">
                                  {parentObjects[0].full_name}
                                  {parentObjects[0].relationship && (
                                    <span className="text-slate-500 font-normal ml-1">({parentObjects[0].relationship})</span>
                                  )}
                                </div>
                                {parentObjects[0].phone && (
                                  <div className="text-xs text-slate-500 font-normal mt-0.5 truncate">
                                    {parentObjects[0].phone}
                                  </div>
                                )}
                              </div>
                            ) : (
                              <div className="flex items-center gap-1.5 truncate">
                                <div className="truncate max-w-[130px]">
                                  <span className="font-semibold text-slate-800 text-xs truncate">
                                    {parentObjects[0].full_name}
                                  </span>
                                </div>
                                <span
                                  className="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-semibold bg-brand/10 text-brand border border-brand/20 cursor-help shrink-0"
                                  title={parentObjects.map((p) => `${p.full_name} (${p.phone || "Chưa có SĐT"})`).join(", ")}
                                >
                                  +{parentObjects.length - 1}
                                </span>
                              </div>
                            )}
                          </div>
                        )}
                      </td>

                      {/* Cột Ngày sinh / Giới tính: Input date chuẩn + Dropdown nhỏ gọn ở Edit Mode */}
                      <td className="px-3.5 py-3 text-ink-soft">
                        {isEditMode ? (
                          <div className="flex flex-col gap-1.5 min-w-[130px]">
                            <input
                              type="date"
                              className={`${editInputBase} py-1 px-2 ${
                                isCellDirty(c, "date_of_birth")
                                  ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                  : ""
                              }`}
                              value={rowData.date_of_birth}
                              onChange={(e) => updateCell(c, "date_of_birth", e.target.value)}
                              title="Ngày sinh (DD/MM/YYYY)"
                            />
                            <select
                              className={`${editInputBase} py-1 px-2 text-[11px] ${
                                isCellDirty(c, "gender")
                                  ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                  : ""
                              }`}
                              value={rowData.gender}
                              onChange={(e) => updateCell(c, "gender", e.target.value)}
                            >
                              <option value="male">Nam</option>
                              <option value="female">Nữ</option>
                            </select>
                          </div>
                        ) : (
                          <div className="flex items-center gap-1.5">
                            <span className="text-slate-700 text-xs font-medium">
                              {c.date_of_birth ? formatDate(c.date_of_birth) : "—"}
                            </span>
                            {c.gender === "female" ? (
                              <span className="text-[10px] px-1.5 py-0.2 rounded bg-pink-50 text-pink-700 border border-pink-200 font-medium">
                                Nữ
                              </span>
                            ) : (
                              <span className="text-[10px] px-1.5 py-0.2 rounded bg-blue-50 text-blue-700 border border-blue-200 font-medium">
                                Nam
                              </span>
                            )}
                          </div>
                        )}
                      </td>

                      {/* Cột Ghi chú: Text tĩnh ở View Mode vs Input ở Edit Mode */}
                      <td className="px-3.5 py-3 text-ink-soft">
                        {isEditMode ? (
                          <input
                            type="text"
                            className={`${editInputBase} min-w-[140px] ${
                              isCellDirty(c, "medical_allergies")
                                ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                : ""
                            }`}
                            value={rowData.medical_allergies}
                            onChange={(e) => updateCell(c, "medical_allergies", e.target.value)}
                            placeholder="Ghi chú / dị ứng..."
                          />
                        ) : (
                          <div className="max-w-xs truncate text-xs text-slate-600" title={c.note || ""}>
                            {c.note || "—"}
                          </div>
                        )}
                      </td>

                      {/* Cột Thao tác: Icon Sửa ✏️ & Xóa 🗑️ (màu đỏ) */}
                      <td className="px-3.5 py-3 text-right whitespace-nowrap">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            type="button"
                            onClick={() => openEdit(c)}
                            className="p-1.5 rounded-lg text-slate-500 hover:text-brand hover:bg-slate-100 transition-colors"
                            title="Chỉnh sửa chi tiết học sinh"
                          >
                            <span className="text-sm">✏️</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => setConfirmDel(c)}
                            className="p-1.5 rounded-lg text-red-500 hover:text-red-700 hover:bg-red-50 transition-colors"
                            title="Xóa học sinh này"
                          >
                            <span className="text-sm">🗑️</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="flex flex-col sm:flex-row items-center justify-between text-xs text-[#65727D] mt-2 mb-4 gap-2">
        <div>💡 Hồ sơ học sinh kết nối tự động với sổ liên lạc và điểm danh hàng ngày của giáo viên.</div>
        <div>Tổng: <span className="font-bold text-[#102737]">{filtered.length}</span> học sinh</div>
      </div>

      <Drawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={editing ? "Chỉnh sửa học sinh" : "Thêm học sinh mới"}
        footer={
          <>
            <button
              onClick={() => setDrawerOpen(false)}
              className="kbtn kbtn-secondary"
              disabled={saving}
            >
              Hủy
            </button>
            <button onClick={handleSave} className="kbtn kbtn-primary" disabled={saving}>
              {saving ? "Đang lưu..." : editing ? "Lưu thay đổi" : "Tạo học sinh"}
            </button>
          </>
        }
      >
        <FormField label="Họ và tên" required>
          <input
            className="kinput"
            value={form.full_name}
            onChange={(e) => setForm({ ...form, full_name: e.target.value })}
          />
        </FormField>
        <FormField label="Biệt danh">
          <input
            className="kinput"
            value={form.nickname}
            onChange={(e) => setForm({ ...form, nickname: e.target.value })}
            placeholder="Bắp, Miu, ..."
          />
        </FormField>
        <FormField label="Lớp học" required>
          <SearchableSelect
            options={classFormOptions}
            value={form.class_id ?? ""}
            onChange={(val) => setForm({ ...form, class_id: val || null })}
            placeholder="-- Chọn lớp --"
            searchPlaceholder="Tìm kiếm tên lớp, phòng..."
            prefixIcon={<span className="text-sm select-none">🏫</span>}
          />
        </FormField>
        {selectedClassIsFull && (
          <div
            className="text-xs rounded-control px-3 py-2"
            style={{ background: "#F6EED9", color: "#8A5E12" }}
          >
            Lớp đã đầy sĩ số ({selectedClassCount}/{selectedClassCapacity}). Hệ thống sẽ
            chặn khi lưu — vui lòng chọn lớp khác hoặc tăng sĩ số ở trang Quản lý lớp.
          </div>
        )}
        <FormField
          label="Ngày sinh"
          hint={
            form.date_of_birth
              ? `Đã chọn: ${formatDateToDmy(form.date_of_birth)}`
              : "Nhập theo định dạng dd/mm/yyyy"
          }
        >
          <DateInput
            value={form.date_of_birth}
            max={todayIsoStr()}
            onChange={(val) => setForm({ ...form, date_of_birth: val })}
            onInvalid={(msg) => setToast({ msg, tone: "bad" })}
          />
        </FormField>
        <FormField label="Giới tính">
          <div className="flex gap-2">
            {[
              { v: "male", l: "Nam" },
              { v: "female", l: "Nữ" },
              { v: "other", l: "Khác" },
            ].map((g) => (
              <button
                key={g.v}
                type="button"
                onClick={() => setForm({ ...form, gender: g.v })}
                className={`px-3 py-1.5 rounded-control text-xs font-semibold border ${
                  form.gender === g.v
                    ? "text-white border-transparent"
                    : "bg-white text-ink border-line-strong"
                }`}
                style={form.gender === g.v ? { background: "#16665a" } : {}}
              >
                {g.l}
              </button>
            ))}
          </div>
        </FormField>
        <FormField
          label="Phụ huynh liên kết (có thể chọn nhiều)"
          hint="Phụ huynh đầu tiên được tick sẽ là phụ huynh chính."
        >
          {parents.length === 0 ? (
            <div className="text-xs text-ink-faint">
              Chưa có phụ huynh nào. Hãy tạo phụ huynh trước.
            </div>
          ) : (
            <div className="space-y-2 max-h-64 overflow-auto pr-1">
              {parents.map((p) => {
                const checked = form.parent_ids.includes(p.id);
                return (
                  <label
                    key={p.id}
                    className="flex items-center gap-2 px-3 py-2 rounded-control border border-line cursor-pointer hover:bg-sunken"
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggleParent(p.id)}
                      style={{ accentColor: "#16665a" }}
                    />
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-ink text-sm">
                        {p.full_name}
                        {p.relationship && (
                          <span className="text-xs text-ink-soft ml-1">
                            ({p.relationship})
                          </span>
                        )}
                      </div>
                      <div className="text-xs text-ink-soft truncate">
                        {p.phone}
                        {p.email && ` · ${p.email}`}
                      </div>
                    </div>
                    {checked && form.parent_ids.length > 1 && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault();
                          setForm({ ...form, primary_parent_id: p.id });
                        }}
                        className="text-[11px] font-bold px-2 py-0.5 rounded-control"
                        style={{
                          background:
                            form.primary_parent_id === p.id
                              ? "#16665a"
                              : "#EFECE5",
                          color: form.primary_parent_id === p.id ? "white" : "#605D57",
                        }}
                      >
                        {form.primary_parent_id === p.id ? "★ Chính" : "Đặt làm chính"}
                      </button>
                    )}
                  </label>
                );
              })}
            </div>
          )}
        </FormField>
        <FormField label="Trạng thái dị ứng">
          <select
            className="kinput"
            value={form.allergy_status}
            onChange={(e) => setForm({ ...form, allergy_status: e.target.value })}
          >
            <option value="unknown">Chưa khai báo</option>
            <option value="none">Không có dị ứng được biết</option>
            <option value="present">Có dị ứng</option>
          </select>
        </FormField>
        {form.allergy_status === "present" && (
          <FormField label="Mô tả dị ứng">
            <textarea
              className="kinput"
              rows={3}
              value={form.medical_allergies}
              onChange={(e) => setForm({ ...form, medical_allergies: e.target.value })}
              placeholder="VD: Dị ứng đậu phộng..."
            />
          </FormField>
        )}
        <FormField label="Lưu ý chăm sóc">
          <textarea
            className="kinput"
            rows={3}
            value={form.care_notes}
            onChange={(e) => setForm({ ...form, care_notes: e.target.value })}
            placeholder="VD: Tránh nắng, không cho ăn đồ ngọt..."
          />
        </FormField>
        <FormField label="Trạng thái">
          <select
            className="kinput"
            value={form.status}
            onChange={(e) => setForm({ ...form, status: e.target.value })}
          >
            <option value="enrolled">Đang học</option>
            <option value="graduated">Đã tốt nghiệp</option>
            <option value="withdrawn">Thôi học</option>
          </select>
        </FormField>
      </Drawer>

      {duplicateAlert && (
        <Modal
          open={!!duplicateAlert}
          onClose={() => setDuplicateAlert(null)}
          title={`⚠️ Cảnh báo: Trùng họ tên trong lớp (${duplicateAlert.totalDuplicates} học sinh)`}
          size={duplicateAlert.totalDuplicates > 2 ? "xl" : "lg"}
          footer={
            <div className="flex flex-wrap items-center justify-between w-full gap-2">
              <button
                type="button"
                onClick={() => setDuplicateAlert(null)}
                className="kbtn kbtn-secondary text-xs"
              >
                Quay lại chỉnh sửa
              </button>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => confirmSaveStudent(duplicateAlert.payload, false)}
                  className="kbtn kbtn-secondary text-xs text-ink-soft hover:text-ink"
                  title="Lưu mà không thêm hậu tố biệt danh"
                >
                  Giữ nguyên tên gốc
                </button>
                <button
                  type="button"
                  onClick={() => confirmSaveStudent(duplicateAlert.payload, true)}
                  className="kbtn kbtn-primary text-xs flex items-center gap-1.5 font-bold"
                >
                  <span>✓</span>
                  <span>Áp dụng biệt danh &amp; Lưu</span>
                </button>
              </div>
            </div>
          }
        >
          <div className="space-y-4 text-xs">
            {/* Notification alert banner */}
            <div className="p-3.5 rounded-control bg-warn/15 border border-warn/30 space-y-1">
              <div className="font-bold text-ink text-sm flex items-center gap-2">
                <span className="text-base">⚠️</span>
                <span>
                  Phát hiện {duplicateAlert.totalDuplicates} học sinh trùng cả họ tên và biệt danh trong lớp{" "}
                  <strong className="text-brand-strong">{duplicateAlert.targetClassName}</strong>
                </span>
              </div>
              <p className="text-ink-soft leading-relaxed">
                {duplicateAlert.totalDuplicates === 2
                  ? "Có 2 học sinh trùng nhau, hệ thống đề xuất gắn hậu tố (Lớn) và (Nhỏ) dựa theo ngày sinh để phân biệt. Bạn có thể điều chỉnh lại biệt danh ở các ô bên dưới."
                  : `Có ${duplicateAlert.totalDuplicates} học sinh trùng nhau (từ 3 bé trở lên), hệ thống tự động sắp xếp theo độ tuổi từ lớn đến nhỏ và đề xuất đánh số thứ tự (1), (2), (3)... Bạn có thể chỉnh sửa lại trực tiếp ở các ô bên dưới trước khi lưu.`}
              </p>
            </div>

            {/* Cards list for all matching kids */}
            <div
              className={`grid gap-3 ${
                duplicateAlert.totalDuplicates === 2
                  ? "grid-cols-1 md:grid-cols-2"
                  : duplicateAlert.totalDuplicates === 3
                  ? "grid-cols-1 md:grid-cols-3"
                  : "grid-cols-1 md:grid-cols-2"
              }`}
            >
              {duplicateAlert.items.map((item, idx) => (
                <div
                  key={idx}
                  className={`border rounded-card p-3.5 space-y-2.5 transition-all ${
                    item.isNew
                      ? "border-2 border-brand/50 bg-brand/5 shadow-sm"
                      : "border-line bg-sunken/30"
                  }`}
                >
                  <div className="flex items-center justify-between gap-1">
                    <span
                      className={`font-bold text-xs ${
                        item.isNew ? "text-brand-strong" : "text-ink"
                      }`}
                    >
                      {item.isNew
                        ? duplicateAlert.editingChildId
                          ? "Bé cập nhật / chuyển lớp"
                          : "Bé mới thêm"
                        : `Bé ${idx + 1} trong lớp`}
                    </span>
                    <Pill tone={item.isNew ? "brand" : idx === 0 ? "ok" : "info"}>
                      {item.rankLabel}
                    </Pill>
                  </div>

                  <div className="space-y-1.5 text-ink-soft">
                    <div className="flex justify-between">
                      <span>Họ và tên:</span>
                      <strong className="text-ink">{item.full_name}</strong>
                    </div>
                    <div className="flex justify-between">
                      <span>Ngày sinh:</span>
                      <span className="text-ink font-medium">
                        {item.ageInfo.formattedDob}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span>Tuổi &amp; Năm sinh:</span>
                      <span className="text-ink font-bold">
                        {item.ageInfo.years} tuổi
                        {item.ageInfo.months > 0 && ` (${item.ageInfo.months} tháng)`}
                        {item.ageInfo.birthYear !== "—" && ` · Năm ${item.ageInfo.birthYear}`}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span>Biệt danh hiện tại:</span>
                      <span>{item.current_nickname}</span>
                    </div>
                  </div>

                  <div
                    className={`pt-2 border-t space-y-1 ${
                      item.isNew ? "border-brand/20" : "border-line"
                    }`}
                  >
                    <label
                      className={`font-bold block text-[11px] ${
                        item.isNew ? "text-brand-strong" : "text-ink"
                      }`}
                    >
                      {item.isNew ? "Biệt danh sẽ gán:" : "Biệt danh cập nhật:"}
                    </label>
                    <input
                      type="text"
                      className={`kinput font-bold ${
                        item.isNew
                          ? "text-brand-strong bg-white border-brand/40"
                          : "text-ink"
                      }`}
                      value={item.custom_nickname}
                      onChange={(e) => {
                        const val = e.target.value;
                        setDuplicateAlert((prev) => {
                          if (!prev) return null;
                          const newItems = [...prev.items];
                          newItems[idx] = { ...newItems[idx], custom_nickname: val };
                          return { ...prev, items: newItems };
                        });
                      }}
                      placeholder={item.suggested_nickname}
                    />
                    <div className="text-[11px] text-ink-faint flex items-center justify-between">
                      <span>Gợi ý: <strong>{item.suggested_nickname}</strong></span>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="p-3 bg-sunken/60 rounded-control text-ink-soft text-[11px] leading-relaxed">
              💡 <strong>Lưu ý:</strong> Khi bấm &quot;Áp dụng biệt danh &amp; Lưu&quot;, hệ thống sẽ tự động cập nhật biệt danh cho cả {duplicateAlert.totalDuplicates} học sinh để phụ huynh và giáo viên dễ dàng theo dõi trên danh sách lớp, sổ bé ngoan và điểm danh.
            </div>
          </div>
        </Modal>
      )}

      <ConfirmDialog
        open={!!confirmDel}
        title="Xóa học sinh?"
        message={`Bạn có chắc muốn xóa "${confirmDel?.full_name}"? Toàn bộ liên kết phụ huynh sẽ bị xóa.`}
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      <ConfirmDialog
        open={confirmBulkDel}
        title={`Xóa ${selectedIds.length} học sinh đã chọn?`}
        message={`Bạn có chắc muốn xóa vĩnh viễn ${selectedIds.length} học sinh này? Toàn bộ hồ sơ sức khỏe và dữ liệu liên quan sẽ được xóa bỏ.`}
        confirmLabel={bulkDeleting ? "Đang xóa..." : `Xóa ${selectedIds.length} học sinh`}
        onConfirm={handleBulkDelete}
        onCancel={() => !bulkDeleting && setConfirmBulkDel(false)}
      />

      <ImportModal
        open={importOpen}
        onClose={() => setImportOpen(false)}
        title="Nhập danh sách học sinh từ file"
        description="Tải lên file Excel (.xlsx, .xls) hoặc CSV. Hệ thống hỗ trợ đọc cùng lúc nhiều sheet (chia theo từng lớp), tự động nhận diện lớp theo tên sheet và tự động liên kết với phụ huynh theo số điện thoại."
        templateFilename="mau_nhap_hoc_sinh.xlsx"
        sampleHeaders={[
          "Họ và tên",
          "Biệt danh",
          "Tên lớp",
          "Ngày sinh (DD/MM/YYYY)",
          "Giới tính (Nam/Nữ)",
          "SĐT phụ huynh",
          "Ghi chú / Dị ứng",
        ]}
        sampleRow={[
          "Nguyễn Bảo An",
          "Bống",
          classes[0]?.name || "Lớp Mầm 1",
          "15/05/2021",
          "Nữ",
          "0912345678",
          "Dị ứng hải sản",
        ]}
        onImportRows={handleImportRows}
        onSuccess={() => {
          setToast({ msg: "Đã nhập danh sách học sinh thành công", tone: "ok" });
        }}
      />

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}

function formatDate(iso: string | null | undefined): string {
  // iso yyyy-mm-dd hoặc yyyy-mm-ddThh:mm:ss → dd/mm/yyyy
  if (!iso) return "—";
  const datePart = iso.split("T")[0];
  const parts = datePart.split("-");
  if (parts.length === 3) {
    const [y, m, d] = parts;
    return `${d.padStart(2, "0")}/${m.padStart(2, "0")}/${y}`;
  }
  return iso;
}