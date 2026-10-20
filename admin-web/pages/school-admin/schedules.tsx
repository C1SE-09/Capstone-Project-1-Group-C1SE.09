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
  const [highlightedId, setHighlightedId] = useState<string | null>(null);
  const [conflictCycleIndex, setConflictCycleIndex] = useState(0);
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

  const classMap = useMemo(() => new Map(classes.map((c) => [c.id, c.name])), [classes]);

  // Tải tất cả lịch trong trường để kiểm tra xung đột phòng và trùng lịch tuần
  const { data: allSchedules, mutate: mutateAll } = useSWR<Schedule[]>(
    ready ? "all-schedules" : null,
    () => getSchedules(),
    { refreshInterval: 30000 },
  );

  const dayOfWeek = selectedDay + 2; // backend expects 2..6 (Mon..Fri)

  const { data: directDaySchedules, mutate: mutateDay } = useSWR<Schedule[]>(
    ready && selectedClassId ? ["schedules", selectedClassId, dayOfWeek] : null,
    () => getSchedules(selectedClassId, dayOfWeek),
    { refreshInterval: 30000 },
  );

  const schedules = useMemo(() => {
    if (directDaySchedules) return directDaySchedules;
    if (!allSchedules || !selectedClassId) return undefined;
    return allSchedules.filter(
      (s) => s.class_id === selectedClassId && s.day_of_week === dayOfWeek,
    );
  }, [directDaySchedules, allSchedules, selectedClassId, dayOfWeek]);

  const { data: timeSlots } = useSWR<TimeSlot[]>(
    ready ? "time-slots" : null,
    () => getTimeSlots(),
  );

  // Xác định lý do xung đột cho từng tiết của lớp đang chọn
  const conflictReasons = useMemo(() => {
    const reasons = new Map<string, string>();
    if (!allSchedules || !selectedClassId) return reasons;

    const classScheds = allSchedules.filter((s) => s.class_id === selectedClassId);

    for (const a of classScheds) {
      if (!a.start_time || !a.end_time) continue;
      const aS = toMin(a.start_time);
      const aE = toMin(a.end_time);

      for (const b of allSchedules) {
        if (b.id === a.id || b.day_of_week !== a.day_of_week) continue;
        if (!b.start_time || !b.end_time) continue;
        const bS = toMin(b.start_time);
        const bE = toMin(b.end_time);

        // Trùng giờ
        if (aS < bE && aE > bS) {
          const sameClass = b.class_id === a.class_id;
          const sameRoom = Boolean(
            a.room_name &&
            b.room_name &&
            a.room_name.trim().toLowerCase() === b.room_name.trim().toLowerCase(),
          );

          if (sameClass) {
            reasons.set(
              a.id,
              `Trùng khung giờ với "${b.activity_name}" (${b.start_time} - ${b.end_time})`,
            );
            break;
          } else if (sameRoom) {
            const otherClassName = (b.class_id && classMap.get(b.class_id)) || "lớp khác";
            reasons.set(
              a.id,
              `Trùng phòng "${a.room_name}" với ${otherClassName} ("${b.activity_name}")`,
            );
            break;
          }
        }
      }
    }
    return reasons;
  }, [allSchedules, selectedClassId, classMap]);

  // Xung đột trong ngày đang chọn
  const conflicts = useMemo(() => {
    return (schedules ?? []).filter((s) => conflictReasons.has(s.id));
  }, [schedules, conflictReasons]);

  // Toàn bộ các tiết bị xung đột trong tuần của lớp này, sắp xếp theo gần hôm nay nhất
  const weeklyConflicts = useMemo(() => {
    if (!allSchedules || !selectedClassId) return [];
    const jsDay = new Date().getDay(); // 0: CN, 1: T2, ..., 6: T7
    const todayIndex = jsDay >= 1 && jsDay <= 5 ? jsDay - 1 : 0;

    const list = allSchedules.filter(
      (s) => s.class_id === selectedClassId && conflictReasons.has(s.id),
    );

    return list.slice().sort((a, b) => {
      const dayA = a.day_of_week - 2;
      const dayB = b.day_of_week - 2;
      const distA = (dayA - todayIndex + 5) % 5;
      const distB = (dayB - todayIndex + 5) % 5;
      if (distA !== distB) return distA - distB;
      return toMin(a.start_time || "") - toMin(b.start_time || "");
    });
  }, [allSchedules, selectedClassId, conflictReasons]);

  const nearestConflict = weeklyConflicts[0] || null;

  function jumpToConflict(targetSchedule?: Schedule) {
    if (weeklyConflicts.length === 0) return;
    const target = targetSchedule || weeklyConflicts[conflictCycleIndex % weeklyConflicts.length];
    if (!target) return;

    const targetDayIndex = target.day_of_week - 2;
    setSelectedDay(targetDayIndex);
    setQuery("");
    setHighlightedId(target.id);
    setConflictCycleIndex((prev) => (prev + 1) % weeklyConflicts.length);

    setTimeout(() => {
      const el = document.getElementById(`schedule-${target.id}`);
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "center" });
      }
    }, 150);

    setTimeout(() => {
      setHighlightedId((curr) => (curr === target.id ? null : curr));
    }, 4500);
  }

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
        class_id: selectedClassId,
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
      mutateDay();
      mutateAll();
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
      mutateDay();
      mutateAll();
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

      {/* Cảnh báo xung đột NẰM TRÊN PHẦN CHỌN LỚP */}
      {selectedClassId && allSchedules && (
        weeklyConflicts.length > 0 ? (
          <div
            onClick={() => jumpToConflict()}
            role="button"
            tabIndex={0}
            className="card p-3.5 mb-4 flex items-center justify-between gap-3 cursor-pointer transition-all duration-200 hover:shadow-md border select-none group"
            style={{
              background: "#FBF6ED",
              borderColor: "#D9A54C",
            }}
            title="Nhấn để nhảy tới tiết bị xung đột"
          >
            <div className="flex items-start gap-3 min-w-0">
              <span className="text-2xl shrink-0 mt-0.5 animate-pulse">⚠️</span>
              <div className="min-w-0">
                <div className="font-bold text-sm text-[#8A5E12] flex items-center gap-2 flex-wrap">
                  <span>Phát hiện {weeklyConflicts.length} tiết học bị xung đột trong tuần</span>
                  {weeklyConflicts.length > 1 && (
                    <span className="text-[11px] font-medium px-2 py-0.5 rounded-full bg-[#8A5E12]/15 text-[#8A5E12]">
                      Nhấn lần {(conflictCycleIndex % weeklyConflicts.length) + 1}/{weeklyConflicts.length}
                    </span>
                  )}
                </div>
                {nearestConflict && (
                  <div className="text-xs text-[#605D57] mt-1 line-clamp-1">
                    <strong className="text-[#8A5E12]">Gần hiện tại nhất:</strong>{" "}
                    <span className="font-semibold text-ink">
                      {(() => {
                        const nearestDayIndex = nearestConflict.day_of_week - 2;
                        const jsDay = new Date().getDay();
                        const todayIndex = jsDay >= 1 && jsDay <= 5 ? jsDay - 1 : 0;
                        if (nearestDayIndex === todayIndex) return `Hôm nay (${DAY_LABELS[nearestDayIndex]})`;
                        if (nearestDayIndex === (todayIndex + 1) % 5) return `Ngày mai (${DAY_LABELS[nearestDayIndex]})`;
                        return DAY_LABELS[nearestDayIndex];
                      })()}
                    </span>{" "}
                    ({nearestConflict.start_time} - {nearestConflict.end_time}):{" "}
                    <span className="font-medium text-ink">{nearestConflict.activity_name}</span>
                    {conflictReasons.get(nearestConflict.id) && (
                      <span className="text-[#8A5E12] ml-1">
                        · {conflictReasons.get(nearestConflict.id)}
                      </span>
                    )}
                  </div>
                )}
              </div>
            </div>
            <div
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-control text-xs font-bold text-white shrink-0 shadow-sm transition group-hover:scale-105"
              style={{ background: "#B0791B" }}
            >
              <span>Sửa tiết xung đột</span>
              <span className="text-sm transition group-hover:translate-x-0.5">→</span>
            </div>
          </div>
        ) : (
          <div
            className="card px-3.5 py-2.5 mb-4 flex items-center gap-2 text-xs font-medium"
            style={{ background: "#EDF5F2", color: "#16665A", borderColor: "#C4DCD3" }}
          >
            <span className="text-base">✅</span>
            <span>Không phát hiện xung đột phòng hoặc khung giờ trong tuần cho lớp này.</span>
          </div>
        )
      )}

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
              const hasConflict = conflictReasons.has(s.id);
              const reason = conflictReasons.get(s.id);
              const isHighlighted = highlightedId === s.id;
              return (
                <li
                  key={s.id}
                  id={`schedule-${s.id}`}
                  className={`flex items-start gap-3 px-4 py-3 transition-all duration-300 ${idx > 0 ? "border-t border-line" : ""
                    } ${isHighlighted
                      ? "bg-[#FFF9EE] ring-2 ring-[#B0791B] ring-offset-2 z-10 relative rounded-control shadow-sm"
                      : ""
                    }`}
                >
                  <div
                    className="flex flex-col items-center justify-center rounded-control px-2.5 py-1 min-w-[80px]"
                    style={{ background: isHighlighted ? "#FCEBCB" : "#E6EFEC" }}
                  >
                    <div className="font-bold text-sm" style={{ color: isHighlighted ? "#8A5E12" : "#16665a" }}>
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
                      {isHighlighted && (
                        <span className="text-[11px] px-2 py-0.5 rounded font-bold bg-[#B0791B] text-white animate-pulse">
                          Đang xem xung đột
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-ink-soft mt-0.5">
                      {s.time_range && `Khung giờ: ${s.time_range}`}
                      {s.room_name && ` · Phòng: ${s.room_name}`}
                    </div>
                    {hasConflict && reason && (
                      <div className="mt-1.5 text-xs text-[#8A5E12] font-semibold flex items-center gap-1.5 px-2.5 py-1 rounded bg-[#FBF6ED] border border-[#E2BF81] inline-block">
                        <span>⚠️</span>
                        <span>{reason}</span>
                      </div>
                    )}
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
                className={`px-3 py-1.5 rounded-control text-xs font-semibold border ${form.day_of_week === idx + 2
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
                  className={`px-2.5 py-1.5 rounded-control text-xs font-semibold border ${form.slot_id === slot.id
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