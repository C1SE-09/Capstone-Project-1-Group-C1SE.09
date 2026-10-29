/**
 * pages/school-admin/classes.tsx
 * ===============================
 * CRUD lớp học:
 *   - Search bar + nút Thêm/Làm mới/Xuất Excel.
 *   - Bảng danh sách (desktop) / Cards (mobile).
 *   - Drawer chỉnh sửa: Tên lớp, Khối, Phòng, Sĩ số tối đa.
 *   - Quy tắc: chỉ xóa lớp khi đã hết học sinh (backend chặn 400 nếu còn bé).
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
} from "@/components/ui-school";
import { clearToken, getStoredSchoolAdmin, getToken } from "@/lib/api";
import { exportToExcel } from "@/lib/excel-helper";
import {
  SchoolClass,
  ClassPayload,
  createClass,
  deleteClass,
  deleteClassesBatch,
  getClasses,
  updateClass,
} from "@/lib/admin-api";

interface ClassFormState {
  name: string;
  grade_label: string;
  room_number: string;
  capacity: string;
}

const EMPTY_FORM: ClassFormState = {
  name: "",
  grade_label: "",
  room_number: "",
  capacity: "",
};

const GRADE_OPTIONS = ["Nhà trẻ", "Mầm", "Chồi", "Lá", "Mẫu giáo", "Khác"];

export default function SchoolAdminClassesPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editing, setEditing] = useState<SchoolClass | null>(null);
  const [form, setForm] = useState<ClassFormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<SchoolClass | null>(null);
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
  }, []);

  const { data: classes, error: classesError, mutate } = useSWR<SchoolClass[]>(
    ready ? "classes" : null,
    () => getClasses(),
    { refreshInterval: 30000 },
  );

  useEffect(() => {
    if (classesError && (classesError as any).status === 401) {
      clearToken("schoolAdmin");
      window.location.href = "/login";
    }
  }, [classesError]);

  const filtered = useMemo(() => {
    const list = classes ?? [];
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        (c.grade_label || "").toLowerCase().includes(q) ||
        (c.room_number || "").toLowerCase().includes(q),
    );
  }, [classes, query]);

  function handleExportExcel() {
    if (!filtered || filtered.length === 0) {
      setToast({ msg: "Không có dữ liệu lớp để xuất", tone: "warn" });
      return;
    }
    const headers = ["Tên lớp", "Khối", "Phòng", "Sĩ số tối đa", "Số học sinh"];
    const rows = filtered.map((c) => [
      c.name,
      c.grade_label || "",
      c.room_number || "",
      c.capacity != null ? String(c.capacity) : "",
      c.student_count != null ? String(c.student_count) : "",
    ]);
    exportToExcel("danh_sach_lop.xlsx", "Lop", headers, rows);
    setToast({ msg: `Đã xuất ${rows.length} lớp ra file Excel`, tone: "ok" });
  }

  function openCreate() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setDrawerOpen(true);
  }

  function openEdit(c: SchoolClass) {
    setEditing(c);
    setForm({
      name: c.name,
      grade_label: c.grade_label || "",
      room_number: c.room_number || "",
      capacity: c.capacity != null ? String(c.capacity) : "",
    });
    setDrawerOpen(true);
  }

  function toPayload(): ClassPayload | null {
    const name = form.name.trim();
    if (!name) {
      setToast({ msg: "Vui lòng nhập tên lớp", tone: "bad" });
      return null;
    }
    const room = form.room_number.trim();
    if (room) {
      const dupRoom = (classes || []).find(
        (c) =>
          c.room_number &&
          c.room_number.trim().toLowerCase() === room.toLowerCase() &&
          (!editing || c.id !== editing.id)
      );
      if (dupRoom) {
        setToast({
          msg: `Phòng "${room}" đã được sử dụng cho "${dupRoom.name}". Vui lòng chọn phòng khác!`,
          tone: "bad",
        });
        return null;
      }
    }
    let capacity: number | null = null;
    if (form.capacity.trim()) {
      capacity = Number(form.capacity.trim());
      if (!Number.isInteger(capacity) || capacity <= 0) {
        setToast({ msg: "Sĩ số tối đa phải là số nguyên dương", tone: "bad" });
        return null;
      }
    }
    return {
      name,
      grade_label: form.grade_label.trim() || null,
      room_number: room || null,
      capacity,
    };
  }

  async function handleSave() {
    const payload = toPayload();
    if (!payload) return;
    setSaving(true);
    try {
      if (editing) {
        await updateClass(editing.id, payload);
        setToast({ msg: "Đã cập nhật lớp", tone: "ok" });
      } else {
        await createClass(payload);
        setToast({ msg: "Đã tạo lớp mới", tone: "ok" });
      }
      setDrawerOpen(false);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.detail || err?.message || "Không thể lưu lớp", tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(c: SchoolClass) {
    try {
      await deleteClass(c.id);
      setToast({ msg: `Đã xóa lớp ${c.name}`, tone: "ok" });
      setSelectedIds((prev) => prev.filter((id) => id !== c.id));
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa lớp", tone: "bad" });
    }
    setConfirmDel(null);
  }

  const allSelected =
    filtered.length > 0 && filtered.every((c) => selectedIds.includes(c.id));
  const someSelected = selectedIds.length > 0 && !allSelected;

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
      const res = await deleteClassesBatch(selectedIds);
      setToast({ msg: res.message || `Đã xóa ${selectedIds.length} lớp`, tone: res.blocked && res.blocked.length > 0 ? "warn" : "ok" });
      setSelectedIds([]);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa hàng loạt lớp", tone: "bad" });
    } finally {
      setBulkDeleting(false);
      setConfirmBulkDel(false);
    }
  }

  if (!ready) return null;

  return (
    <SchoolAdminLayout
      active="features"
      pageTitle="Quản lý lớp học"
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
          <button onClick={openCreate} className="kbtn kbtn-primary">
            + Thêm lớp
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3 flex flex-col sm:flex-row gap-2.5 items-stretch sm:items-center">
        <div className="flex-1">
          <SearchBar
            value={query}
            onChange={setQuery}
            placeholder="Tìm lớp, khối, phòng..."
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
            <span>Đã chọn {selectedIds.length} lớp</span>
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
        {!classes && !classesError ? (
          <Spinner />
        ) : classesError ? (
          <div className="text-center py-12">
            <div className="text-bad font-semibold mb-2">
              {(classesError as any)?.status === 401
                ? "Phiên đăng nhập đã hết hạn. Đang chuyển về trang đăng nhập..."
                : `Không thể tải danh sách lớp (${(classesError as any)?.detail || "Vui lòng thử lại"})`}
            </div>
            <button onClick={() => mutate()} className="kbtn kbtn-secondary mt-2">
              Thử lại
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-5xl mb-2">🏫</div>
            <div className="text-ink font-semibold">Chưa có lớp nào</div>
            <div className="text-sm text-ink-soft mt-1">
              {query ? "Không có kết quả phù hợp." : 'Bấm "+ Thêm lớp" để tạo mới.'}
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
                      title="Chọn tất cả lớp hiển thị"
                    />
                  </th>
                  <th className="px-4 py-3 text-left font-semibold">Tên lớp</th>
                  <th className="px-4 py-3 text-left font-semibold">Khối</th>
                  <th className="px-4 py-3 text-left font-semibold">Phòng</th>
                  <th className="px-4 py-3 text-left font-semibold">Sĩ số</th>
                  <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((c, idx) => {
                  const isSelected = selectedIds.includes(c.id);
                  const count = c.student_count ?? 0;
                  const full = c.capacity != null && count >= c.capacity;
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
                        <a
                          href={`/school-admin/students?class=${c.id}`}
                          className="flex items-center gap-2.5 group"
                          title={`Xem học sinh lớp ${c.name}`}
                        >
                          <div
                            className="w-9 h-9 flex items-center justify-center rounded-full font-bold text-white"
                            style={{ background: "#16665a" }}
                          >
                            {c.name.charAt(0).toUpperCase()}
                          </div>
                          <div className="font-bold text-ink group-hover:underline">{c.name}</div>
                        </a>
                      </td>
                      <td className="px-4 py-3">
                        {c.grade_label ? (
                          <Pill tone="brand">{c.grade_label}</Pill>
                        ) : (
                          <span className="text-xs text-ink-faint">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <div className="text-ink">{c.room_number || "—"}</div>
                      </td>
                      <td className="px-4 py-3">
                        <Pill tone={full ? "warn" : "ok"}>
                          {count}{c.capacity != null ? `/${c.capacity}` : " bé"}
                        </Pill>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button onClick={() => openEdit(c)} className="kbtn kbtn-ghost text-xs">
                          Sửa
                        </button>
                        <button
                          onClick={() => setConfirmDel(c)}
                          className="kbtn kbtn-ghost text-xs text-bad"
                          title={count > 0 ? `Lớp còn ${count} bé — phải chuyển hết mới xóa được` : "Xóa lớp"}
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
        Tổng: <span className="font-bold text-ink">{filtered.length}</span> lớp
      </div>

      {/* Drawer chỉnh sửa */}
      <Drawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={editing ? "Chỉnh sửa lớp" : "Thêm lớp mới"}
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
              {saving ? "Đang lưu..." : editing ? "Lưu thay đổi" : "Tạo lớp"}
            </button>
          </>
        }
      >
        <FormField label="Tên lớp" required>
          <input
            className="kinput"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Lớp Mầm 1"
          />
        </FormField>
        <FormField label="Khối">
          <select
            className="kinput"
            value={GRADE_OPTIONS.includes(form.grade_label) ? form.grade_label : form.grade_label ? "Khác" : ""}
            onChange={(e) => {
              const v = e.target.value;
              setForm({ ...form, grade_label: v === "Khác" ? form.grade_label : v });
            }}
          >
            <option value="">— Chọn khối —</option>
            {GRADE_OPTIONS.map((g) => (
              <option key={g} value={g}>{g}</option>
            ))}
          </select>
          {(!GRADE_OPTIONS.includes(form.grade_label) || form.grade_label === "Khác") && (
            <input
              className="kinput mt-2"
              value={form.grade_label === "Khác" ? "" : form.grade_label}
              onChange={(e) => setForm({ ...form, grade_label: e.target.value })}
              placeholder="Nhập tên khối..."
            />
          )}
        </FormField>
        <FormField label="Phòng" hint="Mỗi lớp học 1 phòng riêng, không được trùng nhau">
          <input
            className="kinput"
            value={form.room_number}
            onChange={(e) => setForm({ ...form, room_number: e.target.value })}
            placeholder="P.101"
          />
        </FormField>
        <FormField label="Sĩ số tối đa" hint="Bỏ trống nếu không giới hạn">
          <input
            className="kinput"
            type="number"
            min={1}
            value={form.capacity}
            onChange={(e) => setForm({ ...form, capacity: e.target.value })}
            placeholder="30"
          />
        </FormField>
        {editing && (editing.student_count ?? 0) > 0 && (
          <div className="text-xs rounded-control px-3 py-2" style={{ background: "#F6EED9", color: "#8A5E12" }}>
            Lớp đang có {editing.student_count} bé — không xóa được cho đến khi chuyển hết các bé sang lớp khác.
          </div>
        )}
      </Drawer>

      <ConfirmDialog
        open={!!confirmDel}
        title="Xóa lớp?"
        message={
          (confirmDel?.student_count ?? 0) > 0
            ? `Lớp "${confirmDel?.name}" còn ${confirmDel?.student_count} học sinh nên KHÔNG xóa được. Vui lòng chuyển các bé sang lớp khác trước.`
            : `Bạn có chắc muốn xóa lớp "${confirmDel?.name}"? Thao tác này không thể hoàn tác.`
        }
        confirmLabel="Xóa"
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      <ConfirmDialog
        open={confirmBulkDel}
        title={`Xóa ${selectedIds.length} lớp đã chọn?`}
        message="Chỉ những lớp đã hết học sinh mới bị xóa. Các lớp còn bé sẽ được giữ lại và báo rõ."
        confirmLabel={bulkDeleting ? "Đang xóa..." : `Xóa ${selectedIds.length} lớp`}
        onConfirm={handleBulkDelete}
        onCancel={() => !bulkDeleting && setConfirmBulkDel(false)}
      />

      {toast && <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />}
    </SchoolAdminLayout>
  );
}
