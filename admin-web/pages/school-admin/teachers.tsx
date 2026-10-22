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

export default function SchoolAdminTeachersPage() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState("");
  const [selectedClassId, setSelectedClassId] = useState("");
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
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

  const { data: teachers, error: teachersError, mutate } = useSWR<Teacher[]>(
    ready ? "teachers" : null,
    () => getTeachers(),
    { refreshInterval: 30000 },
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
      const username = row[4]?.trim() || null;
      const password = row[5]?.trim() || null;

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
      setSelectedIds((prev) => prev.filter((id) => id !== t.id));
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
      active="features"
      pageTitle="Quản lý giáo viên"
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
            + Thêm giáo viên
          </button>
        </div>
      }
    >
      <div className="card p-3 mb-3 flex flex-col sm:flex-row gap-2.5 items-stretch sm:items-center">
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
            <span>Đã chọn {selectedIds.length} giáo viên</span>
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
                </thead>
                <tbody>
                  {filtered.map((t, idx) => {
                    const isSelected = selectedIds.includes(t.id);
                    return (
                    <tr
                      key={t.id}
                      className={`${idx > 0 ? "border-t border-line" : ""} ${
                        isSelected ? "bg-[#FDF8F6]" : ""
                      }`}
                    >
                      <td className="px-3 py-3 text-center">
                        <input
                          type="checkbox"
                          className="rounded cursor-pointer"
                          checked={isSelected}
                          onChange={() => toggleSelect(t.id)}
                        />
                      </td>
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
                  );
                })}
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
        description="Tải lên file Excel (.xlsx, .xls) hoặc CSV để thêm hàng loạt giáo viên vào trường."
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