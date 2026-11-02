/**
 * pages/school-admin/parents.tsx
 * ==============================
 * CRUD phụ huynh — UI y hệt Flutter app.
 */

import { useEffect, useMemo, useState } from "react";
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
  Child,
  ChildPayload,
  Parent,
  ParentPayload,
  SchoolClass,
  createParent,
  deleteParent,
  deleteParentsBatch,
  getChildren,
  getClasses,
  getParents,
  updateParent,
} from "@/lib/admin-api";

interface FormState {
  full_name: string;
  phone: string;
  email: string;
  relationship: string;
  child_ids: string[];
  username: string;
  password: string;
  status: string;
}

const EMPTY: FormState = {
  full_name: "",
  phone: "",
  email: "",
  relationship: "",
  child_ids: [],
  username: "",
  password: "",
  status: "active",
};

function getParentChildrenSummary(p: Parent, allChildren: Child[] = []): string {
  if (p.children && p.children.length > 0) {
    return p.children
      .map((c) => {
        const name = c.name || (c as any).full_name || "Bé";
        const cls = c.class_name ? ` (${c.class_name})` : "";
        return `${name}${cls}`;
      })
      .join(", ");
  }

  const rawSummary = (p.children_summary || "").trim();
  const isUnlinked =
    !rawSummary ||
    rawSummary.includes("Chưa liên kết") ||
    rawSummary.includes("Chưa có liên kết");

  if (!isUnlinked) {
    return rawSummary.replace(/^Bé:\s*/, "");
  }

  const matched = allChildren.filter(
    (c) =>
      c.parent_id === p.id ||
      (c.parent_ids && c.parent_ids.includes(p.id)) ||
      (p.child_ids && p.child_ids.includes(c.id)) ||
      (p.child_id && p.child_id === c.id),
  );

  if (matched.length > 0) {
    return matched
      .map((c) => `${c.full_name}${c.class_name ? ` (${c.class_name})` : ""}`)
      .join(", ");
  }

  return "Chưa liên kết học sinh";
}

function parentHasChildInClass(
  p: Parent,
  classId: string,
  allChildren: Child[] = [],
): boolean {
  if (!classId) return true;

  if (p.children && p.children.length > 0) {
    if (p.children.some((c) => c.class_id === classId)) return true;
  }

  const matched = allChildren.filter(
    (c) =>
      c.parent_id === p.id ||
      (c.parent_ids && c.parent_ids.includes(p.id)) ||
      (p.child_ids && p.child_ids.includes(c.id)) ||
      (p.child_id && p.child_id === c.id),
  );

  if (matched.some((c) => c.class_id === classId)) return true;

  return false;
}

export default function SchoolAdminParentsPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [selectedClassId, setSelectedClassId] = useState("");
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [children, setChildren] = useState<Child[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  // Chế độ Bulk Edit giống Excel: Toàn bộ bảng luôn ở chế độ có thể chỉnh sửa trực tiếp
  interface RowEditState {
    full_name: string;
    phone: string;
    email: string;
    relationship: string;
    username: string;
    children_text: string;
    status: string;
  }
  const [tableEdits, setTableEdits] = useState<Record<string, RowEditState>>({});
  const [savingTable, setSavingTable] = useState(false);
  const [editing, setEditing] = useState<Parent | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Parent | null>(null);
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
    Promise.all([
      getChildren().catch(() => []),
      getClasses().catch(() => []),
    ]).then(([c, cl]) => {
      setChildren(c);
      setClasses(cl);
    });
  }, []);

  const { data: parents, error: parentsError, mutate } = useSWR<Parent[]>(
    ready ? "parents" : null,
    () => getParents(),
    { refreshInterval: 30000 },
  );

  useEffect(() => {
    if (parentsError && (parentsError as any).status === 401) {
      clearToken("schoolAdmin");
      window.location.href = "/login";
    }
  }, [parentsError]);

  const filtered = useMemo(() => {
    let list = parents ?? [];
    if (selectedClassId) {
      list = list.filter((p) => parentHasChildInClass(p, selectedClassId, children));
    }
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter((p) => {
      const childrenSummary = getParentChildrenSummary(p, children).toLowerCase();
      return (
        p.full_name.toLowerCase().includes(q) ||
        p.phone.toLowerCase().includes(q) ||
        (p.email || "").toLowerCase().includes(q) ||
        (p.username || "").toLowerCase().includes(q) ||
        childrenSummary.includes(q)
      );
    });
  }, [parents, query, selectedClassId, children]);

  function handleExportExcel() {
    if (!filtered || filtered.length === 0) {
      setToast({ msg: "Không có dữ liệu phụ huynh để xuất", tone: "warn" });
      return;
    }
    const headers = [
      "Họ và tên",
      "Số điện thoại",
      "Email",
      "Quan hệ",
      "Con liên kết",
      "Tên đăng nhập",
      "Trạng thái",
    ];
    const rows = filtered.map((p) => [
      p.full_name,
      p.phone,
      p.email || "",
      p.relationship || "Phụ huynh",
      getParentChildrenSummary(p, children),
      p.username || "",
      p.status === "active" ? "Đang hoạt động" : "Ngừng",
    ]);
    const currentClass = classes.find((cl) => cl.id === selectedClassId);
    const filename = currentClass
      ? `danh_sach_phu_huynh_${currentClass.name.replace(/\s+/g, "_")}.xlsx`
      : "danh_sach_phu_huynh.xlsx";
    exportToExcel(filename, "PhuHuynh", headers, rows);
    setToast({ msg: `Đã xuất ${rows.length} phụ huynh ra file Excel`, tone: "ok" });
  }

function findMatchingChildren(conStr: string, allChildren: Child[]): { matchedIds: string[]; missingNames: string[] } {
  if (!conStr || !conStr.trim()) return { matchedIds: [], missingNames: [] };

  const tokens = conStr.split(/[,;\n]+/).map((s) => s.trim()).filter(Boolean);
  const matchedIds: string[] = [];
  const missingNames: string[] = [];

  for (const token of tokens) {
    const match = token.match(/^(.*?)\s*\((.*?)\)$/);
    const childName = (match ? match[1] : token).trim().toLowerCase();
    const classHint = (match ? match[2] : "").trim().toLowerCase();

    const candidates = allChildren.filter((c) => {
      const cName = c.full_name.trim().toLowerCase();
      const cNick = (c.nickname || "").trim().toLowerCase();
      const matchName =
        cName === childName ||
        cName.includes(childName) ||
        childName.includes(cName) ||
        cNick === childName;
      if (!matchName) return false;
      if (classHint) {
        const cClass = (c.class_name || "").toLowerCase();
        return cClass.includes(classHint);
      }
      return true;
    });

    if (candidates.length > 0) {
      for (const cand of candidates) {
        if (!matchedIds.includes(cand.id)) {
          matchedIds.push(cand.id);
        }
      }
    } else {
      missingNames.push(token);
    }
  }

  return { matchedIds, missingNames };
}

  async function handleImportRows(rows: string[][]): Promise<ImportResult> {
    let success = 0;
    let failed = 0;
    const errors: string[] = [];
    const warnings: string[] = [];

    let currentChildren = children;
    try {
      currentChildren = await getChildren();
      setChildren(currentChildren);
    } catch {
      // dùng children sẵn có
    }

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const fullName = row[0]?.trim();
      const phone = row[1]?.trim();
      const email = row[2]?.trim() || null;
      const relationship = row[3]?.trim() || "Phụ huynh";

      let conStr = "";
      let username = "";
      let password = "";

      if (row.length >= 7) {
        conStr = row[4]?.trim() || "";
        username = row[5]?.trim() || phone;
        password = row[6]?.trim() || "123456";
      } else if (row.length === 6) {
        const col4 = row[4]?.trim() || "";
        const col5 = row[5]?.trim() || "";
        const isChildName = col4.includes(" ") || col4.includes(",") || /[à-ỹÀ-Ỹ]/.test(col4);
        if (isChildName) {
          conStr = col4;
          username = phone;
          password = col5 || "123456";
        } else {
          conStr = "";
          username = col4 || phone;
          password = col5 || "123456";
        }
      } else {
        username = row[4]?.trim() || phone;
        password = row[5]?.trim() || "123456";
      }

      if (!fullName || !phone) {
        failed++;
        errors.push(`Dòng ${i + 1}: Thiếu họ tên hoặc số điện thoại.`);
        continue;
      }
      if (!/^0\d{9}$/.test(phone)) {
        failed++;
        errors.push(`Dòng ${i + 1} (${fullName}): Số điện thoại phải gồm 10 số bắt đầu bằng 0.`);
        continue;
      }

      const { matchedIds, missingNames } = findMatchingChildren(conStr, currentChildren);
      if (missingNames.length > 0) {
        warnings.push(
          `Dòng ${i + 1} (${fullName}): Không tìm thấy học sinh [${missingNames.join(", ")}] trong hệ thống để tự động liên kết.`
        );
      }

      try {
        await createParent({
          full_name: fullName,
          phone,
          email,
          relationship,
          child_ids: matchedIds.length > 0 ? matchedIds : undefined,
          username,
          password,
          status: "active",
        });
        success++;
      } catch (err: any) {
        failed++;
        errors.push(`Dòng ${i + 1} (${fullName}): ${err?.message || "Lỗi tạo phụ huynh"}`);
      }
    }

    if (success > 0) {
      mutate();
    }
    return { total: rows.length, success, failed, errors, warnings };
  }

  // Lấy chuỗi con liên kết ban đầu (loại bỏ nhãn 'Chưa liên kết')
  function getInitialChildrenText(p: Parent): string {
    const summary = getParentChildrenSummary(p, children);
    return summary.includes("Chưa liên kết") || summary.includes("Chưa có liên kết") ? "" : summary;
  }

  // Lấy dữ liệu hiện tại của một dòng (ưu tiên dữ liệu đã sửa trong tableEdits, fallback về dữ liệu gốc)
  function getRowData(p: Parent): RowEditState {
    if (tableEdits[p.id]) return tableEdits[p.id];
    return {
      full_name: p.full_name || "",
      phone: p.phone || "",
      email: p.email || "",
      relationship: p.relationship || "Phụ huynh",
      username: p.username || "",
      children_text: getInitialChildrenText(p),
      status: p.status || "active",
    };
  }

  // Cập nhật giá trị ô input phẳng
  function updateCell(p: Parent, field: keyof RowEditState, val: string) {
    setTableEdits((prev) => {
      const current = prev[p.id] || getRowData(p);
      return {
        ...prev,
        [p.id]: {
          ...current,
          [field]: val,
        },
      };
    });
  }

  // Toggle nhanh trạng thái active / inactive trực tiếp trên bảng
  function toggleRowStatus(p: Parent) {
    const current = getRowData(p);
    const nextStatus = current.status === "active" ? "inactive" : "active";
    updateCell(p, "status", nextStatus);
  }

  // Kiểm tra xem 1 ô cụ thể có bị thay đổi so với dữ liệu gốc hay không
  function isCellDirty(p: Parent, field: keyof RowEditState): boolean {
    if (!tableEdits[p.id]) return false;
    const current = tableEdits[p.id][field];
    if (field === "full_name") return current.trim() !== (p.full_name || "").trim();
    if (field === "phone") return current.trim() !== (p.phone || "").trim();
    if (field === "email") return current.trim() !== (p.email || "").trim();
    if (field === "relationship") return current.trim() !== (p.relationship || "Phụ huynh").trim();
    if (field === "username") return current.trim() !== (p.username || "").trim();
    if (field === "status") return current !== (p.status || "active");
    if (field === "children_text") {
      const cleanOrig = getInitialChildrenText(p);
      return current.trim() !== cleanOrig.trim();
    }
    return false;
  }

  // Kiểm tra xem dòng có bất kỳ ô nào bị thay đổi hay không
  function isRowDirty(p: Parent): boolean {
    if (!tableEdits[p.id]) return false;
    return (
      isCellDirty(p, "full_name") ||
      isCellDirty(p, "phone") ||
      isCellDirty(p, "email") ||
      isCellDirty(p, "relationship") ||
      isCellDirty(p, "username") ||
      isCellDirty(p, "status") ||
      isCellDirty(p, "children_text")
    );
  }

  // Danh sách các dòng đang có thay đổi chưa lưu
  const dirtyRows = useMemo(() => {
    return filtered.filter((p) => isRowDirty(p));
  }, [filtered, tableEdits, children]);

  // Hủy toàn bộ thay đổi chưa lưu
  function cancelAllEdits() {
    setTableEdits({});
    setToast({ msg: "Đã hủy bỏ mọi thay đổi chưa lưu", tone: "brand" });
  }

  // Lưu hàng loạt tất cả các dòng đã thay đổi cùng một lúc (Bulk Save)
  async function handleSaveAllEdits() {
    if (dirtyRows.length === 0) {
      setToast({ msg: "Không có thay đổi nào để lưu", tone: "brand" });
      return;
    }

    // Kiểm tra tính hợp lệ trước khi gọi API
    for (const p of dirtyRows) {
      const edit = getRowData(p);
      if (!edit.full_name.trim()) {
        setToast({ msg: `Họ tên phụ huynh không được để trống (SĐT: ${edit.phone})`, tone: "bad" });
        return;
      }
      if (!edit.phone.trim()) {
        setToast({ msg: `Vui lòng nhập SĐT cho phụ huynh ${edit.full_name}`, tone: "bad" });
        return;
      }
      if (edit.email && !/^[a-zA-Z0-9._%+-]+@gmail\.com$/i.test(edit.email.trim())) {
        setToast({ msg: `Email của ${edit.full_name} phải đúng định dạng Gmail (@gmail.com)`, tone: "bad" });
        return;
      }
    }

    setSavingTable(true);
    let success = 0;
    let failed = 0;

    for (const p of dirtyRows) {
      const edit = getRowData(p);
      // Nếu có sửa cột con liên kết thì map ra matchedIds
      let child_ids: string[] | undefined = undefined;
      if (isCellDirty(p, "children_text")) {
        const { matchedIds } = findMatchingChildren(edit.children_text, children || []);
        child_ids = matchedIds;
      }

      const payload: ParentPayload = {
        full_name: edit.full_name.trim(),
        phone: edit.phone.trim(),
        email: edit.email.trim() || null,
        relationship: edit.relationship.trim() || null,
        username: edit.username.trim() || null,
        status: edit.status,
        ...(child_ids !== undefined ? { child_ids } : {}),
      };

      try {
        await updateParent(p.id, payload);
        success++;
      } catch (e) {
        failed++;
      }
    }

    setSavingTable(false);
    setTableEdits({});
    mutate();

    if (failed === 0) {
      setToast({ msg: `Đã lưu thành công ${success} phụ huynh!`, tone: "ok" });
    } else {
      setToast({ msg: `Đã lưu ${success} phụ huynh (${failed} phụ huynh bị lỗi cập nhật)`, tone: "warn" });
    }
  }

  function openCreate() {
    setEditing(null);
    setForm(EMPTY);
    setDrawerOpen(true);
  }

  function openEdit(p: Parent) {
    setEditing(p);
    setForm({
      full_name: p.full_name,
      phone: p.phone,
      email: p.email,
      relationship: p.relationship,
      child_ids: p.child_ids,
      username: p.username || "",
      password: "",
      status: p.status,
    });
    setDrawerOpen(true);
  }

  async function handleSave() {
    if (!form.full_name.trim() || !form.phone.trim()) {
      setToast({ msg: "Vui lòng nhập họ tên và số điện thoại", tone: "bad" });
      return;
    }
    if (form.phone && !/^0\d{9}$/.test(form.phone.trim())) {
      setToast({ msg: "Số điện thoại phải gồm 10 chữ số bắt đầu bằng 0", tone: "bad" });
      return;
    }
    if (form.email && !/^[a-zA-Z0-9._%+-]+@gmail\.com$/i.test(form.email.trim())) {
      setToast({ msg: "Email phải đúng định dạng Gmail", tone: "bad" });
      return;
    }
    setSaving(true);
    try {
      const payload: ParentPayload = {
        full_name: form.full_name.trim(),
        phone: form.phone.trim(),
        email: form.email.trim() || null,
        relationship: form.relationship.trim() || null,
        child_ids: form.child_ids,
        username: form.username.trim() || null,
        password: form.password.trim() || null,
        status: form.status,
      };
      if (editing) {
        await updateParent(editing.id, payload);
        setToast({ msg: "Đã cập nhật phụ huynh", tone: "ok" });
      } else {
        await createParent(payload);
        setToast({ msg: "Đã thêm phụ huynh mới", tone: "ok" });
      }
      setDrawerOpen(false);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể lưu", tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  const allSelected =
    filtered.length > 0 && filtered.every((p) => selectedIds.includes(p.id));
  const someSelected =
    selectedIds.length > 0 && !allSelected;

  function toggleSelectAll() {
    if (allSelected) {
      setSelectedIds([]);
    } else {
      setSelectedIds(filtered.map((p) => p.id));
    }
  }

  function toggleSelect(id: string) {
    setSelectedIds((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    );
  }

  async function handleDelete(p: Parent) {
    try {
      await deleteParent(p.id);
      setToast({ msg: `Đã xóa ${p.full_name}`, tone: "ok" });
      setSelectedIds((prev) => prev.filter((id) => id !== p.id));
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
  }

  async function handleBulkDelete() {
    if (selectedIds.length === 0) return;
    setBulkDeleting(true);
    try {
      const res = await deleteParentsBatch(selectedIds);
      setToast({
        msg: res.message || `Đã xóa ${selectedIds.length} phụ huynh`,
        tone: "ok",
      });
      setSelectedIds([]);
      mutate();
    } catch (err: any) {
      setToast({
        msg: err?.message || "Không thể xóa hàng loạt phụ huynh",
        tone: "bad",
      });
    } finally {
      setBulkDeleting(false);
      setConfirmBulkDel(false);
    }
  }

  function toggleChild(cid: string) {
    setForm((f) => {
      const exists = f.child_ids.includes(cid);
      return {
        ...f,
        child_ids: exists ? f.child_ids.filter((x) => x !== cid) : [...f.child_ids, cid],
      };
    });
  }

  if (!ready) return null;

  return (
    <SchoolAdminLayout
      active="features"
      pageTitle="Quản lý phụ huynh"
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
            title="Xuất danh sách ra file Excel"
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
          {dirtyRows.length > 0 && (
            <>
              <button
                onClick={cancelAllEdits}
                disabled={savingTable}
                className="kbtn kbtn-secondary text-sm hover:border-bad hover:text-bad transition-colors"
                title="Hủy bỏ mọi thay đổi chưa lưu trên bảng"
              >
                ✕ Hủy thay đổi
              </button>
              <button
                onClick={handleSaveAllEdits}
                disabled={savingTable}
                className="kbtn text-sm font-bold text-white flex items-center gap-2 shadow-md hover:shadow-lg transition-all"
                style={{ background: "#16665a" }}
                title="Lưu toàn bộ thay đổi của tất cả các dòng vào hệ thống"
              >
                {savingTable ? (
                  <>
                    <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Đang lưu ({dirtyRows.length})...</span>
                  </>
                ) : (
                  <>
                    <span>💾</span>
                    <span>Lưu tất cả thay đổi</span>
                    <span className="bg-white/20 text-white text-xs px-1.5 py-0.2 rounded-full font-bold ml-1">
                      {dirtyRows.length}
                    </span>
                  </>
                )}
              </button>
            </>
          )}
          <button onClick={openCreate} className="kbtn kbtn-primary">
            + Thêm phụ huynh
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3 flex flex-col sm:flex-row gap-2.5 items-stretch sm:items-center">
        <div className="flex-1">
          <SearchBar
            value={query}
            onChange={setQuery}
            placeholder="Tìm phụ huynh, số điện thoại, con liên kết..."
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

      {/* Banner thông báo các dòng có thay đổi chưa lưu (Excel-like alert) */}
      {dirtyRows.length > 0 && (
        <div className="mb-3 px-4 py-2.5 bg-amber-50 border border-amber-200 text-amber-900 rounded-lg flex items-center justify-between shadow-sm animate-fadeIn">
          <div className="flex items-center gap-2 text-sm">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse" />
            <span className="font-semibold">Đang có {dirtyRows.length} phụ huynh có chỉnh sửa chưa lưu.</span>
            <span className="text-xs text-amber-700 hidden sm:inline">(Các ô màu vàng là các ô đã thay đổi)</span>
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

      <div className="card overflow-hidden">
        {!parents && !parentsError ? (
          <Spinner />
        ) : parentsError ? (
          <div className="text-center py-12">
            <div className="text-bad font-semibold mb-2">
              {(parentsError as any)?.status === 401
                ? "Phiên đăng nhập đã hết hạn. Đang chuyển về trang đăng nhập..."
                : `Không thể tải danh sách phụ huynh (${(parentsError as any)?.detail || "Vui lòng thử lại"})`}
            </div>
            <button onClick={() => mutate()} className="kbtn kbtn-secondary mt-2">
              Thử lại
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-5xl mb-2">👪</div>
            <div className="text-ink font-semibold">
              {query ? "Không có kết quả phù hợp." : "Chưa có phụ huynh nào"}
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
                          Đã chọn {selectedIds.length} phụ huynh
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
                        title="Chọn tất cả phụ huynh hiển thị"
                      />
                    </th>
                    <th className="px-4 py-3 text-left font-semibold">Họ tên</th>
                    <th className="px-4 py-3 text-left font-semibold">SĐT / Quan hệ</th>
                    <th className="px-4 py-3 text-left font-semibold">Con liên kết</th>
                    <th className="px-4 py-3 text-left font-semibold">Tài khoản</th>
                    <th className="px-4 py-3 text-left font-semibold">Trạng thái</th>
                    <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                  </tr>
                )}
              </thead>
              <tbody>
                {filtered.map((p, idx) => {
                  const isSelected = selectedIds.includes(p.id);
                  const isDirty = isRowDirty(p);
                  const rowData = getRowData(p);

                  // Helper class cho ô input phẳng chuẩn Excel
                  const baseCellClass =
                    "w-full bg-transparent border border-transparent rounded px-2 py-1.5 text-xs text-ink transition-all hover:bg-slate-100/70 hover:border-slate-300/60 focus:bg-white focus:border-[#4B6F8C] focus:ring-1 focus:ring-[#4B6F8C]/30 focus:outline-none";

                  return (
                    <tr
                      key={p.id}
                      className={`${idx > 0 ? "border-t border-line" : ""} transition-colors ${
                        isSelected
                          ? "bg-[#FDF8F6]"
                          : isDirty
                          ? "bg-amber-50/25"
                          : "hover:bg-sunken/30"
                      }`}
                    >
                      {/* Checkbox chọn dòng + Dấu chấm báo hiệu dòng có thay đổi chưa lưu */}
                      <td className="px-3 py-2.5 text-center">
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
                            className="rounded cursor-pointer"
                            checked={isSelected}
                            onChange={() => toggleSelect(p.id)}
                            title="Chọn dòng"
                          />
                        </div>
                      </td>

                      {/* Cột Họ tên: Avatar + Input Họ tên + Input Email */}
                      <td className="px-3 py-2">
                        <div className="flex items-center gap-2">
                          <div
                            className="w-8 h-8 flex items-center justify-center rounded-full text-white text-xs font-bold shrink-0 shadow-sm"
                            style={{ background: "#4B6F8C" }}
                          >
                            {(rowData.full_name || "P").charAt(0).toUpperCase()}
                          </div>
                          <div className="space-y-0.5 flex-1 min-w-[170px]">
                            <input
                              type="text"
                              className={`${baseCellClass} font-bold ${
                                isCellDirty(p, "full_name")
                                  ? "bg-amber-100/80 border-amber-300 text-amber-950"
                                  : ""
                              }`}
                              value={rowData.full_name}
                              onChange={(e) => updateCell(p, "full_name", e.target.value)}
                              placeholder="Họ và tên phụ huynh..."
                            />
                            <input
                              type="email"
                              className={`${baseCellClass} text-[11px] text-ink-soft py-0.5 ${
                                isCellDirty(p, "email")
                                  ? "bg-amber-100/80 border-amber-300 text-amber-950 font-medium"
                                  : ""
                              }`}
                              value={rowData.email}
                              onChange={(e) => updateCell(p, "email", e.target.value)}
                              placeholder="Gmail (@gmail.com)..."
                            />
                          </div>
                        </div>
                      </td>

                      {/* Cột SĐT / Quan hệ: 2 ô input phẳng */}
                      <td className="px-3 py-2">
                        <div className="space-y-0.5 min-w-[130px]">
                          <input
                            type="tel"
                            className={`${baseCellClass} font-bold ${
                              isCellDirty(p, "phone")
                                ? "bg-amber-100/80 border-amber-300 text-amber-950"
                                : ""
                            }`}
                            value={rowData.phone}
                            onChange={(e) => updateCell(p, "phone", e.target.value)}
                            placeholder="Số điện thoại..."
                          />
                          <input
                            type="text"
                            className={`${baseCellClass} text-[11px] text-ink-soft py-0.5 ${
                              isCellDirty(p, "relationship")
                                ? "bg-amber-100/80 border-amber-300 text-amber-950 font-medium"
                                : ""
                            }`}
                            value={rowData.relationship}
                            onChange={(e) => updateCell(p, "relationship", e.target.value)}
                            placeholder="Quan hệ (Bố, Mẹ...)"
                          />
                        </div>
                      </td>

                      {/* Cột Con liên kết: Ô input dạng text gõ trực tiếp tên con */}
                      <td className="px-3 py-2">
                        <div className="min-w-[180px]">
                          <input
                            type="text"
                            className={`${baseCellClass} ${
                              isCellDirty(p, "children_text")
                                ? "bg-amber-100/80 border-amber-300 text-amber-950 font-medium"
                                : ""
                            }`}
                            value={rowData.children_text}
                            onChange={(e) => updateCell(p, "children_text", e.target.value)}
                            placeholder="Nhập tên bé (ngăn cách bằng dấu phẩy)..."
                            title="Gõ tên con để tự động liên kết (vd: Bé Nam, Bé An)"
                          />
                        </div>
                      </td>

                      {/* Cột Tài khoản: Ô input phẳng có tiền tố @ */}
                      <td className="px-3 py-2">
                        <div className="min-w-[130px] flex items-center">
                          <span className="text-xs text-ink-soft font-medium pl-1">@</span>
                          <input
                            type="text"
                            className={`${baseCellClass} ${
                              isCellDirty(p, "username")
                                ? "bg-amber-100/80 border-amber-300 text-amber-950 font-medium"
                                : ""
                            }`}
                            value={rowData.username}
                            onChange={(e) => updateCell(p, "username", e.target.value)}
                            placeholder="username..."
                          />
                        </div>
                      </td>

                      {/* Cột Trạng thái: Toggle / Select phẳng click đổi trực tiếp */}
                      <td className="px-3 py-2">
                        <button
                          type="button"
                          onClick={() => toggleRowStatus(p)}
                          className={`text-xs px-2.5 py-1 rounded-full font-medium transition-all shadow-sm flex items-center gap-1.5 ${
                            rowData.status === "active"
                              ? "bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100"
                              : "bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200"
                          } ${
                            isCellDirty(p, "status")
                              ? "ring-2 ring-amber-400 font-bold"
                              : ""
                          }`}
                          title="Click để đổi nhanh trạng thái"
                        >
                          <span
                            className={`w-2 h-2 rounded-full ${
                              rowData.status === "active" ? "bg-emerald-500" : "bg-slate-400"
                            }`}
                          />
                          <span>{rowData.status === "active" ? "Đang hoạt động" : "Ngừng"}</span>
                        </button>
                      </td>

                      {/* Cột Thao tác: Bỏ hoàn toàn 'Xong'/'Đang sửa', chỉ giữ Chi tiết & Xóa */}
                      <td className="px-3 py-2 text-right whitespace-nowrap">
                        <div className="flex items-center justify-end gap-1">
                          <button
                            type="button"
                            onClick={() => openEdit(p)}
                            className="kbtn kbtn-ghost text-xs text-ink-soft hover:text-ink px-2 py-1"
                            title="Mở bảng chi tiết cấu hình nâng cao"
                          >
                            Chi tiết
                          </button>
                          <button
                            type="button"
                            onClick={() => setConfirmDel(p)}
                            className="kbtn kbtn-ghost text-xs text-bad hover:bg-bad/10 px-2 py-1"
                            title="Xóa phụ huynh này"
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

      <div className="text-xs text-ink-faint mt-2 flex items-center justify-between">
        <div>
          Tổng: <span className="font-bold text-ink">{filtered.length}</span> phụ huynh
          {selectedIds.length > 0 && (
            <span className="ml-2 font-semibold text-bad">
              (Đã chọn {selectedIds.length})
            </span>
          )}
        </div>
      </div>

      <Drawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={editing ? "Chỉnh sửa phụ huynh" : "Thêm phụ huynh mới"}
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
              {saving ? "Đang lưu..." : editing ? "Lưu thay đổi" : "Tạo phụ huynh"}
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
        <FormField label="Số điện thoại" required hint="Gồm đúng 10 chữ số, bắt đầu bằng 0">
          <input
            className="kinput"
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            placeholder="0901234567"
          />
        </FormField>
        <FormField label="Email" hint="(không bắt buộc) · Phải là Gmail">
          <input
            className="kinput"
            type="email"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
            placeholder="parent@gmail.com"
          />
        </FormField>
        <FormField label="Quan hệ với học sinh">
          <select
            className="kinput"
            value={form.relationship}
            onChange={(e) => setForm({ ...form, relationship: e.target.value })}
          >
            <option value="">-- Chọn quan hệ --</option>
            <option value="Bố">Bố</option>
            <option value="Mẹ">Mẹ</option>
            <option value="Ông">Ông</option>
            <option value="Bà">Bà</option>
            <option value="Người giám hộ">Người giám hộ</option>
            <option value="Phụ huynh">Phụ huynh</option>
          </select>
        </FormField>
        <FormField label="Con liên kết" hint="Chọn các học sinh mà phụ huynh này chịu trách nhiệm.">
          {children.length === 0 ? (
            <div className="text-xs text-ink-faint">
              Chưa có học sinh nào.
            </div>
          ) : (
            <div className="space-y-2 max-h-64 overflow-auto pr-1">
              {children.map((c) => {
                const checked = form.child_ids.includes(c.id);
                return (
                  <label
                    key={c.id}
                    className="flex items-center gap-2 px-3 py-2 rounded-control border border-line cursor-pointer hover:bg-sunken"
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggleChild(c.id)}
                      style={{ accentColor: "#16665a" }}
                    />
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-ink text-sm">
                        {c.full_name}
                      </div>
                      <div className="text-xs text-ink-soft truncate">
                        {c.class_name}
                        {c.nickname && ` · Biệt danh: ${c.nickname}`}
                      </div>
                    </div>
                  </label>
                );
              })}
            </div>
          )}
        </FormField>
        <FormField label="Tên đăng nhập" hint="(không bắt buộc)">
          <input
            className="kinput"
            value={form.username}
            onChange={(e) => setForm({ ...form, username: e.target.value })}
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
          />
        </FormField>
        <FormField label="Trạng thái">
          <select
            className="kinput"
            value={form.status}
            onChange={(e) => setForm({ ...form, status: e.target.value })}
          >
            <option value="active">Đang hoạt động</option>
            <option value="inactive">Ngừng</option>
          </select>
        </FormField>
      </Drawer>

      <ConfirmDialog
        open={!!confirmDel}
        title="Xóa phụ huynh?"
        message={`Bạn có chắc muốn xóa "${confirmDel?.full_name}"? Toàn bộ tài khoản và liên kết với học sinh sẽ được gỡ.`}
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      <ConfirmDialog
        open={confirmBulkDel}
        title={`Xóa ${selectedIds.length} phụ huynh đã chọn?`}
        message={`Bạn có chắc muốn xóa vĩnh viễn ${selectedIds.length} phụ huynh này? Toàn bộ tài khoản và liên kết với học sinh sẽ được gỡ bỏ.`}
        confirmLabel={bulkDeleting ? "Đang xóa..." : `Xóa ${selectedIds.length} phụ huynh`}
        onConfirm={handleBulkDelete}
        onCancel={() => !bulkDeleting && setConfirmBulkDel(false)}
      />

      <ImportModal
        open={importOpen}
        onClose={() => setImportOpen(false)}
        title="Nhập danh sách phụ huynh từ file"
        description="Tải lên file Excel (.xlsx, .xls) hoặc CSV để thêm hàng loạt phụ huynh và tự động liên kết với con theo tên học sinh. Nếu để trống cột Tên đăng nhập và Mật khẩu, hệ thống sẽ tự động dùng Số điện thoại làm tên đăng nhập và mật khẩu mặc định là 123456."
        templateFilename="mau_nhap_phu_huynh.xlsx"
        sampleHeaders={[
          "Họ và tên",
          "Số điện thoại",
          "Email",
          "Quan hệ (Bố/Mẹ/...)",
          "Con liên kết (Tên bé hoặc Tên bé - Lớp)",
          "Tên đăng nhập",
          "Mật khẩu",
        ]}
        sampleRow={[
          "Nguyễn Văn An",
          "0912345678",
          "an.nguyen@gmail.com",
          "Bố",
          children[0]
            ? `${children[0].full_name}${children[0].class_name ? ` (${children[0].class_name})` : ""}`
            : "Nguyễn Bảo An (Lớp Mầm 1)",
          "0912345678",
          "123456",
        ]}
        onImportRows={handleImportRows}
        onSuccess={() => {
          setToast({ msg: "Đã nhập danh sách phụ huynh thành công", tone: "ok" });
        }}
      />

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}