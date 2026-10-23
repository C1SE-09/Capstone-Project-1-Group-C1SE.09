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

  async function handleImportRows(rows: string[][]): Promise<ImportResult> {
    let success = 0;
    let failed = 0;
    const errors: string[] = [];

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const fullName = row[0]?.trim();
      const phone = row[1]?.trim();
      const email = row[2]?.trim() || null;
      const relationship = row[3]?.trim() || "Phụ huynh";
      const username = row[4]?.trim() || phone;
      const password = row[5]?.trim() || "123456";

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

      try {
        await createParent({
          full_name: fullName,
          phone,
          email,
          relationship,
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
    return { total: rows.length, success, failed, errors };
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
            <span>Đã chọn {selectedIds.length} phụ huynh</span>
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
              </thead>
              <tbody>
                {filtered.map((p, idx) => {
                  const isSelected = selectedIds.includes(p.id);
                  return (
                  <tr
                    key={p.id}
                    className={`${idx > 0 ? "border-t border-line" : ""} ${
                      isSelected ? "bg-[#FDF8F6]" : ""
                    }`}
                  >
                    <td className="px-3 py-3 text-center">
                      <input
                        type="checkbox"
                        className="rounded cursor-pointer"
                        checked={isSelected}
                        onChange={() => toggleSelect(p.id)}
                      />
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2.5">
                        <div
                          className="w-9 h-9 flex items-center justify-center rounded-full text-white font-bold"
                          style={{ background: "#4B6F8C" }}
                        >
                          {p.full_name.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-bold text-ink">{p.full_name}</div>
                          <div className="text-xs text-ink-soft">{p.email || "—"}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-ink">{p.phone}</div>
                      <div className="text-xs text-ink-soft">
                        {p.relationship || "Phụ huynh"}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-ink-soft max-w-xs line-clamp-2">
                      {getParentChildrenSummary(p, children)}
                    </td>
                    <td className="px-4 py-3">
                      {p.username ? (
                        <Pill tone="info">@{p.username}</Pill>
                      ) : (
                        <span className="text-xs text-ink-faint">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <Pill tone={p.status === "active" ? "ok" : "neutral"}>
                        {p.status === "active" ? "Đang hoạt động" : "Ngừng"}
                      </Pill>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => openEdit(p)}
                        className="kbtn kbtn-ghost text-xs"
                      >
                        Sửa
                      </button>
                      <button
                        onClick={() => setConfirmDel(p)}
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
        description="Tải lên file Excel (.xlsx, .xls) hoặc CSV để thêm hàng loạt phụ huynh. Nếu để trống cột Tên đăng nhập và Mật khẩu, hệ thống sẽ tự động dùng Số điện thoại làm tên đăng nhập và mật khẩu mặc định là 123456 (phụ huynh có thể đăng nhập bằng cả Email hoặc Số điện thoại)."
        templateFilename="mau_nhap_phu_huynh.xlsx"
        sampleHeaders={["Họ và tên", "Số điện thoại", "Email", "Quan hệ (Bố/Mẹ/...)", "Tên đăng nhập", "Mật khẩu"]}
        sampleRow={[
          "Nguyễn Văn An",
          "0912345678",
          "an.nguyen@gmail.com",
          "Bố",
          "an_nguyen",
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