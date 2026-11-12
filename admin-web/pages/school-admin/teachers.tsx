/**
 * pages/school-admin/teachers.tsx
 * ===============================
 * CRUD giáo viên — UI y hệt Flutter app:
 *   - Search bar + nút Thêm/Làm mới.
 *   - Bảng danh sách (desktop) / Cards (mobile).
 *   - Drawer chỉnh sửa với các trường: Họ tên, Email, SĐT, Lớp, Username, Password.
 */

import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import {
  Drawer,
  FormField,
  Pill,
  SearchBar,
  Spinner,
  ConfirmDialog,
  Toast,
  ClassFilterSelect,
  ImportModal,
  ImportResult,
} from "@/components/ui-school";
import { clearToken, getStoredSchoolAdmin, getToken } from "@/lib/api";
import { exportToExcel } from "@/lib/excel-helper";
import {
  Teacher,
  TeacherPayload,
  SchoolClass,
  createTeacher,
  deleteTeacher,
  deleteTeachersBatch,
  getClasses,
  getTeachers,
  updateTeacher,
} from "@/lib/admin-api";

interface TeacherFormState {
  full_name: string;
  email: string;
  phone: string;
  class_id: string | null;
  class_ids: string[];
  username: string;
  password: string;
  status: string;
}

const EMPTY_FORM: TeacherFormState = {
  full_name: "",
  email: "",
  phone: "",
  class_id: null,
  class_ids: [],
  username: "",
  password: "",
  status: "active",
};

interface TeacherRowEditState {
  full_name: string;
  email: string;
  phone: string;
  class_ids: string[];
  username: string;
  status: string;
}

interface ClassDropdownAnchor {
  teacherId: string;
  top?: number;
  bottom?: number;
  left: number;
  minWidth: number;
}

function getOriginalClassIds(t: Teacher): string[] {
  if (Array.isArray(t.class_ids) && t.class_ids.length > 0) {
    return Array.from(new Set(t.class_ids));
  }
  if (Array.isArray(t.classes) && t.classes.length > 0) {
    return Array.from(new Set(t.classes.map((c) => c.id)));
  }
  return t.class_id ? [t.class_id] : [];
}

function buildInitialRowEdit(t: Teacher): TeacherRowEditState {
  return {
    full_name: t.full_name || "",
    email: t.email || "",
    phone: t.phone || "",
    class_ids: getOriginalClassIds(t),
    username: t.username || "",
    status: t.status || "active",
  };
}

function isTeacherCellDirty(
  t: Teacher,
  edit: TeacherRowEditState | undefined,
  field: keyof TeacherRowEditState,
): boolean {
  if (!edit) return false;
  if (field === "full_name") return edit.full_name.trim() !== (t.full_name || "").trim();
  if (field === "email") return edit.email.trim() !== (t.email || "").trim();
  if (field === "phone") return edit.phone.trim() !== (t.phone || "").trim();
  if (field === "username") return edit.username.trim() !== (t.username || "").trim();
  if (field === "status") return edit.status !== (t.status || "active");
  if (field === "class_ids") {
    const origIds = getOriginalClassIds(t);
    const curIds = edit.class_ids;
    if (origIds.length !== curIds.length) return true;
    const origSet = new Set(origIds);
    return curIds.some((id) => !origSet.has(id));
  }
  return false;
}

function isTeacherRowDirty(
  t: Teacher,
  edit: TeacherRowEditState | undefined,
): boolean {
  if (!edit) return false;
  return (
    isTeacherCellDirty(t, edit, "full_name") ||
    isTeacherCellDirty(t, edit, "email") ||
    isTeacherCellDirty(t, edit, "phone") ||
    isTeacherCellDirty(t, edit, "class_ids") ||
    isTeacherCellDirty(t, edit, "username") ||
    isTeacherCellDirty(t, edit, "status")
  );
}

export default function SchoolAdminTeachersPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [selectedClassId, setSelectedClassId] = useState("");
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [isEditingTable, setIsEditingTable] = useState(false);
  const [tableEdits, setTableEdits] = useState<Record<string, TeacherRowEditState>>({});
  const [savingTable, setSavingTable] = useState(false);
  const [openClassDropdown, setOpenClassDropdown] = useState<ClassDropdownAnchor | null>(null);
  const [classSearchQuery, setClassSearchQuery] = useState("");
  const classDropdownRef = useRef<HTMLDivElement | null>(null);
  const [editing, setEditing] = useState<Teacher | null>(null);
  const [form, setForm] = useState<TeacherFormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Teacher | null>(null);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [confirmBulkDel, setConfirmBulkDel] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "brand" | "warn" } | null>(null);

  useEffect(() => {
    if (!getToken() || !getStoredSchoolAdmin()) {
      window.location.href = "/login";
      return;
    }
    setReady(true);
    getClasses()
      .then(setClasses)
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (!openClassDropdown) return;
    const handleScrollOrResize = (e: Event) => {
      if (
        e.type === "scroll" &&
        classDropdownRef.current &&
        e.target instanceof Node &&
        classDropdownRef.current.contains(e.target)
      ) {
        return;
      }
      setOpenClassDropdown(null);
    };
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpenClassDropdown(null);
      }
    };
    window.addEventListener("scroll", handleScrollOrResize, true);
    window.addEventListener("resize", handleScrollOrResize);
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("scroll", handleScrollOrResize, true);
      window.removeEventListener("resize", handleScrollOrResize);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [openClassDropdown]);

  const { data: teachers, error: teachersError, mutate } = useSWR<Teacher[]>(
    ready ? "teachers" : null,
    () => getTeachers(),
    {
      refreshInterval: drawerOpen || importOpen || isEditingTable ? 0 : 30000,
      revalidateOnFocus: !(drawerOpen || importOpen || isEditingTable),
    },
  );

  useEffect(() => {
    if (teachersError && (teachersError as any).status === 401) {
      clearToken("schoolAdmin");
      window.location.href = "/login";
    }
  }, [teachersError]);

  const filtered = useMemo(() => {
    let list = teachers ?? [];
    if (selectedClassId) {
      list = list.filter((t) => {
        if (t.class_ids && t.class_ids.includes(selectedClassId)) return true;
        if (t.class_id === selectedClassId) return true;
        if (t.classes && t.classes.some((c) => c.id === selectedClassId)) return true;
        return false;
      });
    }
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter(
      (t) =>
        t.full_name.toLowerCase().includes(q) ||
        t.email.toLowerCase().includes(q) ||
        t.phone.toLowerCase().includes(q) ||
        (t.class_name || "").toLowerCase().includes(q),
    );
  }, [teachers, query, selectedClassId]);

  function handleExportExcel() {
    if (!filtered || filtered.length === 0) {
      setToast({ msg: "Không có dữ liệu giáo viên để xuất", tone: "warn" });
      return;
    }
    const headers = [
      "Họ và tên",
      "Email",
      "Số điện thoại",
      "Lớp phụ trách",
      "Tên đăng nhập",
      "Trạng thái",
    ];
    const rows = filtered.map((t) => [
      t.full_name,
      t.email,
      t.phone,
      t.classes && t.classes.length > 0
        ? t.classes.map((c) => c.name).join(", ")
        : t.class_name || "Chưa phân lớp",
      t.username || "",
      t.status === "active" ? "Đang hoạt động" : "Ngừng",
    ]);
    const currentClass = classes.find((c) => c.id === selectedClassId);
    const filename = currentClass
      ? `danh_sach_giao_vien_${currentClass.name.replace(/\s+/g, "_")}.xlsx`
      : "danh_sach_giao_vien.xlsx";
    exportToExcel(filename, "GiaoVien", headers, rows);
    setToast({ msg: `Đã xuất ${rows.length} giáo viên ra file Excel`, tone: "ok" });
  }

  async function handleImportRows(rows: string[][]): Promise<ImportResult> {
    let success = 0;
    let failed = 0;
    const errors: string[] = [];

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const fullName = row[0]?.trim();
      const email = row[1]?.trim();
      const phone = row[2]?.trim();
      const classNameOrId = row[3]?.trim();
      const username = row[4]?.trim() || phone || email;
      const password = row[5]?.trim() || "123456";

      if (!fullName || !email || !phone) {
        failed++;
        errors.push(`Dòng ${i + 1}: Thiếu họ tên, email hoặc số điện thoại.`);
        continue;
      }
      if (!/^0\d{9}$/.test(phone)) {
        failed++;
        errors.push(`Dòng ${i + 1} (${fullName}): Số điện thoại phải gồm 10 số.`);
        continue;
      }

      let matchedClassIds: string[] = [];
      if (classNameOrId) {
        const found = classes.find(
          (c) =>
            c.id === classNameOrId ||
            c.name.toLowerCase() === classNameOrId.toLowerCase()
        );
        if (found) {
          matchedClassIds = [found.id];
        }
      }

      try {
        await createTeacher({
          full_name: fullName,
          email,
          phone,
          class_ids: matchedClassIds,
          username,
          password,
          status: "active",
        });
        success++;
      } catch (err: any) {
        failed++;
        errors.push(`Dòng ${i + 1} (${fullName}): ${err?.message || "Lỗi tạo giáo viên"}`);
      }
    }

    if (success > 0) {
      mutate();
    }
    return { total: rows.length, success, failed, errors };
  }

  const dirtyRows = useMemo(() => {
    return (teachers ?? []).filter((t) => isTeacherRowDirty(t, tableEdits[t.id]));
  }, [teachers, tableEdits]);

  const activeDropdownTeacher = useMemo(() => {
    if (!openClassDropdown) return null;
    return (teachers ?? []).find((t) => t.id === openClassDropdown.teacherId) ?? null;
  }, [openClassDropdown, teachers]);

  function getRowData(t: Teacher): TeacherRowEditState {
    return tableEdits[t.id] ?? buildInitialRowEdit(t);
  }

  function startTableEditing() {
    setTableEdits({});
    setOpenClassDropdown(null);
    setIsEditingTable(true);
  }

  function cancelTableEditing() {
    const hadChanges = dirtyRows.length > 0;
    setIsEditingTable(false);
    setTableEdits({});
    setOpenClassDropdown(null);
    if (hadChanges) {
      setToast({ msg: "Đã hủy bỏ mọi thay đổi chưa lưu", tone: "brand" });
    }
  }

  function updateRowEdit<K extends keyof TeacherRowEditState>(
    t: Teacher,
    field: K,
    val: TeacherRowEditState[K],
  ) {
    setTableEdits((prev) => {
      const current = prev[t.id] ?? buildInitialRowEdit(t);
      return {
        ...prev,
        [t.id]: {
          ...current,
          [field]: val,
        },
      };
    });
  }

  function toggleRowClassSelection(t: Teacher, classId: string) {
    setTableEdits((prev) => {
      const current = prev[t.id] ?? buildInitialRowEdit(t);
      const exists = current.class_ids.includes(classId);
      const nextIds = exists
        ? current.class_ids.filter((id) => id !== classId)
        : [...current.class_ids, classId];
      return {
        ...prev,
        [t.id]: {
          ...current,
          class_ids: nextIds,
        },
      };
    });
  }

  async function handleSaveTableEdits() {
    if (dirtyRows.length === 0) {
      setToast({ msg: "Không có thay đổi nào để lưu", tone: "brand" });
      setIsEditingTable(false);
      setOpenClassDropdown(null);
      return;
    }

    const changedItems: { id: string; payload: Partial<TeacherPayload> }[] = [];
    for (const t of dirtyRows) {
      const edit = getRowData(t);
      if (!edit.full_name.trim()) {
        setToast({ msg: "Họ tên giáo viên không được để trống", tone: "bad" });
        return;
      }

      const emailDirty = isTeacherCellDirty(t, edit, "email");
      if (emailDirty) {
        if (!edit.email.trim()) {
          setToast({ msg: `Email của ${edit.full_name.trim()} không được để trống`, tone: "bad" });
          return;
        }
        if (!/^[a-zA-Z0-9._%+-]+@gmail\.com$/i.test(edit.email.trim())) {
          setToast({
            msg: `Email của ${edit.full_name.trim()} phải đúng định dạng Gmail (@gmail.com)`,
            tone: "bad",
          });
          return;
        }
      }

      const phoneDirty = isTeacherCellDirty(t, edit, "phone");
      if (phoneDirty) {
        if (!edit.phone.trim()) {
          setToast({
            msg: `Số điện thoại của ${edit.full_name.trim()} không được để trống`,
            tone: "bad",
          });
          return;
        }
        if (!/^0\d{9}$/.test(edit.phone.trim())) {
          setToast({
            msg: `Số điện thoại của ${edit.full_name.trim()} phải gồm 10 chữ số bắt đầu bằng 0`,
            tone: "bad",
          });
          return;
        }
      }

      const usernameDirty = isTeacherCellDirty(t, edit, "username");
      if (usernameDirty && (t.username || "").trim() && !edit.username.trim()) {
        setToast({
          msg: `Tên đăng nhập của ${edit.full_name.trim()} không được để trống`,
          tone: "bad",
        });
        return;
      }

      const payload: Partial<TeacherPayload> = {};
      if (isTeacherCellDirty(t, edit, "full_name")) payload.full_name = edit.full_name.trim();
      if (emailDirty) payload.email = edit.email.trim();
      if (phoneDirty) payload.phone = edit.phone.trim();
      if (isTeacherCellDirty(t, edit, "class_ids")) payload.class_ids = edit.class_ids;
      if (usernameDirty) payload.username = edit.username.trim() || null;
      if (isTeacherCellDirty(t, edit, "status")) payload.status = edit.status;

      changedItems.push({ id: t.id, payload });
    }

    setSavingTable(true);
    let success = 0;
    let failed = 0;
    let firstErrorMsg = "";
    const succeededIds = new Set<string>();

    for (const item of changedItems) {
      try {
        await updateTeacher(item.id, item.payload);
        success++;
        succeededIds.add(item.id);
      } catch (err: unknown) {
        failed++;
        if (!firstErrorMsg) {
          firstErrorMsg =
            err instanceof Error
              ? err.message
              : "Lỗi cập nhật giáo viên";
        }
      }
    }

    setSavingTable(false);
    if (succeededIds.size > 0) {
      setTableEdits((prev) => {
        const next = { ...prev };
        succeededIds.forEach((id) => delete next[id]);
        return next;
      });
      await mutate();
    }

    if (failed === 0) {
      setIsEditingTable(false);
      setOpenClassDropdown(null);
      setToast({ msg: `Đã lưu thành công ${success} giáo viên!`, tone: "ok" });
    } else if (success > 0) {
      setToast({
        msg: `Đã lưu ${success} giáo viên (${failed} giáo viên lỗi: ${firstErrorMsg})`,
        tone: "warn",
      });
    } else {
      setToast({ msg: firstErrorMsg || "Không thể lưu thay đổi", tone: "bad" });
    }
  }

  function openCreate() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setDrawerOpen(true);
  }

  function openEdit(t: Teacher) {
    setEditing(t);
    const origClassIds = getOriginalClassIds(t);
    setForm({
      full_name: t.full_name,
      email: t.email,
      phone: t.phone,
      class_id: origClassIds[0] ?? t.class_id,
      class_ids: origClassIds,
      username: t.username || "",
      password: "",
      status: t.status,
    });
    setDrawerOpen(true);
  }

  async function handleSave() {
    if (!form.full_name.trim() || !form.email.trim() || !form.phone.trim()) {
      setToast({ msg: "Vui lòng điền đầy đủ họ tên, email và số điện thoại", tone: "bad" });
      return;
    }
    if (form.phone && !/^0\d{9}$/.test(form.phone.trim())) {
      setToast({ msg: "Số điện thoại phải gồm 10 chữ số bắt đầu bằng 0", tone: "bad" });
      return;
    }
    if (form.email && !/^[a-zA-Z0-9._%+-]+@gmail\.com$/i.test(form.email.trim())) {
      setToast({ msg: "Email phải đúng định dạng Gmail (@gmail.com)", tone: "bad" });
      return;
    }
    setSaving(true);
    try {
      const payload: TeacherPayload = {
        full_name: form.full_name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        class_ids: form.class_ids,
        username: form.username.trim() || null,
        password: form.password.trim() || null,
        status: form.status,
      };
      if (editing) {
        await updateTeacher(editing.id, payload);
        setTableEdits((prev) => {
          if (!prev[editing.id]) return prev;
          const next = { ...prev };
          delete next[editing.id];
          return next;
        });
        setToast({ msg: "Đã cập nhật giáo viên", tone: "ok" });
      } else {
        await createTeacher(payload);
        setToast({ msg: "Đã tạo giáo viên mới", tone: "ok" });
      }
      setDrawerOpen(false);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể lưu giáo viên", tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(t: Teacher) {
    try {
      await deleteTeacher(t.id);
      setToast({ msg: `Đã xóa giáo viên ${t.full_name}`, tone: "ok" });
      setSelectedIds((prev) => prev.filter((id) => id !== t.id));
      setTableEdits((prev) => {
        if (!prev[t.id]) return prev;
        const next = { ...prev };
        delete next[t.id];
        return next;
      });
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
  }

  const allSelected =
    filtered.length > 0 && filtered.every((t) => selectedIds.includes(t.id));
  const someSelected =
    selectedIds.length > 0 && !allSelected;

  function toggleSelectAll() {
    if (allSelected) {
      setSelectedIds([]);
    } else {
      setSelectedIds(filtered.map((t) => t.id));
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
      const res = await deleteTeachersBatch(selectedIds);
      setToast({
        msg: res.message || `Đã xóa ${selectedIds.length} giáo viên`,
        tone: "ok",
      });
      setTableEdits((prev) => {
        const next = { ...prev };
        let changed = false;
        selectedIds.forEach((id) => {
          if (id in next) {
            delete next[id];
            changed = true;
          }
        });
        return changed ? next : prev;
      });
      setSelectedIds([]);
      mutate();
    } catch (err: any) {
      setToast({
        msg: err?.message || "Không thể xóa hàng loạt giáo viên",
        tone: "bad",
      });
    } finally {
      setBulkDeleting(false);
      setConfirmBulkDel(false);
    }
  }

  function toggleClass(classId: string) {
    setForm((f) => {
      const exists = f.class_ids.includes(classId);
      const next = exists
        ? f.class_ids.filter((x) => x !== classId)
        : [...f.class_ids, classId];
      return { ...f, class_ids: next, class_id: next[0] ?? null };
    });
  }

  if (!ready) return null;

  return (
    <SchoolAdminLayout
      active="teachers"
      pageTitle="Quản lý Giáo viên"
      pageAction={
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => {
              mutate();
              setToast({ msg: "Đã đồng bộ dữ liệu mới nhất", tone: "brand" });
            }}
            className="px-3 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] font-bold text-xs transition"
            title="Làm mới"
            disabled={isEditingTable}
          >
            ↻
          </button>
          <button
            onClick={handleExportExcel}
            className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] font-bold text-xs flex items-center gap-1.5 transition"
            title="Xuất danh sách ra file Excel"
          >
            📥 Xuất Excel
          </button>
          <button
            onClick={() => setImportOpen(true)}
            className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#102737] hover:bg-[#F6F7F8] font-bold text-xs flex items-center gap-1.5 transition"
            title="Nhập dữ liệu từ file Excel / CSV"
            disabled={isEditingTable}
          >
            📤 Nhập file
          </button>
          {!isEditingTable ? (
            <button
              onClick={startTableEditing}
              className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#087F70] hover:bg-[#E6F3EB] font-bold text-xs flex items-center gap-1.5 transition disabled:opacity-50"
              title="Chỉnh sửa trực tiếp tất cả các dòng trên bảng"
              disabled={filtered.length === 0}
            >
              <span>✏️</span>
              <span>Chỉnh sửa bảng</span>
            </button>
          ) : (
            <>
              <button
                onClick={cancelTableEditing}
                disabled={savingTable}
                className="px-4 py-2 rounded-full border border-[#E5E8EB] bg-white text-[#65727D] hover:bg-[#F6F7F8] font-bold text-xs transition"
              >
                ✕ Hủy bỏ
              </button>
              <button
                onClick={handleSaveTableEdits}
                disabled={savingTable}
                className="px-4 py-2 rounded-full bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-xs flex items-center gap-2 shadow-sm transition"
              >
                {savingTable ? (
                  <>
                    <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Đang lưu ({dirtyRows.length})...</span>
                  </>
                ) : (
                  <>
                    <span>💾</span>
                    <span>Lưu thay đổi</span>
                    {dirtyRows.length > 0 && (
                      <span className="bg-white/20 text-white text-[10px] px-1.5 py-0.5 rounded-full font-bold">
                        {dirtyRows.length}
                      </span>
                    )}
                  </>
                )}
              </button>
            </>
          )}
          {!isEditingTable && (
            <button
              onClick={openCreate}
              className="px-4 py-2 rounded-full bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-xs shadow-sm flex items-center gap-1.5 transition"
            >
              + Thêm giáo viên
            </button>
          )}
        </div>
      }
    >
      {/* Search & Class Filter */}
      <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-4 mb-4 shadow-soft flex flex-col sm:flex-row gap-3 items-stretch sm:items-center">
        <div className="flex-1">
          <SearchBar
            value={query}
            onChange={setQuery}
            placeholder="Tìm giáo viên, số điện thoại, lớp..."
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

      {/* Banner thông báo khi đang ở chế độ chỉnh sửa bảng */}
      {isEditingTable && dirtyRows.length > 0 && (
        <div className="mb-3 px-4 py-2.5 bg-amber-50 border border-amber-200 text-amber-900 rounded-lg flex items-center justify-between shadow-sm">
          <div className="flex items-center gap-2 text-xs sm:text-sm">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse shrink-0" />
            <span className="font-semibold">
              Đang có {dirtyRows.length} giáo viên có chỉnh sửa chưa lưu.
            </span>
            <span className="text-xs text-amber-700 hidden sm:inline">
              (Các ô có viền vàng là các trường đã thay đổi)
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={cancelTableEditing}
              disabled={savingTable}
              className="text-xs px-2.5 py-1 text-amber-800 hover:text-bad hover:underline font-medium"
            >
              Hủy bỏ
            </button>
            <button
              onClick={handleSaveTableEdits}
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
        {!teachers && !teachersError ? (
          <Spinner />
        ) : teachersError ? (
          <div className="text-center py-12">
            <div className="text-bad font-semibold mb-2">
              {(teachersError as any)?.status === 401
                ? "Phiên đăng nhập đã hết hạn. Đang chuyển về trang đăng nhập..."
                : `Không thể tải danh sách giáo viên (${(teachersError as any)?.detail || "Vui lòng thử lại"})`}
            </div>
            <button onClick={() => mutate()} className="kbtn kbtn-secondary mt-2">
              Thử lại
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-5xl mb-2">👨‍🏫</div>
              <div className="text-ink font-semibold">Chưa có giáo viên nào</div>
              <div className="text-sm text-ink-soft mt-1">
                {query
                  ? "Không có kết quả phù hợp."
                  : "Bấm \"+ Thêm giáo viên\" để tạo mới."}
              </div>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm table-fixed min-w-[960px]">
                <colgroup>
                  <col className="w-11" />
                  <col className="w-[22%]" />
                  <col />
                  <col className="w-[15%]" />
                  <col className="w-[13%]" />
                  <col className="w-[12%]" />
                  <col className="w-[120px]" />
                </colgroup>
                <thead
                  className="text-xs uppercase tracking-wider transition-colors duration-200"
                  style={{
                    background: selectedIds.length > 0 ? "#FDF8F6" : "#EFECE5",
                    color: selectedIds.length > 0 ? "#BB4A34" : "#605D57",
                  }}
                >
                  {selectedIds.length > 0 ? (
                    <tr className="border-b border-[#F2D5CE]">
                      <th className="px-3 py-2.5 text-center">
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
                            Đã chọn {selectedIds.length} giáo viên
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
                      <th className="px-3 py-3 text-center">
                        <input
                          type="checkbox"
                          className="rounded cursor-pointer"
                          checked={allSelected}
                          ref={(el) => {
                            if (el) el.indeterminate = someSelected;
                          }}
                          onChange={toggleSelectAll}
                          title="Chọn tất cả giáo viên hiển thị"
                        />
                      </th>
                      <th className="px-4 py-3 text-left font-semibold">Họ tên</th>
                      <th className="px-4 py-3 text-left font-semibold">Email / SĐT</th>
                      <th className="px-4 py-3 text-left font-semibold">Lớp phụ trách</th>
                      <th className="px-4 py-3 text-left font-semibold">Tài khoản</th>
                      <th className="px-4 py-3 text-left font-semibold">Trạng thái</th>
                      <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                    </tr>
                  )}
                </thead>
                <tbody>
                  {filtered.map((t, idx) => {
                    const isSelected = selectedIds.includes(t.id);
                    const rowEdit = tableEdits[t.id];
                    const rowData = getRowData(t);
                    const isDirty = isTeacherRowDirty(t, rowEdit);
                    const selectedClassObjs = rowData.class_ids.map((cid) => {
                      const found =
                        classes.find((c) => c.id === cid) ||
                        t.classes?.find((c) => c.id === cid);
                      return { id: cid, name: found?.name || cid };
                    });
                    const editInputBase =
                      "w-full bg-white border border-slate-300 rounded px-2 py-1 text-sm text-ink transition-colors focus:border-[#16665a] focus:ring-1 focus:ring-[#16665a]/30 focus:outline-none";

                    return (
                      <tr
                        key={t.id}
                        className={`${idx > 0 ? "border-t border-line" : ""} transition-colors ${
                          isSelected
                            ? "bg-[#FDF8F6]"
                            : isDirty
                              ? "bg-amber-50/30"
                              : "hover:bg-slate-50/60"
                        }`}
                      >
                        <td className="relative px-3 py-3 text-center">
                          {isEditingTable && isDirty && (
                            <span
                              className="absolute left-1.5 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse pointer-events-none"
                              title="Dòng này có thay đổi chưa lưu"
                            />
                          )}
                          <input
                            type="checkbox"
                            className="rounded cursor-pointer"
                            checked={isSelected}
                            onChange={() => toggleSelect(t.id)}
                          />
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2.5 min-w-0">
                            <div
                              className="w-9 h-9 flex items-center justify-center rounded-full font-bold text-white shrink-0"
                              style={{ background: "#16665a" }}
                            >
                              {(rowData.full_name.trim() || t.full_name || "G")
                                .charAt(0)
                                .toUpperCase()}
                            </div>
                            <div className="flex-1 min-w-0">
                              {isEditingTable ? (
                                <input
                                  type="text"
                                  className={`${editInputBase} font-bold ${
                                    isTeacherCellDirty(t, rowEdit, "full_name")
                                      ? "bg-amber-50 border-amber-400 text-amber-950"
                                      : ""
                                  }`}
                                  value={rowData.full_name}
                                  onChange={(e) =>
                                    updateRowEdit(t, "full_name", e.target.value)
                                  }
                                  placeholder="Họ và tên giáo viên..."
                                />
                              ) : (
                                <div className="w-full px-2 py-1 border border-transparent rounded font-bold text-sm text-ink truncate">
                                  {t.full_name}
                                </div>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="-mx-2 flex flex-col gap-0.5">
                            {isEditingTable ? (
                              <>
                                <input
                                  type="email"
                                  className={`${editInputBase} py-0.5 ${
                                    isTeacherCellDirty(t, rowEdit, "email")
                                      ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                      : ""
                                  }`}
                                  value={rowData.email}
                                  onChange={(e) =>
                                    updateRowEdit(t, "email", e.target.value)
                                  }
                                  placeholder="Email (@gmail.com)..."
                                />
                                <input
                                  type="tel"
                                  className={`${editInputBase} text-xs text-ink-soft py-0.5 ${
                                    isTeacherCellDirty(t, rowEdit, "phone")
                                      ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                      : ""
                                  }`}
                                  value={rowData.phone}
                                  onChange={(e) =>
                                    updateRowEdit(t, "phone", e.target.value)
                                  }
                                  placeholder="Số điện thoại (10 số)..."
                                />
                              </>
                            ) : (
                              <>
                                <div className="w-full px-2 py-0.5 border border-transparent rounded text-sm text-ink truncate">
                                  {t.email}
                                </div>
                                <div className="w-full px-2 py-0.5 border border-transparent rounded text-xs text-ink-soft truncate">
                                  {t.phone}
                                </div>
                              </>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="-mx-2">
                            {isEditingTable ? (
                              <button
                                type="button"
                                onClick={(e) => {
                                  if (openClassDropdown?.teacherId === t.id) {
                                    setOpenClassDropdown(null);
                                    return;
                                  }
                                  const rect = e.currentTarget.getBoundingClientRect();
                                  const spaceBelow = window.innerHeight - rect.bottom;
                                  const openUpward = spaceBelow < 300 && rect.top > 300;
                                  const minWidth = Math.max(rect.width, 250);
                                  const left = Math.max(
                                    8,
                                    Math.min(rect.left, window.innerWidth - minWidth - 8),
                                  );
                                  setClassSearchQuery("");
                                  setOpenClassDropdown({
                                    teacherId: t.id,
                                    top: openUpward ? undefined : rect.bottom + 6,
                                    bottom: openUpward
                                      ? window.innerHeight - rect.top + 6
                                      : undefined,
                                    left,
                                    minWidth,
                                  });
                                }}
                                className={`w-full text-left bg-white border rounded px-2 py-1 text-sm flex items-center justify-between gap-1.5 transition-colors ${
                                  isTeacherCellDirty(t, rowEdit, "class_ids")
                                    ? "bg-amber-50 border-amber-400 text-amber-950 font-medium"
                                    : "border-slate-300 hover:border-[#16665a] text-ink"
                                }`}
                                title={
                                  selectedClassObjs.length > 0
                                    ? selectedClassObjs.map((c) => c.name).join(", ")
                                    : "Click để chọn lớp phụ trách"
                                }
                              >
                                <span className="truncate flex-1">
                                  {selectedClassObjs.length === 0 ? (
                                    <span className="text-slate-400 italic">
                                      Chưa phân lớp
                                    </span>
                                  ) : selectedClassObjs.length === 1 ? (
                                    selectedClassObjs[0].name
                                  ) : (
                                    <span className="inline-flex items-center gap-1 max-w-full">
                                      <span className="truncate">
                                        {selectedClassObjs[0].name}
                                      </span>
                                      <span className="inline-flex items-center px-1.5 rounded text-[10px] font-bold bg-brand/10 text-brand border border-brand/20 shrink-0">
                                        +{selectedClassObjs.length - 1}
                                      </span>
                                    </span>
                                  )}
                                </span>
                                <span className="text-slate-400 text-[10px] shrink-0">
                                  ▼
                                </span>
                              </button>
                            ) : (
                              <div className="w-full px-2 py-1 border border-transparent rounded text-sm text-ink truncate">
                                {t.class_name || "Chưa phân lớp"}
                              </div>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="-mx-2">
                            {isEditingTable ? (
                              <div
                                className={`w-full px-2 py-1 border rounded text-xs font-medium inline-flex items-center transition-colors focus-within:border-[#16665a] focus-within:ring-1 focus-within:ring-[#16665a]/30 ${
                                  isTeacherCellDirty(t, rowEdit, "username")
                                    ? "bg-amber-50 border-amber-400 text-amber-950"
                                    : "bg-white border-slate-300 text-slate-800"
                                }`}
                              >
                                <span className="text-slate-400 select-none shrink-0">
                                  @
                                </span>
                                <input
                                  type="text"
                                  className="w-full min-w-0 bg-transparent text-xs font-medium text-inherit focus:outline-none"
                                  value={rowData.username}
                                  onChange={(e) =>
                                    updateRowEdit(t, "username", e.target.value)
                                  }
                                  placeholder="username..."
                                />
                              </div>
                            ) : t.username ? (
                              <div className="w-full px-2 py-1 border border-transparent rounded text-xs">
                                <Pill
                                  tone="brand"
                                  className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium max-w-full truncate"
                                >
                                  @{t.username}
                                </Pill>
                              </div>
                            ) : (
                              <div className="w-full px-2 py-1 border border-transparent rounded text-xs text-ink-faint">
                                —
                              </div>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="-mx-2">
                            {isEditingTable ? (
                              <select
                                className={`w-full px-2 py-1 border rounded text-xs font-medium bg-white transition-colors focus:border-[#16665a] focus:ring-1 focus:ring-[#16665a]/30 focus:outline-none ${
                                  isTeacherCellDirty(t, rowEdit, "status")
                                    ? "bg-amber-50 border-amber-400 text-amber-950"
                                    : "border-slate-300 text-slate-800"
                                }`}
                                value={rowData.status}
                                onChange={(e) =>
                                  updateRowEdit(t, "status", e.target.value)
                                }
                              >
                                <option value="active">Đang dạy</option>
                                <option value="on_leave">Nghỉ phép</option>
                                <option value="inactive">Ngừng</option>
                              </select>
                            ) : (
                              <div className="w-full px-2 py-1 border border-transparent rounded text-xs">
                                <Pill
                                  className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
                                  tone={
                                    t.status === "active"
                                      ? "ok"
                                      : t.status === "on_leave"
                                        ? "warn"
                                        : "neutral"
                                  }
                                >
                                  {t.status === "active"
                                    ? "Đang dạy"
                                    : t.status === "on_leave"
                                      ? "Nghỉ phép"
                                      : "Ngừng"}
                                </Pill>
                              </div>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-right whitespace-nowrap">
                          <div className="inline-flex items-center justify-end gap-2">
                            <button
                              type="button"
                              onClick={() => openEdit(t)}
                              className="px-2.5 py-1 rounded-lg text-xs font-semibold text-ink hover:bg-slate-100 transition-colors"
                            >
                              Sửa
                            </button>
                            <button
                              type="button"
                              onClick={() => setConfirmDel(t)}
                              className="px-2.5 py-1 rounded-lg text-xs font-semibold text-bad hover:bg-bad-tint transition-colors"
                            >
                              Xóa
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

      <div className="text-xs text-[#65727D] mt-2 mb-4">
        💡 Lưới nhập trực tiếp (Web Grid): chạm vào ô để sửa tại chỗ; thay đổi được lưu theo hàng. Phân công lớp thực hiện ngay tại cột Lớp phụ trách.
      </div>

      {/* Popover multi-select Lớp phụ trách (fixed để không bị overflow-hidden cắt) */}
      {isEditingTable && openClassDropdown && activeDropdownTeacher && (() => {
        const activeRowData = getRowData(activeDropdownTeacher);
        const qCls = classSearchQuery.trim().toLowerCase();
        const filteredClasses = classes.filter((c) => {
          if (!qCls) return true;
          return (
            c.name.toLowerCase().includes(qCls) ||
            (c.grade_label || "").toLowerCase().includes(qCls)
          );
        });
        return (
          <>
            <div
              className="fixed inset-0 z-40"
              onClick={() => setOpenClassDropdown(null)}
            />
            <div
              ref={classDropdownRef}
              style={{
                top: openClassDropdown.top,
                bottom: openClassDropdown.bottom,
                left: openClassDropdown.left,
                width: openClassDropdown.minWidth,
              }}
              className="fixed bg-white rounded-lg shadow-xl border border-slate-200 z-50 p-2.5 space-y-2"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="relative">
                <input
                  type="text"
                  value={classSearchQuery}
                  onChange={(e) => setClassSearchQuery(e.target.value)}
                  placeholder="Tìm tên lớp..."
                  className="w-full text-xs px-2.5 py-1.5 border border-slate-200 rounded focus:border-[#16665a] focus:outline-none"
                  autoFocus
                />
                {classSearchQuery && (
                  <button
                    type="button"
                    onClick={() => setClassSearchQuery("")}
                    className="absolute right-2 top-1.5 text-xs text-slate-400 hover:text-slate-600"
                  >
                    ✕
                  </button>
                )}
              </div>
              <div className="max-h-48 overflow-y-auto space-y-0.5 divide-y divide-slate-50">
                {filteredClasses.length === 0 ? (
                  <div className="text-center py-3 text-xs text-slate-400">
                    {classes.length === 0
                      ? "Chưa có lớp nào"
                      : "Không tìm thấy lớp phù hợp"}
                  </div>
                ) : (
                  filteredClasses.map((c) => {
                    const isChecked = activeRowData.class_ids.includes(c.id);
                    return (
                      <label
                        key={c.id}
                        className="flex items-center gap-2 px-2 py-1.5 hover:bg-slate-50 rounded cursor-pointer text-xs"
                      >
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() =>
                            toggleRowClassSelection(activeDropdownTeacher, c.id)
                          }
                          className="rounded text-brand focus:ring-brand/30 cursor-pointer"
                        />
                        <div className="flex-1 min-w-0 truncate">
                          <span className="font-medium text-slate-800">
                            {c.name}
                          </span>
                          {c.grade_label && (
                            <span className="text-[11px] text-slate-400 ml-1">
                              ({c.grade_label})
                            </span>
                          )}
                        </div>
                      </label>
                    );
                  })
                )}
              </div>
              <div className="flex items-center justify-between pt-1.5 border-t border-slate-100 text-[11px]">
                <span className="text-slate-500">
                  Đã chọn:{" "}
                  <strong className="text-slate-700">
                    {activeRowData.class_ids.length}
                  </strong>{" "}
                  lớp
                </span>
                <button
                  type="button"
                  onClick={() => setOpenClassDropdown(null)}
                  className="text-brand font-semibold hover:underline"
                >
                  Xong
                </button>
              </div>
            </div>
          </>
        );
      })()}

      <div className="text-xs text-ink-faint mt-2">
        Tổng: <span className="font-bold text-ink">{filtered.length}</span> giáo viên
      </div>

      {/* Drawer chỉnh sửa */}
      <Drawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={editing ? "Chỉnh sửa giáo viên" : "Thêm giáo viên mới"}
        footer={
          <>
            <button
              onClick={() => setDrawerOpen(false)}
              className="kbtn kbtn-secondary"
              disabled={saving}
            >
              Hủy
            </button>
            <button
              onClick={handleSave}
              className="kbtn kbtn-primary"
              disabled={saving}
            >
              {saving ? "Đang lưu..." : editing ? "Lưu thay đổi" : "Tạo giáo viên"}
            </button>
          </>
        }
      >
        <FormField label="Họ và tên" required>
          <input
            className="kinput"
            value={form.full_name}
            onChange={(e) => setForm({ ...form, full_name: e.target.value })}
            placeholder="Nguyễn Văn A"
          />
        </FormField>
        <FormField label="Email" required hint="Phải là địa dạng Gmail (@gmail.com)">
          <input
            className="kinput"
            type="email"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
            placeholder="teacher@gmail.com"
          />
        </FormField>
        <FormField label="Số điện thoại" required hint="Gồm đúng 10 chữ số, bắt đầu bằng 0">
          <input
            className="kinput"
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            placeholder="0901234567"
          />
        </FormField>
        <FormField label="Lớp phụ trách">
          <div className="flex flex-wrap gap-2">
            {classes.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => toggleClass(c.id)}
                className={`px-3 py-1.5 rounded-control text-xs font-semibold border ${
                  form.class_ids.includes(c.id)
                    ? "text-white border-transparent"
                    : "bg-white text-ink border-line-strong"
                }`}
                style={
                  form.class_ids.includes(c.id)
                    ? { background: "#16665a", color: "white" }
                    : {}
                }
              >
                {c.name}
              </button>
            ))}
            {classes.length === 0 && (
              <span className="text-xs text-ink-faint">Chưa có lớp nào.</span>
            )}
          </div>
        </FormField>
        <FormField label="Tên đăng nhập" hint="(không bắt buộc)">
          <input
            className="kinput"
            value={form.username}
            onChange={(e) => setForm({ ...form, username: e.target.value })}
            placeholder="tên đăng nhập"
          />
        </FormField>
        <FormField
          label={editing ? "Đặt lại mật khẩu" : "Mật khẩu"}
          hint={editing ? "Bỏ trống nếu không muốn đổi. Mặc định: 123456" : "Mặc định: 123456 nếu bỏ trống"}
        >
          <input
            className="kinput"
            type="text"
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            placeholder="••••••"
          />
        </FormField>
        <FormField label="Trạng thái">
          <select
            className="kinput"
            value={form.status}
            onChange={(e) => setForm({ ...form, status: e.target.value })}
          >
            <option value="active">Đang dạy</option>
            <option value="on_leave">Nghỉ phép</option>
            <option value="inactive">Ngừng công tác</option>
          </select>
        </FormField>
      </Drawer>

      <ConfirmDialog
        open={!!confirmDel}
        title="Xóa giáo viên?"
        message={`Bạn có chắc muốn xóa giáo viên "${confirmDel?.full_name}"? Thao tác này không thể hoàn tác.`}
        confirmLabel="Xóa"
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      <ConfirmDialog
        open={confirmBulkDel}
        title={`Xóa ${selectedIds.length} giáo viên đã chọn?`}
        message={`Bạn có chắc muốn xóa vĩnh viễn ${selectedIds.length} giáo viên này? Toàn bộ tài khoản và thông tin phân công lớp sẽ được gỡ bỏ.`}
        confirmLabel={bulkDeleting ? "Đang xóa..." : `Xóa ${selectedIds.length} giáo viên`}
        onConfirm={handleBulkDelete}
        onCancel={() => !bulkDeleting && setConfirmBulkDel(false)}
      />

      <ImportModal
        open={importOpen}
        onClose={() => setImportOpen(false)}
        title="Nhập danh sách giáo viên từ file"
        description="Tải lên file Excel (.xlsx, .xls) hoặc CSV để thêm hàng loạt giáo viên vào trường. Nếu để trống Tên đăng nhập và Mật khẩu, hệ thống sẽ tự động dùng Số điện thoại làm tên đăng nhập và mật khẩu mặc định là 123456 (giáo viên có thể đăng nhập bằng cả Email hoặc Số điện thoại)."
        templateFilename="mau_nhap_giao_vien.xlsx"
        sampleHeaders={["Họ và tên", "Email", "Số điện thoại", "Tên lớp", "Tên đăng nhập", "Mật khẩu"]}
        sampleRow={[
          "Nguyễn Thị Mai",
          "mai.nguyen@gmail.com",
          "0901234567",
          classes[0]?.name || "Lớp Mầm 1",
          "mainguyen",
          "123456",
        ]}
        onImportRows={handleImportRows}
        onSuccess={() => {
          setToast({ msg: "Đã nhập danh sách giáo viên thành công", tone: "ok" });
        }}
      />

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}