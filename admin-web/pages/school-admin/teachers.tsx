/**
 * pages/school-admin/teachers.tsx
 * ===============================
 * CRUD giáo viên — UI y hệt Flutter app:
 *   - Search bar + nút Thêm/Làm mới.
 *   - Bảng danh sách (desktop) / Cards (mobile).
 *   - Drawer chỉnh sửa với các trường: Họ tên, Email, SĐT, Lớp, Username, Password.
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
  Teacher,
  TeacherPayload,
  SchoolClass,
  createTeacher,
  deleteTeacher,
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

export default function SchoolAdminTeachersPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editing, setEditing] = useState<Teacher | null>(null);
  const [form, setForm] = useState<TeacherFormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Teacher | null>(null);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "brand" } | null>(null);

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

  const { data: teachers, mutate } = useSWR<Teacher[]>(
    ready ? "teachers" : null,
    () => getTeachers(),
    { refreshInterval: 30000 },
  );

  const filtered = useMemo(() => {
    const list = teachers ?? [];
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter(
      (t) =>
        t.full_name.toLowerCase().includes(q) ||
        t.email.toLowerCase().includes(q) ||
        t.phone.toLowerCase().includes(q) ||
        t.class_name.toLowerCase().includes(q),
    );
  }, [teachers, query]);

  function openCreate() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setDrawerOpen(true);
  }

  function openEdit(t: Teacher) {
    setEditing(t);
    setForm({
      full_name: t.full_name,
      email: t.email,
      phone: t.phone,
      class_id: t.class_id,
      class_ids: t.class_ids,
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
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
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
      active="features"
      pageTitle="Quản lý giáo viên"
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
            + Thêm giáo viên
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3">
        <SearchBar
          value={query}
          onChange={setQuery}
          placeholder="Tìm giáo viên, số điện thoại, lớp..."
        />
      </div>

      <div className="card overflow-hidden">
        {!teachers ? (
          <Spinner />
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
              <table className="w-full text-sm">
                <thead
                  className="text-xs uppercase tracking-wider"
                  style={{ background: "#EFECE5", color: "#605D57" }}
                >
                  <tr>
                    <th className="px-4 py-3 text-left font-semibold">Họ tên</th>
                    <th className="px-4 py-3 text-left font-semibold">Email / SĐT</th>
                    <th className="px-4 py-3 text-left font-semibold">Lớp phụ trách</th>
                    <th className="px-4 py-3 text-left font-semibold">Tài khoản</th>
                    <th className="px-4 py-3 text-left font-semibold">Trạng thái</th>
                    <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((t, idx) => (
                    <tr
                      key={t.id}
                      className={idx > 0 ? "border-t border-line" : ""}
                    >
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2.5">
                          <div
                            className="w-9 h-9 flex items-center justify-center rounded-full font-bold text-white"
                            style={{ background: "#16665a" }}
                          >
                            {t.full_name.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <div className="font-bold text-ink">
                              {t.full_name}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="text-ink">{t.email}</div>
                        <div className="text-xs text-ink-soft">{t.phone}</div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="text-ink">{t.class_name || "Chưa phân lớp"}</div>
                      </td>
                      <td className="px-4 py-3">
                        {t.username ? (
                          <Pill tone="brand">@{t.username}</Pill>
                        ) : (
                          <span className="text-xs text-ink-faint">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <Pill tone={t.status === "active" ? "ok" : t.status === "on_leave" ? "warn" : "neutral"}>
                          {t.status === "active"
                            ? "Đang dạy"
                            : t.status === "on_leave"
                              ? "Nghỉ phép"
                              : "Ngừng"}
                        </Pill>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => openEdit(t)}
                          className="kbtn kbtn-ghost text-xs"
                        >
                          Sửa
                        </button>
                        <button
                          onClick={() => setConfirmDel(t)}
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

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}