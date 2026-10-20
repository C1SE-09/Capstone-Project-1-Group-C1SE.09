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
} from "@/components/ui-school";
import { getStoredSchoolAdmin, getToken } from "@/lib/api";
import {
  Child,
  ChildPayload,
  Parent,
  ParentPayload,
  createParent,
  deleteParent,
  getChildren,
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

export default function SchoolAdminParentsPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [children, setChildren] = useState<Child[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editing, setEditing] = useState<Parent | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Parent | null>(null);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "brand" } | null>(null);

  useEffect(() => {
    if (!getToken() || !getStoredSchoolAdmin()) {
      window.location.href = "/login";
      return;
    }
    setReady(true);
    getChildren()
      .then(setChildren)
      .catch(() => []);
  }, []);

  const { data: parents, mutate } = useSWR<Parent[]>(
    ready ? "parents" : null,
    () => getParents(),
    { refreshInterval: 30000 },
  );

  const filtered = useMemo(() => {
    const list = parents ?? [];
    const q = query.toLowerCase().trim();
    if (!q) return list;
    return list.filter(
      (p) =>
        p.full_name.toLowerCase().includes(q) ||
        p.phone.toLowerCase().includes(q) ||
        p.email.toLowerCase().includes(q) ||
        (p.username || "").toLowerCase().includes(q) ||
        (p.children_summary || "").toLowerCase().includes(q),
    );
  }, [parents, query]);

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

  async function handleDelete(p: Parent) {
    try {
      await deleteParent(p.id);
      setToast({ msg: `Đã xóa ${p.full_name}`, tone: "ok" });
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
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
            + Thêm phụ huynh
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3">
        <SearchBar
          value={query}
          onChange={setQuery}
          placeholder="Tìm phụ huynh, số điện thoại, con liên kết..."
        />
      </div>

      <div className="card overflow-hidden">
        {!parents ? (
          <Spinner />
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
                  <th className="px-4 py-3 text-left font-semibold">Họ tên</th>
                  <th className="px-4 py-3 text-left font-semibold">SĐT / Quan hệ</th>
                  <th className="px-4 py-3 text-left font-semibold">Con liên kết</th>
                  <th className="px-4 py-3 text-left font-semibold">Tài khoản</th>
                  <th className="px-4 py-3 text-left font-semibold">Trạng thái</th>
                  <th className="px-4 py-3 text-right font-semibold">Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((p, idx) => (
                  <tr key={p.id} className={idx > 0 ? "border-t border-line" : ""}>
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
                      {p.children_summary || "Chưa liên kết"}
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
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="text-xs text-ink-faint mt-2">
        Tổng: <span className="font-bold text-ink">{filtered.length}</span> phụ huynh
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
        message={`Bạn có chắc muốn xóa "${confirmDel?.full_name}"? Liên kết với học sinh sẽ được gỡ.`}
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}