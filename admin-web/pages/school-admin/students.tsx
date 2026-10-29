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
  ClassFilterSelect,
  ImportModal,
  ImportResult,
  DateInput,
  todayIsoStr,
} from "@/components/ui-school";
import { clearToken, getStoredSchoolAdmin, getToken } from "@/lib/api";
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

interface DuplicateStudentAlert {
  existingChild: Child;
  targetClassName: string;
  suggestedNewNickname: string;
  suggestedExistingNickname: string;
  customNewNickname: string;
  customExistingNickname: string;
  isNewOlder: boolean;
  isSameAge: boolean;
  ageInfoNew: AgeDetail;
  ageInfoExisting: AgeDetail;
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
    { refreshInterval: 30000 },
  );

  useEffect(() => {
    if (childrenError && (childrenError as any).status === 401) {
      clearToken("schoolAdmin");
      window.location.href = "/login";
    }
  }, [childrenError]);

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

      // Phát hiện trùng họ tên trong cùng lớp học
      if (matchedClassId) {
        const existingMatch = workingChildren.find(
          (c) =>
            c.class_id === matchedClassId &&
            c.full_name.trim().toLowerCase() === fullName.toLowerCase()
        );

        if (existingMatch) {
          const cmp = compareAges(isoDob, existingMatch.date_of_birth);
          const baseNewNick = cleanNickname(nickname, fullName);
          const baseExistNick = cleanNickname(existingMatch.nickname, existingMatch.full_name);

          let newSuffix = "(Nhỏ)";
          let existSuffix = "(Lớn)";
          if (cmp < 0) {
            newSuffix = "(Lớn)";
            existSuffix = "(Nhỏ)";
          } else if (cmp > 0) {
            newSuffix = "(Nhỏ)";
            existSuffix = "(Lớn)";
          } else {
            newSuffix = "(1)";
            existSuffix = "(2)";
          }

          nickname = `${baseNewNick} ${newSuffix}`.trim();
          const updatedExistNick = `${baseExistNick} ${existSuffix}`.trim();

          // Cập nhật biệt danh bé cũ nếu bé đó đã có ID trên DB
          if (existingMatch.id) {
            try {
              await updateChild(existingMatch.id, {
                nickname: updatedExistNick,
              });
              existingMatch.nickname = updatedExistNick;
            } catch (e) {
              console.error("Lỗi cập nhật biệt danh bé cũ:", e);
            }
          }

          const targetClass = classes.find((cl) => cl.id === matchedClassId);
          const targetClassName = targetClass ? targetClass.name : "lớp";
          const ageNew = getAgeDetail(isoDob);
          const ageExist = getAgeDetail(existingMatch.date_of_birth);

          warnings.push(
            `Dòng ${i + 1} (${fullName}): Trùng tên trong lớp "${targetClassName}". Tự động tính tuổi theo năm & ngày sinh để gán biệt danh: bé sinh trước (${cmp <= 0 ? nickname : updatedExistNick} - sinh ${cmp <= 0 ? ageNew.formattedDob : ageExist.formattedDob}${cmp <= 0 ? (ageNew.birthYear !== "—" ? `, năm ${ageNew.birthYear}` : "") : (ageExist.birthYear !== "—" ? `, năm ${ageExist.birthYear}` : "")} · ${cmp <= 0 ? ageNew.years : ageExist.years} tuổi) và bé sinh sau (${cmp > 0 ? nickname : updatedExistNick} - sinh ${cmp > 0 ? ageNew.formattedDob : ageExist.formattedDob}${cmp > 0 ? (ageNew.birthYear !== "—" ? `, năm ${ageNew.birthYear}` : "") : (ageExist.birthYear !== "—" ? `, năm ${ageExist.birthYear}` : "")} · ${cmp > 0 ? ageNew.years : ageExist.years} tuổi).`
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
      const today = new Date().toISOString().split("T")[0];
      if (form.date_of_birth > today) {
        setToast({
          msg: "Ngày sinh không thể là ngày trong tương lai",
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
      // Cảnh báo trùng họ tên trong cùng một lớp (áp dụng cho cả tạo mới lẫn sửa đổi/chuyển lớp)
      if (form.class_id) {
        const trimmedName = form.full_name.trim().toLowerCase();
        const existingMatch = (children || []).find(
          (c) =>
            c.id !== (editing?.id ?? "") &&
            c.class_id === form.class_id &&
            c.full_name.trim().toLowerCase() === trimmedName
        );

        if (existingMatch) {
          setSaving(false);
          const cmp = compareAges(form.date_of_birth, existingMatch.date_of_birth);
          const baseNewNick = cleanNickname(form.nickname, form.full_name);
          const baseExistNick = cleanNickname(existingMatch.nickname, existingMatch.full_name);

          let newSuffix = "(Nhỏ)";
          let existSuffix = "(Lớn)";

          if (cmp < 0) {
            newSuffix = "(Lớn)";
            existSuffix = "(Nhỏ)";
          } else if (cmp > 0) {
            newSuffix = "(Nhỏ)";
            existSuffix = "(Lớn)";
          } else {
            newSuffix = "(1)";
            existSuffix = "(2)";
          }

          const suggestedNew = `${baseNewNick} ${newSuffix}`.trim();
          const suggestedExisting = `${baseExistNick} ${existSuffix}`.trim();
          const targetClassName = classes.find((cl) => cl.id === form.class_id)?.name || "lớp";
          const ageNew = getAgeDetail(form.date_of_birth);
          const ageExist = getAgeDetail(existingMatch.date_of_birth);

          setDuplicateAlert({
            existingChild: existingMatch,
            targetClassName,
            suggestedNewNickname: suggestedNew,
            suggestedExistingNickname: suggestedExisting,
            customNewNickname: suggestedNew,
            customExistingNickname: suggestedExisting,
            isNewOlder: cmp < 0,
            isSameAge: cmp === 0,
            ageInfoNew: ageNew,
            ageInfoExisting: ageExist,
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
        payload.nickname = alertData.customNewNickname.trim() || alertData.suggestedNewNickname;
        // Cập nhật biệt danh phân biệt cho bé cũ trong lớp
        const existNick = alertData.customExistingNickname.trim() || alertData.suggestedExistingNickname;
        try {
          await updateChild(alertData.existingChild.id, {
            nickname: existNick,
          });
        } catch (e) {
          console.error("Lỗi cập nhật biệt danh bé cũ:", e);
        }
      }

      if (alertData.editingChildId) {
        await updateChild(alertData.editingChildId, payload);
        setToast({
          msg: applyNicknames
            ? `Đã cập nhật học sinh "${payload.full_name}" (${payload.nickname}) và cập nhật bé trong lớp (${alertData.customExistingNickname.trim() || alertData.suggestedExistingNickname})`
            : `Đã cập nhật học sinh "${payload.full_name}"`,
          tone: "ok",
        });
      } else {
        await createChild(payload);
        setToast({
          msg: applyNicknames
            ? `Đã thêm học sinh "${payload.full_name}" (${payload.nickname}) và cập nhật bé cũ (${alertData.customExistingNickname.trim() || alertData.suggestedExistingNickname})`
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
      active="features"
      pageTitle="Quản lý học sinh"
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
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Nhập dữ liệu từ file Excel / CSV"
          >
            📤 Nhập file
          </button>
          <button onClick={openCreate} className="kbtn kbtn-primary">
            + Thêm học sinh
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3 flex flex-col sm:flex-row gap-2.5 items-stretch sm:items-center">
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

      {selectedIds.length > 0 && (
        <div
          className="card p-3 mb-3 flex items-center justify-between gap-3 border"
          style={{ background: "#FDF8F6", borderColor: "#F2D5CE" }}
        >
          <div className="flex items-center gap-2.5 text-sm font-semibold text-ink">
            <span
              className="w-6 h-6 rounded-full flex items-center justify-center text-xs text-white font-bold"
              style={{ background: "#BB4A34" }}
            >
              {selectedIds.length}
            </span>
            <span>Đã chọn {selectedIds.length} học sinh</span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setSelectedIds([])}
              className="kbtn kbtn-secondary text-xs"
              disabled={bulkDeleting}
            >
              Bỏ chọn
            </button>
            <button
              onClick={() => setConfirmBulkDel(true)}
              className="kbtn text-xs text-white font-medium flex items-center gap-1.5"
              style={{ background: "#BB4A34" }}
              disabled={bulkDeleting}
            >
              <span>🗑️</span>
              <span>Xóa đã chọn ({selectedIds.length})</span>
            </button>
          </div>
        </div>
      )}

      <div className="card overflow-hidden">
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
                className="text-xs uppercase tracking-wider"
                style={{ background: "#EFECE5", color: "#605D57" }}
              >
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
              </thead>
              <tbody>
                {filtered.map((c, idx) => {
                  const isSelected = selectedIds.includes(c.id);
                  return (
                  <tr
                    key={c.id}
                    className={`${idx > 0 ? "border-t border-line" : ""} ${
                      isSelected ? "bg-[#FDF8F6]" : ""
                    }`}
                  >
                    <td className="px-3 py-3 text-center">
                      <input
                        type="checkbox"
                        className="rounded cursor-pointer"
                        checked={isSelected}
                        onChange={() => toggleSelect(c.id)}
                      />
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2.5">
                        <div
                          className="w-9 h-9 flex items-center justify-center rounded-full text-white font-bold"
                          style={{ background: "#8A5E12" }}
                        >
                          {c.full_name.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-bold text-ink">{c.full_name}</div>
                          {c.nickname && (
                            <div className="text-xs text-ink-soft">
                              Biệt danh: {c.nickname}
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Pill tone="warn">{c.class_name}</Pill>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-ink line-clamp-1">
                        {c.parents_summary || "Chưa liên kết"}
                      </div>
                      {c.parent_phone && (
                        <div className="text-xs text-ink-soft">{c.parent_phone}</div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-ink-soft">
                      {c.date_of_birth ? formatDate(c.date_of_birth) : "—"}
                    </td>
                    <td className="px-4 py-3 text-ink-soft max-w-xs">
                      <div className="line-clamp-1">{c.note || "—"}</div>
                      {c.care_notes && (
                        <div className="text-xs mt-0.5 line-clamp-2">
                          Lưu ý: {c.care_notes}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => openEdit(c)}
                        className="kbtn kbtn-ghost text-xs"
                      >
                        Sửa
                      </button>
                      <button
                        onClick={() => setConfirmDel(c)}
                        className="kbtn kbtn-ghost text-xs text-bad"
                      >
                        Xóa
                      </button>
                    </td>
                  </tr>
                );
              })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="text-xs text-ink-faint mt-2">
        Tổng: <span className="font-bold text-ink">{filtered.length}</span> học sinh
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
            onInvalid={(msg) => setToast({ msg, tone: "warn" })}
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
          title="⚠️ Cảnh báo: Trùng họ tên trong lớp"
          size="lg"
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
                  title="Lưu mà không thêm hậu tố (Lớn / Nhỏ)"
                >
                  Giữ nguyên tên gốc
                </button>
                <button
                  type="button"
                  onClick={() => confirmSaveStudent(duplicateAlert.payload, true)}
                  className="kbtn kbtn-primary text-xs flex items-center gap-1.5 font-bold"
                >
                  <span>✓</span>
                  <span>Áp dụng biệt danh & Lưu</span>
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
                  Phát hiện học sinh trùng họ tên trong lớp{" "}
                  <strong className="text-brand-strong">{duplicateAlert.targetClassName}</strong>
                </span>
              </div>
              <p className="text-ink-soft leading-relaxed">
                {duplicateAlert.editingChildId
                  ? `Khi chuyển hoặc cập nhật học sinh "${duplicateAlert.payload.full_name}" vào lớp "${duplicateAlert.targetClassName}", phát hiện trùng hoàn toàn họ và tên với một học sinh đã có sẵn trong lớp này.`
                  : `Học sinh mới "${duplicateAlert.payload.full_name}" trùng hoàn toàn họ và tên với một học sinh đã có sẵn trong lớp "${duplicateAlert.targetClassName}".`}
                {" "}Hệ thống đã tự động tính tuổi theo cả năm, tháng và ngày sinh để đề xuất biệt danh phân biệt <strong>(Lớn)</strong> và <strong>(Nhỏ)</strong> giúp giáo viên không bị nhầm lẫn khi điểm danh và theo dõi.
              </p>
            </div>

            {/* Comparison cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {/* Existing Child */}
              <div className="border border-line rounded-card p-3.5 bg-sunken/30 space-y-2.5">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-ink">Bé đã có trong lớp</span>
                  <Pill tone={duplicateAlert.isNewOlder ? "info" : "ok"}>
                    {duplicateAlert.isSameAge
                      ? "Cùng tuổi"
                      : duplicateAlert.isNewOlder
                      ? "Sinh sau · Nhỏ hơn"
                      : "Sinh trước · Lớn hơn"}
                  </Pill>
                </div>

                <div className="space-y-1.5 text-ink-soft">
                  <div className="flex justify-between">
                    <span>Họ và tên:</span>
                    <strong className="text-ink">{duplicateAlert.existingChild.full_name}</strong>
                  </div>
                  <div className="flex justify-between">
                    <span>Ngày sinh:</span>
                    <span className="text-ink font-medium">
                      {duplicateAlert.ageInfoExisting.formattedDob}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Tuổi &amp; Năm sinh:</span>
                    <span className="text-ink font-bold">
                      {duplicateAlert.ageInfoExisting.years} tuổi
                      {duplicateAlert.ageInfoExisting.months > 0 && ` (${duplicateAlert.ageInfoExisting.months} tháng)`}
                      {duplicateAlert.ageInfoExisting.birthYear !== "—" && ` · Năm ${duplicateAlert.ageInfoExisting.birthYear}`}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Biệt danh hiện tại:</span>
                    <span>{duplicateAlert.existingChild.nickname || "(Chưa có)"}</span>
                  </div>
                </div>

                <div className="pt-2 border-t border-line space-y-1">
                  <label className="font-bold text-ink block text-[11px]">
                    Biệt danh cập nhật:
                  </label>
                  <input
                    type="text"
                    className="kinput font-bold text-brand-strong"
                    value={duplicateAlert.customExistingNickname}
                    onChange={(e) =>
                      setDuplicateAlert({
                        ...duplicateAlert,
                        customExistingNickname: e.target.value,
                      })
                    }
                    placeholder="VD: Bống (Lớn)"
                  />
                  <div className="text-[11px] text-ink-faint">
                    Gợi ý: {duplicateAlert.suggestedExistingNickname}
                  </div>
                </div>
              </div>

              {/* New Child / Edited Child */}
              <div className="border-2 border-brand/40 rounded-card p-3.5 bg-brand/5 space-y-2.5">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-brand-strong">
                    {duplicateAlert.editingChildId ? "Bé chuyển lớp / cập nhật" : "Bé mới thêm"}
                  </span>
                  <Pill tone={duplicateAlert.isNewOlder ? "ok" : "info"}>
                    {duplicateAlert.isSameAge
                      ? "Cùng tuổi"
                      : duplicateAlert.isNewOlder
                      ? "Sinh trước · Lớn hơn"
                      : "Sinh sau · Nhỏ hơn"}
                  </Pill>
                </div>

                <div className="space-y-1.5 text-ink-soft">
                  <div className="flex justify-between">
                    <span>Họ và tên:</span>
                    <strong className="text-ink">{duplicateAlert.payload.full_name}</strong>
                  </div>
                  <div className="flex justify-between">
                    <span>Ngày sinh:</span>
                    <span className="text-ink font-medium">
                      {duplicateAlert.ageInfoNew.formattedDob}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Tuổi &amp; Năm sinh:</span>
                    <span className="text-ink font-bold">
                      {duplicateAlert.ageInfoNew.years} tuổi
                      {duplicateAlert.ageInfoNew.months > 0 && ` (${duplicateAlert.ageInfoNew.months} tháng)`}
                      {duplicateAlert.ageInfoNew.birthYear !== "—" && ` · Năm ${duplicateAlert.ageInfoNew.birthYear}`}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>{duplicateAlert.editingChildId ? "Biệt danh hiện tại:" : "Biệt danh nhập:"}</span>
                    <span>{duplicateAlert.payload.nickname || "(Chưa có)"}</span>
                  </div>
                </div>

                <div className="pt-2 border-t border-brand/20 space-y-1">
                  <label className="font-bold text-brand-strong block text-[11px]">
                    Biệt danh sẽ gán:
                  </label>
                  <input
                    type="text"
                    className="kinput font-bold text-brand-strong bg-white"
                    value={duplicateAlert.customNewNickname}
                    onChange={(e) =>
                      setDuplicateAlert({
                        ...duplicateAlert,
                        customNewNickname: e.target.value,
                      })
                    }
                    placeholder="VD: Bống (Nhỏ)"
                  />
                  <div className="text-[11px] text-ink-faint">
                    Gợi ý: {duplicateAlert.suggestedNewNickname}
                  </div>
                </div>
              </div>
            </div>

            <div className="p-3 bg-sunken/60 rounded-control text-ink-soft text-[11px] leading-relaxed">
              💡 <strong>Lưu ý:</strong> Khi bấm &quot;Áp dụng biệt danh &amp; Lưu&quot;, hệ thống sẽ tự động cập nhật biệt danh cho cả 2 học sinh để phụ huynh và giáo viên dễ dàng theo dõi trên danh sách lớp, sổ bé ngoan và điểm danh.
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