/**
 * pages/school-admin/students.tsx
 * ===============================
 * CRUD học sinh — UI y hệt Flutter app:
 *   - Search + Add + Refresh.
 *   - Bảng danh sách học sinh.
 *   - Drawer: Họ tên, biệt danh, lớp, phụ huynh liên kết (multi), giới tính, ngày sinh, dị ứng.
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
import { getStoredSchoolAdmin, getToken } from "@/lib/api";
import {
  Child,
  ChildPayload,
  Parent,
  SchoolClass,
  createChild,
  deleteChild,
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
  status: "enrolled",
};

export default function SchoolAdminStudentsPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [parents, setParents] = useState<Parent[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editing, setEditing] = useState<Child | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Child | null>(null);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "brand" } | null>(null);

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

  const { data: children, mutate } = useSWR<Child[]>(
    ready ? "students" : null,
    () => getChildren(),
    { refreshInterval: 30000 },
  );

  const filtered = useMemo(() => {
    const list = children ?? [];
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter(
      (c) =>
        c.full_name.toLowerCase().includes(q) ||
        (c.nickname || "").toLowerCase().includes(q) ||
        c.class_name.toLowerCase().includes(q) ||
        (c.parents_summary || "").toLowerCase().includes(q) ||
        (c.note || "").toLowerCase().includes(q),
    );
  }, [children, query]);

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
      status: c.status,
    });
    setDrawerOpen(true);
  }

  async function handleSave() {
    if (!form.full_name.trim()) {
      setToast({ msg: "Vui lòng nhập họ tên học sinh", tone: "bad" });
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
        status: form.status,
      };
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

  async function handleDelete(c: Child) {
    try {
      await deleteChild(c.id);
      setToast({ msg: `Đã xóa ${c.full_name}`, tone: "ok" });
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
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
        <div className="flex gap-2">
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
          <button onClick={openCreate} className="kbtn kbtn-primary">
            + Thêm học sinh
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3">
        <SearchBar
          value={query}
          onChange={setQuery}
          placeholder="Tìm học sinh, lớp, dị ứng, phụ huynh..."
        />
      </div>

      <div className="card overflow-hidden">
        {!children ? (
          <Spinner />
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
                  <th className="px-4 py-3 text-left font-semibold">Họ tên</th>
                  <th className="px-4 py-3 text-left font-semibold">Lớp</th>
                  <th className="px-4 py-3 text-left font-semibold">Phụ huynh</th>
                  <th className="px-4 py-3 text-left font-semibold">Ngày sinh</th>
                  <th className="px-4 py-3 text-left font-semibold">Ghi chú</th>
                  <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((c, idx) => (
                  <tr key={c.id} className={idx > 0 ? "border-t border-line" : ""}>
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
                    <td className="px-4 py-3 text-ink-soft max-w-xs line-clamp-2">
                      {c.note || "—"}
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
                ))}
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
          <select
            className="kinput"
            value={form.class_id ?? ""}
            onChange={(e) => setForm({ ...form, class_id: e.target.value || null })}
          >
            <option value="">-- Chọn lớp --</option>
            {classes.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name} {c.grade_label && `(${c.grade_label})`}
              </option>
            ))}
          </select>
        </FormField>
        <FormField label="Ngày sinh">
          <input
            type="date"
            className="kinput"
            value={form.date_of_birth}
            onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })}
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
        <FormField label="Dị ứng / Ghi chú y tế">
          <textarea
            className="kinput"
            rows={3}
            value={form.medical_allergies}
            onChange={(e) => setForm({ ...form, medical_allergies: e.target.value })}
            placeholder="VD: Dị ứng đậu phộng..."
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
            <option value="transferred">Chuyển trường</option>
            <option value="withdrawn">Thôi học</option>
          </select>
        </FormField>
      </Drawer>

      <ConfirmDialog
        open={!!confirmDel}
        title="Xóa học sinh?"
        message={`Bạn có chắc muốn xóa "${confirmDel?.full_name}"? Toàn bộ liên kết phụ huynh sẽ bị xóa.`}
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}

function formatDate(iso: string) {
  // iso yyyy-mm-dd → dd/mm/yyyy
  if (!iso) return "—";
  const parts = iso.split("-");
  if (parts.length !== 3) return iso;
  return `${parts[2]}/${parts[1]}/${parts[0]}`;
}