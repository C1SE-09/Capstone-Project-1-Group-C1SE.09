/**
 * pages/school-admin/schedules.tsx
 * ================================
 * Trang thời khóa biểu — y hệt Flutter app:
 *   - Chọn lớp (chỉ 1 vì admin trường tạo TKB cho từng lớp).
 *   - Tab Thứ 2 → Thứ 6.
 *   - Cảnh báo xung đột phòng + khung giờ.
 *   - Drawer thêm/sửa lịch.
 */

import { useEffect, useMemo, useState } from "react";
import useSWR from "swr";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import {
  Drawer,
  FormField,
  Pill,
  Spinner,
  Toast,
  ConfirmDialog,
} from "@/components/ui-school";
import { getStoredSchoolAdmin, getToken } from "@/lib/api";
import {
  Schedule,
  SchedulePayload,
  SchoolClass,
  TimeSlot,
  createSchedule,
  deleteSchedule,
  getClasses,
  getSchedules,
  getTimeSlots,
  updateSchedule,
} from "@/lib/admin-api";

const DAY_LABELS = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6"];
const DAY_SHORT = ["T2", "T3", "T4", "T5", "T6"];

interface FormState {
  activity_name: string;
  content: string;
  room_name: string;
  slot_id: string | null;
  start_time: string;
  end_time: string;
  day_of_week: number;
}

const EMPTY_FORM: FormState = {
  activity_name: "",
  content: "",
  room_name: "",
  slot_id: null,
  start_time: "",
  end_time: "",
  day_of_week: 2,
};

export default function SchoolAdminSchedulesPage() {
  const [ready, setReady] = useState(false);
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [selectedClassId, setSelectedClassId] = useState<string | null>(null);
  const [selectedDay, setSelectedDay] = useState(0); // index 0..4
  const [query, setQuery] = useState("");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editing, setEditing] = useState<Schedule | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [confirmDel, setConfirmDel] = useState<Schedule | null>(null);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "warn" | "brand" } | null>(null);

  useEffect(() => {
    if (!getToken() || !getStoredSchoolAdmin()) {
      window.location.href = "/login";
      return;
    }
    setReady(true);
    getClasses().then((c) => {
      setClasses(c);
      if (c.length > 0 && !selectedClassId) setSelectedClassId(c[0].id);
    });
  }, []);

  const dayOfWeek = selectedDay + 2; // backend expects 2..6 (Mon..Fri)

  const { data: schedules, mutate } = useSWR<Schedule[]>(
    ready && selectedClassId ? ["schedules", dayOfWeek] : null,
    () => getSchedules(dayOfWeek),
    { refreshInterval: 30000 },
  );

  const { data: timeSlots } = useSWR<TimeSlot[]>(
    ready ? "time-slots" : null,
    () => getTimeSlots(),
  );

  // Tính xung đột cùng phòng + khung giờ đè
  const conflicts = useMemo(() => {
    const list = schedules ?? [];
    const seen = new Set<string>();
    const result: Schedule[] = [];
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        if (!a.room_name.trim() || !b.room_name.trim()) continue;
        if (a.room_name.trim().toLowerCase() !== b.room_name.trim().toLowerCase()) continue;
        if (!a.start_time || !b.start_time || !a.end_time || !b.end_time) continue;
        const aS = toMin(a.start_time);
        const aE = toMin(a.end_time);
        const bS = toMin(b.start_time);
        const bE = toMin(b.end_time);
        if (aS < bE && aE > bS) {
          if (!seen.has(a.id)) {
            result.push(a);
            seen.add(a.id);
          }
          if (!seen.has(b.id)) {
            result.push(b);
            seen.add(b.id);
          }
        }
      }
    }
    return result;
  }, [schedules]);

  const filteredSchedules = useMemo(() => {
    const list = (schedules ?? []).slice().sort((a, b) =>
      (a.start_time || "").localeCompare(b.start_time || ""),
    );
    const search = query.toLowerCase().trim();
    if (!search) return list;
    return list.filter(
      (s) =>
        s.activity_name.toLowerCase().includes(search) ||
        s.room_name.toLowerCase().includes(search) ||
        s.time_range.toLowerCase().includes(search) ||
        (s.start_time || "").toLowerCase().includes(search),
    );
  }, [schedules, query]);

  function openCreate(forDay: number) {
    setEditing(null);
    setForm({ ...EMPTY_FORM, day_of_week: forDay + 2 });
    setDrawerOpen(true);
  }

  function openEdit(s: Schedule, forDay: number) {
    setEditing(s);
    setForm({
      activity_name: s.activity_name,
      content: s.content,
      room_name: s.room_name,
      slot_id: s.slot_id,
      start_time: s.start_time || "",
      end_time: s.end_time || "",
      day_of_week: s.day_of_week,
    });
    setDrawerOpen(true);
  }

  async function handleSave() {
    if (!form.activity_name.trim()) {
      setToast({ msg: "Vui lòng nhập tên hoạt động", tone: "bad" });
      return;
    }
    if (!form.slot_id && (!form.start_time || !form.end_time)) {
      setToast({ msg: "Vui lòng chọn khung giờ hoặc nhập giờ bắt đầu/kết thúc", tone: "bad" });
      return;
    }
    setSaving(true);
    try {
      const payload: SchedulePayload = {
        activity_name: form.activity_name.trim(),
        content: form.content.trim() || null,
        room_name: form.room_name.trim() || "Phòng học",
        slot_id: form.slot_id,
        start_time: form.slot_id ? null : form.start_time || null,
        end_time: form.slot_id ? null : form.end_time || null,
        day_of_week: form.day_of_week,
      };
      if (editing) {
        await updateSchedule(editing.id, payload);
        setToast({ msg: "Đã cập nhật hoạt động", tone: "ok" });
      } else {
        await createSchedule(payload);
        setToast({ msg: "Đã thêm hoạt động", tone: "ok" });
      }
      setDrawerOpen(false);
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể lưu hoạt động", tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(s: Schedule) {
    try {
      await deleteSchedule(s.id);
      setToast({ msg: "Đã xóa hoạt động", tone: "ok" });
      mutate();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
  }

  function pickSlot(slot: TimeSlot) {
    setForm({
      ...form,
      slot_id: slot.id,
      start_time: slot.start_time,
      end_time: slot.end_time,
    });
  }

  if (!ready) return null;

  return (
    <SchoolAdminLayout
      active="features"
      pageTitle="Thời khóa biểu"
      pageAction={
        <button onClick={() => openCreate(selectedDay)} className="kbtn kbtn-primary">
          + Thêm hoạt động
        </button>
      }
    >
      <p className="text-sm text-ink-soft -mt-3 mb-4">
        Lên lịch hoạt động cho từng lớp theo tuần. Hệ thống tự động phát hiện xung
        đột phòng/khung giờ.
      </p>

      {/* Class selector */}
      {classes.length > 0 && (
        <div
          className="card p-3 mb-4 flex items-center gap-3"
          style={{ background: "#EFECE5" }}
        >
          <span className="text-sm font-semibold text-ink">Lớp:</span>
          <select
            className="kinput"
            style={{ maxWidth: 280 }}
            value={selectedClassId ?? ""}
            onChange={(e) => setSelectedClassId(e.target.value || null)}
          >
            {classes.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name} {c.grade_label && `(${c.grade_label})`}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Day tabs */}
      <div className="card mb-4 p-1.5 flex gap-1 overflow-x-auto">
        {DAY_LABELS.map((label, idx) => {
          const isActive = idx === selectedDay;
          return (
            <button
              key={label}
              onClick={() => setSelectedDay(idx)}
              className="flex-1 px-3 py-2 rounded-control text-sm font-semibold whitespace-nowrap transition"
              style={
                isActive
                  ? { background: "#16665a", color: "white" }
                  : { background: "transparent", color: "#605D57" }
              }
            >
              {label}
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="card p-3 mb-3">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Tìm hoạt động, phòng, khung giờ (vd: 08:00, 8h)..."
          className="kinput"
        />
      </div>

      {/* Conflict banner */}
      {conflicts.length > 0 && (
        <div
          className="mb-3 px-4 py-3 rounded-control flex items-center gap-3"
          style={{ background: "#F6EED9", border: "1px solid #B0791B" }}
        >
          <span className="text-2xl">⚠️</span>
          <div className="flex-1">
            <div className="font-bold text-sm" style={{ color: "#8A5E12" }}>
              {conflicts.length} xung đột phòng/khung giờ trong ngày {DAY_SHORT[selectedDay]}
            </div>
            <div className="text-xs" style={{ color: "#605D57" }}>
              Vui lòng điều chỉnh để tránh 2 hoạt động cùng phòng + cùng giờ.
            </div>
          </div>
        </div>
      )}

      {/* Schedule list */}
      <div className="card overflow-hidden">
        {!schedules ? (
          <Spinner />
        ) : filteredSchedules.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-5xl mb-2">📅</div>
            <div className="text-ink font-semibold">
              {query ? "Không tìm thấy hoạt động phù hợp" : `Chưa có hoạt động nào cho ${DAY_LABELS[selectedDay]}`}
            </div>
            <div className="text-sm text-ink-soft mt-1">
              Bấm "+ Thêm hoạt động" để tạo mới.
            </div>
          </div>
        ) : (
          <ul>
            {filteredSchedules.map((s, idx) => {
              const hasConflict = conflicts.some((c) => c.id === s.id);
              return (
                <li
                  key={s.id}
                  className={`flex items-start gap-3 px-4 py-3 ${idx > 0 ? "border-t border-line" : ""}`}
                >
                  <div
                    className="flex flex-col items-center justify-center rounded-control px-2.5 py-1 min-w-[80px]"
                    style={{ background: "#E6EFEC" }}
                  >
                    <div className="font-bold text-sm" style={{ color: "#16665a" }}>
                      {s.start_time || "--:--"}
                    </div>
                    <div className="text-[10px]" style={{ color: "#605D57" }}>
                      {s.end_time || "--:--"}
                    </div>
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <div className="font-bold text-ink">{s.activity_name}</div>
                      {hasConflict && (
                        <Pill tone="warn">⚠️ Xung đột</Pill>
                      )}
                    </div>
                    <div className="text-xs text-ink-soft mt-0.5">
                      {s.time_range && `Khung giờ: ${s.time_range}`}
                      {s.room_name && ` · Phòng: ${s.room_name}`}
                    </div>
                    {s.content && (
                      <div className="text-xs text-ink-soft mt-1 line-clamp-2">
                        {s.content}
                      </div>
                    )}
                  </div>
                  <div className="flex items-start gap-1">
                    <button
                      onClick={() => openEdit(s, selectedDay)}
                      className="kbtn kbtn-ghost text-xs"
                    >
                      Sửa
                    </button>
                    <button
                      onClick={() => setConfirmDel(s)}
                      className="kbtn kbtn-ghost text-xs text-bad"
                    >
                      Xóa
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <Drawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={editing ? "Chỉnh sửa hoạt động" : "Thêm hoạt động"}
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
              {saving ? "Đang lưu..." : "Lưu hoạt động"}
            </button>
          </>
        }
      >
        <FormField label="Tên hoạt động" required>
          <input
            className="kinput"
            value={form.activity_name}
            onChange={(e) => setForm({ ...form, activity_name: e.target.value })}
            placeholder="VD: Vẽ sáng tạo, Hát tập thể..."
          />
        </FormField>
        <FormField label="Thứ">
          <div className="flex gap-2 flex-wrap">
            {DAY_LABELS.map((label, idx) => (
              <button
                key={label}
                type="button"
                onClick={() => setForm({ ...form, day_of_week: idx + 2 })}
                className={`px-3 py-1.5 rounded-control text-xs font-semibold border ${
                  form.day_of_week === idx + 2
                    ? "text-white border-transparent"
                    : "bg-white text-ink border-line-strong"
                }`}
                style={form.day_of_week === idx + 2 ? { background: "#16665a" } : {}}
              >
                {label}
              </button>
            ))}
          </div>
        </FormField>
        <FormField label="Khung giờ có sẵn" hint="Click chọn — hệ thống tự điền giờ.">
          {timeSlots && timeSlots.length > 0 ? (
            <div className="flex flex-wrap gap-2">
              {timeSlots.map((slot) => (
                <button
                  key={slot.id}
                  type="button"
                  onClick={() => pickSlot(slot)}
                  className={`px-2.5 py-1.5 rounded-control text-xs font-semibold border ${
                    form.slot_id === slot.id
                      ? "text-white border-transparent"
                      : "bg-white text-ink border-line-strong"
                  }`}
                  style={form.slot_id === slot.id ? { background: "#16665a" } : {}}
                >
                  {slot.name}
                  <span className="text-[10px] opacity-80 ml-1">
                    ({slot.start_time}–{slot.end_time})
                  </span>
                </button>
              ))}
            </div>
          ) : (
            <div className="text-xs text-ink-faint">Chưa có khung giờ nào.</div>
          )}
        </FormField>
        <FormField label="Hoặc nhập giờ tự do">
          <div className="grid grid-cols-2 gap-2">
            <input
              type="time"
              className="kinput"
              value={form.start_time}
              onChange={(e) => setForm({ ...form, start_time: e.target.value, slot_id: null })}
              placeholder="Bắt đầu"
            />
            <input
              type="time"
              className="kinput"
              value={form.end_time}
              onChange={(e) => setForm({ ...form, end_time: e.target.value, slot_id: null })}
              placeholder="Kết thúc"
            />
          </div>
        </FormField>
        <FormField label="Phòng">
          <input
            className="kinput"
            value={form.room_name}
            onChange={(e) => setForm({ ...form, room_name: e.target.value })}
            placeholder="VD: Phòng Mầm A, Sân trường..."
          />
        </FormField>
        <FormField label="Nội dung chi tiết">
          <textarea
            className="kinput"
            rows={3}
            value={form.content}
            onChange={(e) => setForm({ ...form, content: e.target.value })}
            placeholder="Mô tả hoạt động..."
          />
        </FormField>
      </Drawer>

      <ConfirmDialog
        open={!!confirmDel}
        title="Xóa hoạt động?"
        message={`Bạn có chắc muốn xóa hoạt động "${confirmDel?.activity_name}"?`}
        onConfirm={() => confirmDel && handleDelete(confirmDel)}
        onCancel={() => setConfirmDel(null)}
      />

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}

function toMin(t: string): number {
  const [h, m] = t.split(":").map((x) => parseInt(x, 10));
  if (isNaN(h) || isNaN(m)) return 0;
  return h * 60 + m;
}