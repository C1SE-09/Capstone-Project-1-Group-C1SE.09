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
  ClassFilterSelect,
  ConfirmDialog,
  Drawer,
  FormField,
  ImportModal,
  ImportResult,
  Modal,
  Pill,
  Spinner,
  Toast,
} from "@/components/ui-school";
import { exportMultiSheetToExcel, exportToExcel, ExcelSheetData } from "@/lib/excel-helper";
import { clearToken, getStoredSchoolAdmin, getToken } from "@/lib/api";
import {
  Room,
  Schedule,
  SchedulePayload,
  SchoolClass,
  TimeSlot,
  createSchedule,
  deleteSchedule,
  deleteSchedulesBatch,
  getClasses,
  getRooms,
  getSchedules,
  getTimeSlots,
  updateSchedule,
} from "@/lib/admin-api";

const DAY_LABELS = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6"];
const DAY_SHORT = ["T2", "T3", "T4", "T5", "T6"];
const WORKING_HOURS_START = "07:00"; // Mở cửa đón trẻ
const WORKING_HOURS_END = "17:00"; // Hết giờ trả trẻ

const SHARED_KEYWORDS = [
  "sân cỏ",
  "sân trường",
  "sân chơi",
  "ngoài trời",
  "vườn",
  "bể bơi",
  "cát nước",
  "nhà ăn",
  "y tế",
];

function isSharedLocation(name?: string | null, roomsList?: Room[]): boolean {
  if (!name) return false;
  const n = name.trim().toLowerCase();
  if (roomsList && roomsList.length > 0) {
    const matched = roomsList.find((r) => r.name.trim().toLowerCase() === n);
    if (matched) return Boolean(matched.is_shared);
  }
  return SHARED_KEYWORDS.some((kw) => n.includes(kw));
}

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
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [confirmBulkDel, setConfirmBulkDel] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" | "warn" | "brand" } | null>(null);
  const [roomDropdownOpen, setRoomDropdownOpen] = useState(false);
  const [roomSearch, setRoomSearch] = useState("");
  const [schoolConflictsModalOpen, setSchoolConflictsModalOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [exportModalOpen, setExportModalOpen] = useState(false);
  const [exportConfig, setExportConfig] = useState<{
    scope: "current" | "all";
    format: "matrix" | "list";
    dayFilter: "all" | number;
    sessionFilter: "all" | "morning" | "afternoon";
  }>({
    scope: "current",
    format: "matrix",
    dayFilter: "all",
    sessionFilter: "all",
  });

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
  const currentClassName = selectedClassId ? classMap.get(selectedClassId) || "" : "";

  // Tải tất cả lịch trong trường để kiểm tra xung đột phòng và trùng lịch tuần
  const { data: allSchedules, error: allSchedulesError, mutate: mutateAll } = useSWR<Schedule[]>(
    ready ? "all-schedules" : null,
    () => getSchedules(),
    { refreshInterval: 30000 },
  );

  // Tải danh sách phòng/địa điểm của trường
  const { data: rooms } = useSWR<Room[]>(
    ready ? ["rooms", selectedClassId] : null,
    () => getRooms(selectedClassId),
  );

  const availableRooms: Room[] = useMemo(() => {
    if (rooms && rooms.length > 0) return rooms;
    return [
      {
        id: "def-classroom",
        name: currentClassName ? `Phòng học ${currentClassName}` : "Phòng học của lớp",
        room_type: "CLASSROOM",
        class_id: selectedClassId,
        is_shared: false,
      },
      { id: "def-art", name: "Phòng Mỹ thuật & Tạo hình", room_type: "FUNCTIONAL", class_id: null, is_shared: false },
      { id: "def-mus", name: "Phòng Âm nhạc & Vận động", room_type: "FUNCTIONAL", class_id: null, is_shared: false },
      { id: "def-phy", name: "Phòng Thể chất & Đa năng", room_type: "FUNCTIONAL", class_id: null, is_shared: false },
      { id: "def-it", name: "Phòng Tin học / Đa phương tiện", room_type: "FUNCTIONAL", class_id: null, is_shared: false },
      { id: "def-grass", name: "Sân cỏ", room_type: "OUTDOOR", class_id: null, is_shared: true },
      { id: "def-yard", name: "Sân trường", room_type: "OUTDOOR", class_id: null, is_shared: true },
      { id: "def-sand", name: "Khu vui chơi cát nước", room_type: "OUTDOOR", class_id: null, is_shared: true },
      { id: "def-garden", name: "Vườn cổ tích & Khám phá", room_type: "OUTDOOR", class_id: null, is_shared: true },
      { id: "def-meal", name: "Nhà ăn & Bếp bán trú", room_type: "COMMON", class_id: null, is_shared: true },
      { id: "def-med", name: "Phòng y tế", room_type: "COMMON", class_id: null, is_shared: true },
    ];
  }, [rooms, currentClassName, selectedClassId]);

  const filteredRoomGroups = useMemo(() => {
    const q = roomSearch.toLowerCase().trim();
    const matched = availableRooms.filter(
      (r) => !q || r.name.toLowerCase().includes(q) || r.room_type.toLowerCase().includes(q),
    );

    const dedicated = matched.filter(
      (r) => r.room_type === "CLASSROOM" || (selectedClassId && r.class_id === selectedClassId),
    );
    const functional = matched.filter(
      (r) => r.room_type === "FUNCTIONAL" && (!selectedClassId || r.class_id !== selectedClassId),
    );
    const outdoor = matched.filter((r) => r.room_type === "OUTDOOR");
    const common = matched.filter((r) => r.room_type === "COMMON");

    const groups: { icon: string; title: string; items: Room[] }[] = [];
    if (dedicated.length > 0) groups.push({ icon: "🏫", title: "Phòng lớp học", items: dedicated });
    if (functional.length > 0) groups.push({ icon: "🎨", title: "Phòng chức năng", items: functional });
    if (outdoor.length > 0) groups.push({ icon: "⚽", title: "Khu ngoài trời", items: outdoor });
    if (common.length > 0) groups.push({ icon: "🏢", title: "Khu vực sinh hoạt chung", items: common });

    return groups;
  }, [availableRooms, roomSearch, selectedClassId]);

  const exactMatchInList = useMemo(() => {
    const q = roomSearch.toLowerCase().trim();
    return availableRooms.some((r) => r.name.toLowerCase().trim() === q);
  }, [availableRooms, roomSearch]);

  const dayOfWeek = selectedDay + 2; // backend expects 2..6 (Mon..Fri)

  const { data: directDaySchedules, error: daySchedulesError, mutate: mutateDay } = useSWR<Schedule[]>(
    ready && selectedClassId ? ["schedules", selectedClassId, dayOfWeek] : null,
    () => getSchedules(selectedClassId, dayOfWeek),
    { refreshInterval: 30000 },
  );

  const scheduleError = daySchedulesError || allSchedulesError;

  useEffect(() => {
    if (scheduleError && (scheduleError as any).status === 401) {
      clearToken("schoolAdmin");
      window.location.href = "/login";
    }
  }, [scheduleError]);

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

  // Xác định lý do xung đột cho TẤT CẢ các tiết học trên toàn trường
  const allConflictReasons = useMemo(() => {
    const reasons = new Map<string, string>();
    if (!allSchedules || allSchedules.length === 0) return reasons;

    for (const a of allSchedules) {
      if (!a.start_time || !a.end_time) continue;
      const aS = toMin(a.start_time);
      const aE = toMin(a.end_time);

      for (const b of allSchedules) {
        if (b.id === a.id || b.day_of_week !== a.day_of_week) continue;
        if (!b.start_time || !b.end_time) continue;
        const bS = toMin(b.start_time);
        const bE = toMin(b.end_time);

        // Trùng khung giờ
        if (aS < bE && aE > bS) {
          const sameClass = b.class_id === a.class_id;
          const isShared = isSharedLocation(a.room_name, rooms);
          const sameRoom = Boolean(
            !isShared &&
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
  }, [allSchedules, classMap, rooms]);

  // Lý do xung đột của các tiết thuộc lớp đang chọn
  const conflictReasons = useMemo(() => {
    const reasons = new Map<string, string>();
    if (!allSchedules || !selectedClassId) return reasons;
    for (const s of allSchedules) {
      if (s.class_id === selectedClassId && allConflictReasons.has(s.id)) {
        reasons.set(s.id, allConflictReasons.get(s.id)!);
      }
    }
    return reasons;
  }, [allSchedules, selectedClassId, allConflictReasons]);

  // Thống kê và gom nhóm xung đột toàn trường theo từng lớp
  const schoolConflictStats = useMemo(() => {
    if (!allSchedules || allSchedules.length === 0) {
      return {
        totalConflicts: 0,
        roomConflicts: 0,
        timeConflicts: 0,
        classGroups: [] as {
          classId: string;
          className: string;
          gradeLabel?: string;
          conflicts: {
            schedule: Schedule;
            reason: string;
            dayLabel: string;
            timeRange: string;
          }[];
          earliestDayIndex: number;
        }[],
      };
    }

    const groupsMap = new Map<
      string,
      {
        classId: string;
        className: string;
        gradeLabel?: string;
        conflicts: {
          schedule: Schedule;
          reason: string;
          dayLabel: string;
          timeRange: string;
        }[];
        earliestDayIndex: number;
      }
    >();

    let totalConflicts = 0;
    let roomConflicts = 0;
    let timeConflicts = 0;

    for (const s of allSchedules) {
      const reason = allConflictReasons.get(s.id);
      if (!reason) continue;

      totalConflicts++;
      if (reason.includes("Trùng phòng")) {
        roomConflicts++;
      } else {
        timeConflicts++;
      }

      const cid = s.class_id || "unassigned";
      const cName = s.class_id ? (classMap.get(s.class_id) || "Lớp học") : "Chưa phân lớp";
      const matchingClass = classes.find((c) => c.id === s.class_id);

      if (!groupsMap.has(cid)) {
        groupsMap.set(cid, {
          classId: cid,
          className: cName,
          gradeLabel: matchingClass?.grade_label,
          conflicts: [],
          earliestDayIndex: Math.max(0, Math.min(4, s.day_of_week - 2)),
        });
      }

      const group = groupsMap.get(cid)!;
      const dayIdx = Math.max(0, Math.min(4, s.day_of_week - 2));
      if (dayIdx < group.earliestDayIndex) {
        group.earliestDayIndex = dayIdx;
      }

      group.conflicts.push({
        schedule: s,
        reason,
        dayLabel: DAY_LABELS[dayIdx] || `Thứ ${s.day_of_week}`,
        timeRange: s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : ""),
      });
    }

    const classGroups = Array.from(groupsMap.values());
    for (const g of classGroups) {
      g.conflicts.sort((a, b) => {
        if (a.schedule.day_of_week !== b.schedule.day_of_week) {
          return a.schedule.day_of_week - b.schedule.day_of_week;
        }
        return toMin(a.schedule.start_time || "") - toMin(b.schedule.start_time || "");
      });
    }

    // Đưa lớp đang xem lên đầu nếu có xung đột, sau đó xếp theo tên lớp
    classGroups.sort((a, b) => {
      if (a.classId === selectedClassId) return -1;
      if (b.classId === selectedClassId) return 1;
      return a.className.localeCompare(b.className);
    });

    return {
      totalConflicts,
      roomConflicts,
      timeConflicts,
      classGroups,
    };
  }, [allSchedules, allConflictReasons, classMap, classes, selectedClassId]);

  // Xung đột trong ngày đang chọn của lớp đang chọn
  const conflicts = useMemo(() => {
    return (schedules ?? []).filter((s) => allConflictReasons.has(s.id));
  }, [schedules, allConflictReasons]);

  // Toàn bộ các tiết bị xung đột trong tuần của lớp đang chọn
  const weeklyConflicts = useMemo(() => {
    if (!allSchedules || !selectedClassId) return [];
    const jsDay = new Date().getDay(); // 0: CN, 1: T2, ..., 6: T7
    const todayIndex = jsDay >= 1 && jsDay <= 5 ? jsDay - 1 : 0;

    const list = allSchedules.filter(
      (s) => s.class_id === selectedClassId && allConflictReasons.has(s.id),
    );

    return list.slice().sort((a, b) => {
      const dayA = a.day_of_week - 2;
      const dayB = b.day_of_week - 2;
      const distA = (dayA - todayIndex + 5) % 5;
      const distB = (dayB - todayIndex + 5) % 5;
      if (distA !== distB) return distA - distB;
      return toMin(a.start_time || "") - toMin(b.start_time || "");
    });
  }, [allSchedules, selectedClassId, allConflictReasons]);

  const nearestConflict = weeklyConflicts[0] || null;

  // Nhảy tới lớp và ngày bị xung đột từ popup toàn trường
  function handleJumpToClassConflict(targetClassId: string, targetSchedule?: Schedule) {
    setSchoolConflictsModalOpen(false);
    if (targetClassId !== "unassigned" && targetClassId !== selectedClassId) {
      setSelectedClassId(targetClassId);
    }

    const targetDayIndex = targetSchedule
      ? targetSchedule.day_of_week - 2
      : (schoolConflictStats.classGroups.find((g) => g.classId === targetClassId)?.earliestDayIndex ?? 0);

    setSelectedDay(Math.max(0, Math.min(4, targetDayIndex)));
    setQuery("");

    if (targetSchedule) {
      setHighlightedId(targetSchedule.id);
      setTimeout(() => {
        const el = document.getElementById(`schedule-${targetSchedule.id}`);
        if (el) {
          el.scrollIntoView({ behavior: "smooth", block: "center" });
        }
      }, 250);

      setTimeout(() => {
        setHighlightedId((curr) => (curr === targetSchedule.id ? null : curr));
      }, 4500);
    }
  }

  // Nhảy tới và đánh dấu tiết xung đột trong ngày đang xem
  function jumpToDayConflict() {
    if (conflicts.length === 0) return;
    const target = conflicts[conflictCycleIndex % conflicts.length];
    if (!target) return;

    setConflictCycleIndex((prev) => (prev + 1) % conflicts.length);
    setHighlightedId(target.id);
    setTimeout(() => {
      const el = document.getElementById(`schedule-${target.id}`);
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "center" });
      }
    }, 120);

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
    const classroomRoom = availableRooms.find(
      (r) => r.room_type === "CLASSROOM" && r.class_id === selectedClassId
    );
    const defaultRoom =
      classroomRoom?.name ||
      (currentClassName
        ? currentClassName.startsWith("Lớp ")
          ? `Phòng học ${currentClassName.replace("Lớp ", "")}`
          : `Phòng học ${currentClassName}`
        : "Phòng học");
    setForm({ ...EMPTY_FORM, day_of_week: forDay + 2, room_name: defaultRoom });
    setRoomSearch("");
    setRoomDropdownOpen(false);
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
    setRoomSearch(s.room_name || "");
    setRoomDropdownOpen(false);
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

    // Kiểm tra giờ làm việc của trường: chỉ cho phép từ 07:00 đến lúc trả trẻ (17:00)
    let effectiveStart = form.start_time;
    let effectiveEnd = form.end_time;
    if (form.slot_id) {
      const s = timeSlots?.find((ts) => ts.id === form.slot_id);
      if (s) {
        effectiveStart = s.start_time;
        effectiveEnd = s.end_time;
      }
    }

    if (effectiveStart && effectiveEnd) {
      if (effectiveEnd <= effectiveStart) {
        setToast({ msg: "Giờ kết thúc phải sau giờ bắt đầu", tone: "bad" });
        return;
      }
      if (effectiveStart < WORKING_HOURS_START || effectiveEnd > WORKING_HOURS_END) {
        setToast({
          msg: `Khung giờ hoạt động (${effectiveStart} - ${effectiveEnd}) nằm ngoài giờ làm việc của trường (${WORKING_HOURS_START} - ${WORKING_HOURS_END}, từ đón trẻ đến hết giờ trả trẻ).`,
          tone: "bad",
        });
        return;
      }
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
      setSelectedIds((prev) => prev.filter((id) => id !== s.id));
      mutateDay();
      mutateAll();
    } catch (err: any) {
      setToast({ msg: err?.message || "Không thể xóa", tone: "bad" });
    }
    setConfirmDel(null);
  }

  const allSelected =
    filteredSchedules.length > 0 &&
    filteredSchedules.every((s) => selectedIds.includes(s.id));
  const someSelected =
    selectedIds.length > 0 && !allSelected;

  function toggleSelectAll() {
    if (allSelected) {
      setSelectedIds([]);
    } else {
      setSelectedIds(filteredSchedules.map((s) => s.id));
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
      const res = await deleteSchedulesBatch(selectedIds);
      setToast({
        msg: res.message || `Đã xóa ${selectedIds.length} hoạt động`,
        tone: "ok",
      });
      setSelectedIds([]);
      mutateDay();
      mutateAll();
    } catch (err: any) {
      setToast({
        msg: err?.message || "Không thể xóa hàng loạt hoạt động",
        tone: "bad",
      });
    } finally {
      setBulkDeleting(false);
      setConfirmBulkDel(false);
    }
  }

  function buildClassTimetableSheet(
    targetClassName: string,
    classSchedules: Schedule[],
    format: "matrix" | "list",
    daysToExport: number[],
    sessionFilter: "all" | "morning" | "afternoon",
  ): ExcelSheetData | null {
    // 1. Lọc theo các thứ được chọn
    let filtered = classSchedules.filter((s) => daysToExport.includes(s.day_of_week));

    // 2. Lọc theo khung giờ / buổi
    if (sessionFilter === "morning") {
      filtered = filtered.filter((s) => (s.start_time || "") < "12:00");
    } else if (sessionFilter === "afternoon") {
      filtered = filtered.filter((s) => (s.start_time || "") >= "12:00");
    }

    if (filtered.length === 0) return null;

    if (format === "list") {
      const headers = [
        "Lớp",
        "Thứ",
        "Khung giờ",
        "Tên hoạt động",
        "Địa điểm / Phòng học",
        "Nội dung chi tiết",
      ];
      const sorted = filtered.slice().sort((a, b) => {
        if (a.day_of_week !== b.day_of_week) return a.day_of_week - b.day_of_week;
        return (a.start_time || "").localeCompare(b.start_time || "");
      });
      const rows = sorted.map((s) => [
        targetClassName,
        DAY_LABELS[s.day_of_week - 2] || `Thứ ${s.day_of_week}`,
        s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : ""),
        s.activity_name,
        s.room_name || "",
        s.content || "",
      ]);
      return { sheetName: targetClassName, headers, rows };
    }

    // format === "matrix" (Bảng ma trận tuần: Hàng là Khung giờ, Cột là Thứ 2 → Thứ 6)
    const timeMap = new Map<string, { start: string; end: string }>();
    for (const s of filtered) {
      const range = s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : "");
      if (range && !timeMap.has(range)) {
        timeMap.set(range, { start: s.start_time || "", end: s.end_time || "" });
      }
    }

    const sortedRanges = Array.from(timeMap.entries())
      .sort((a, b) => a[1].start.localeCompare(b[1].start))
      .map((e) => e[0]);

    if (sortedRanges.length === 0) return null;

    const headers = [
      "Khung giờ",
      ...daysToExport.map((d) => DAY_LABELS[d - 2] || `Thứ ${d}`),
    ];

    const rows: (string | number)[][] = [];
    for (const range of sortedRanges) {
      const row: (string | number)[] = [range];
      for (const d of daysToExport) {
        const matches = filtered.filter((s) => {
          const sRange = s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : "");
          return s.day_of_week === d && sRange === range;
        });

        if (matches.length === 0) {
          row.push("—");
        } else {
          const cellStr = matches
            .map((s) => `${s.activity_name}${s.room_name ? ` (${s.room_name})` : ""}`)
            .join(" | ");
          row.push(cellStr);
        }
      }
      rows.push(row);
    }

    return { sheetName: targetClassName, headers, rows };
  }

  function handleOpenExport(scope: "current" | "all") {
    setExportConfig((prev) => ({ ...prev, scope }));
    setExportModalOpen(true);
  }

  function executeExport() {
    const { scope, format, dayFilter, sessionFilter } = exportConfig;
    const daysToExport: number[] =
      dayFilter === "all"
        ? [2, 3, 4, 5, 6]
        : [Number(dayFilter)];

    const daySuffix =
      dayFilter === "all"
        ? "_ca_tuan"
        : `_t${dayFilter}`;
    const sessionSuffix =
      sessionFilter === "morning"
        ? "_sang"
        : sessionFilter === "afternoon"
          ? "_chieu"
          : "";

    if (scope === "all") {
      if (!allSchedules || allSchedules.length === 0) {
        setToast({ msg: "Chưa có hoạt động nào trong toàn trường để xuất", tone: "warn" });
        return;
      }

      const sheets: ExcelSheetData[] = [];
      for (const cl of classes) {
        const cScheds = allSchedules.filter((s) => s.class_id === cl.id);
        const sheet = buildClassTimetableSheet(cl.name, cScheds, format, daysToExport, sessionFilter);
        if (sheet) sheets.push(sheet);
      }

      // Hoạt động chưa phân lớp (nếu có)
      const unassigned = allSchedules.filter((s) => !s.class_id || !classMap.has(s.class_id));
      if (unassigned.length > 0) {
        const unSheet = buildClassTimetableSheet("Chưa phân lớp", unassigned, format, daysToExport, sessionFilter);
        if (unSheet) sheets.push(unSheet);
      }

      if (sheets.length === 0) {
        setToast({ msg: "Không có hoạt động nào thỏa mãn bộ lọc để xuất", tone: "warn" });
        return;
      }

      const suffix = format === "matrix" ? "_ma_tran" : "_danh_sach";
      exportMultiSheetToExcel(`thoi_khoa_bieu_toan_truong${suffix}${daySuffix}${sessionSuffix}.xlsx`, sheets);
      setToast({
        msg: `Đã xuất thời khóa biểu toàn trường (${format === "matrix" ? "Ma trận tuần" : "Danh sách"}) ra ${sheets.length} sheet`,
        tone: "ok",
      });
      setExportModalOpen(false);
      return;
    }

    // scope === "current"
    if (!selectedClassId) {
      setToast({ msg: "Vui lòng chọn một lớp để xuất thời khóa biểu", tone: "warn" });
      return;
    }

    const cScheds = (allSchedules ?? []).filter((s) => s.class_id === selectedClassId);
    const sheet = buildClassTimetableSheet(currentClassName || "Lớp", cScheds, format, daysToExport, sessionFilter);

    if (!sheet) {
      setToast({ msg: "Không có hoạt động nào của lớp thỏa mãn bộ lọc để xuất", tone: "warn" });
      return;
    }

    const cleanClassName = (currentClassName || "lop").replace(/\s+/g, "_");
    const suffix = format === "matrix" ? "_ma_tran" : "";
    const filename = `thoi_khoa_bieu_${cleanClassName}${suffix}${daySuffix}${sessionSuffix}.xlsx`;

    exportToExcel(filename, sheet.sheetName, sheet.headers, sheet.rows);
    setToast({
      msg: `Đã xuất thời khóa biểu lớp "${currentClassName}" ra file Excel (${format === "matrix" ? "Ma trận tuần" : "Danh sách"})`,
      tone: "ok",
    });
    setExportModalOpen(false);
  }

  async function handleImportRows(
    rows: string[][],
    options?: { overwrite?: boolean }
  ): Promise<ImportResult> {
    const allowOverwrite = options?.overwrite !== false;
    let success = 0;
    let failed = 0;
    const errors: string[] = [];

    // Lọc bỏ các dòng hoàn toàn trống và các dòng tiêu đề (Header / Ghi chú) nếu còn sót lại
    const validRows: { lineNum: number; raw: string[] }[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      if (!row || row.every((c) => !String(c ?? "").trim())) {
        // Dòng trống -> Bỏ qua
        continue;
      }

      // Xác định dòng tiêu đề (Header) vs dòng dữ liệu:
      // Trong file thời khóa biểu, dòng dữ liệu BẮT BUỘC phải có Thứ (Thứ 2..Thứ 7, CN) ở cột 0 (định dạng 5 cột)
      // hoặc ở cột 1 (định dạng 6 cột có tên lớp).
      // Dòng tiêu đề cột (chứa chữ "Lớp", "Thứ", "Khung giờ"...) hoặc dòng ghi chú sẽ không có Thứ hợp lệ -> Bỏ qua an toàn.
      const col0Day = parseDayOfWeek(row[0]);
      const col1Day = parseDayOfWeek(row[1]);

      if (col0Day === null && col1Day === null) {
        // Cả 2 cột đầu đều không phải Thứ 2..CN -> Đây là dòng tiêu đề hoặc dòng ghi chú -> Bỏ qua
        continue;
      }

      validRows.push({ lineNum: i + 1, raw: row });
    }

    if (validRows.length === 0) {
      return { total: 0, success: 0, failed: 0, errors: ["File không có dòng dữ liệu hợp lệ."] };
    }

    // Lấy dữ liệu mới nhất để so khớp
    const freshAll: Schedule[] = await getSchedules().catch(() => (allSchedules ? [...allSchedules] : []));

    for (const item of validRows) {
      const row = item.raw;
      const lineNum = item.lineNum;

      // Hỗ trợ 2 định dạng:
      // 5 cột: [Thứ, Giờ, Tên hoạt động, Phòng, Nội dung]
      // 6 cột: [Tên lớp, Thứ, Giờ, Tên hoạt động, Phòng, Nội dung]
      let className = "";
      let dayStr = "";
      let timeStr = "";
      let activityName = "";
      let roomName = "";
      let content = "";

      const col0Day = parseDayOfWeek(row[0]);
      const col1Day = parseDayOfWeek(row[1]);

      if (col0Day !== null) {
        dayStr = row[0] ?? "";
        timeStr = row[1] ?? "";
        activityName = row[2] ?? "";
        roomName = row[3] ?? "";
        content = row[4] ?? "";
      } else {
        className = row[0] ?? "";
        dayStr = row[1] ?? "";
        timeStr = row[2] ?? "";
        activityName = row[3] ?? "";
        roomName = row[4] ?? "";
        content = row[5] ?? "";
      }

      // 1. Kiểm tra tên hoạt động
      if (!activityName || !activityName.trim()) {
        failed++;
        errors.push(`Dòng ${lineNum}: Thiếu tên hoạt động.`);
        continue;
      }

      // 2. Kiểm tra thứ
      const dayOfWeek = parseDayOfWeek(dayStr);
      if (!dayOfWeek || dayOfWeek < 2 || dayOfWeek > 8) {
        failed++;
        errors.push(`Dòng ${lineNum} ("${activityName.trim()}"): Thiếu hoặc sai định dạng Thứ (ví dụ: Thứ 2, Thứ 3...).`);
        continue;
      }

      if (dayOfWeek === 7 || dayOfWeek === 8) {
        failed++;
        const dayLabel = dayOfWeek === 7 ? "Thứ 7" : "Chủ Nhật";
        errors.push(
          `Dòng ${lineNum} ("${activityName.trim()}"): Thời khóa biểu chỉ áp dụng từ Thứ 2 đến Thứ 6 (không chấp nhận ${dayLabel}).`
        );
        continue;
      }

      // 3. Xác định lớp học
      let targetClassId = selectedClassId;
      if (className && className.trim()) {
        const cn = className.trim().toLowerCase();
        const found = classes.find(
          (c) =>
            c.id === className.trim() ||
            c.name.toLowerCase() === cn ||
            c.name.toLowerCase().replace("lớp ", "") === cn.replace("lớp ", "")
        );
        if (found) {
          targetClassId = found.id;
        } else {
          failed++;
          errors.push(`Dòng ${lineNum} ("${activityName.trim()}"): Không tìm thấy lớp "${className.trim()}" trong danh sách lớp của trường.`);
          continue;
        }
      }

      if (!targetClassId) {
        failed++;
        errors.push(`Dòng ${lineNum} ("${activityName.trim()}"): Vui lòng chọn lớp trước khi nạp lịch.`);
        continue;
      }

      // 4. Xác định khung giờ
      let slotId: string | null = null;
      let startTime: string | null = null;
      let endTime: string | null = null;

      const trimmedTime = (timeStr || "").trim();
      let matchedSlot = timeSlots?.find(
        (ts) =>
          ts.name.trim().toLowerCase() === trimmedTime.toLowerCase() ||
          `${ts.start_time} - ${ts.end_time}` === trimmedTime ||
          `${ts.start_time}-${ts.end_time}` === trimmedTime
      );

      const parsed = parseTimeRange(trimmedTime);
      if (!matchedSlot && parsed) {
        // Thử tìm slot theo start_time và end_time đã parse
        matchedSlot = timeSlots?.find(
          (ts) => ts.start_time === parsed.start && ts.end_time === parsed.end
        );
      }

      if (matchedSlot) {
        slotId = matchedSlot.id;
        startTime = matchedSlot.start_time;
        endTime = matchedSlot.end_time;
      } else if (parsed) {
        startTime = parsed.start;
        endTime = parsed.end;
      } else {
        failed++;
        errors.push(`Dòng ${lineNum} ("${activityName.trim()}"): Thiếu hoặc sai định dạng khung giờ (ví dụ: 08:10 - 08:40).`);
        continue;
      }

      // Kiểm tra khung giờ làm việc của trường (07:00 - 17:00)
      if (startTime && endTime) {
        if (endTime <= startTime) {
          failed++;
          errors.push(
            `Dòng ${lineNum} ("${activityName.trim()}"): Giờ kết thúc (${endTime}) phải sau giờ bắt đầu (${startTime}).`
          );
          continue;
        }
        if (startTime < WORKING_HOURS_START || endTime > WORKING_HOURS_END) {
          failed++;
          errors.push(
            `Dòng ${lineNum} ("${activityName.trim()}"): Khung giờ ${startTime} - ${endTime} nằm ngoài giờ làm việc của trường (${WORKING_HOURS_START} - ${WORKING_HOURS_END}, từ đón trẻ đến hết giờ trả trẻ).`
          );
          continue;
        }
      }

      // 5. Xác định địa điểm / phòng học (nếu trống tự lấy phòng chính của lớp)
      const targetClassName = classMap.get(targetClassId) || currentClassName || "";
      const defaultRoom = targetClassName
        ? targetClassName.startsWith("Lớp ")
          ? `Phòng học ${targetClassName.replace("Lớp ", "")}`
          : `Phòng học ${targetClassName}`
        : "Phòng học";
      const finalRoomName = roomName.trim() || defaultRoom;

      const payload: SchedulePayload = {
        class_id: targetClassId,
        activity_name: activityName.trim(),
        content: content.trim() || null,
        room_name: finalRoomName,
        slot_id: slotId,
        start_time: slotId ? null : startTime,
        end_time: slotId ? null : endTime,
        day_of_week: dayOfWeek,
      };

      // 6. Kiểm tra xem lớp này đã có lịch ở khung giờ đó chưa:
      // - Nếu bật ghi đè: cập nhật lại tiết cũ
      // - Nếu tắt ghi đè: cứ ghi mới bình thường, hệ thống sẽ cảnh báo trùng lịch trực quan sau ở màn hình chính
      const existing = allowOverwrite
        ? freshAll.find((s) => {
          if (s.class_id !== targetClassId || s.day_of_week !== dayOfWeek) return false;
          if (slotId && s.slot_id === slotId) return true;
          if (startTime && endTime && s.start_time && s.end_time) {
            const s1 = toMin(startTime);
            const e1 = toMin(endTime);
            const s2 = toMin(s.start_time);
            const e2 = toMin(s.end_time);
            return s1 < e2 && e1 > s2;
          }
          return false;
        })
        : null;

      try {
        if (existing) {
          await updateSchedule(existing.id, payload);
          existing.activity_name = payload.activity_name;
          existing.room_name = payload.room_name || existing.room_name;
          existing.content = payload.content || "";
          existing.slot_id = payload.slot_id ?? null;
          existing.start_time = startTime;
          existing.end_time = endTime;
        } else {
          const res = await createSchedule(payload);
          freshAll.push({
            id: res.id,
            activity_name: payload.activity_name,
            content: payload.content || "",
            class_id: targetClassId,
            room_name: payload.room_name || "",
            time_range: matchedSlot?.name || `${startTime} - ${endTime}`,
            slot_id: slotId,
            start_time: startTime,
            end_time: endTime,
            day_of_week: dayOfWeek,
            is_active: true,
          });
        }
        success++;
      } catch (err: any) {
        failed++;
        errors.push(`Dòng ${lineNum} ("${activityName.trim()}"): ${err?.message || "Lỗi lưu hoạt động"}`);
      }
    }

    mutateDay();
    mutateAll();

    return { total: validRows.length, success, failed, errors };
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
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => {
              mutateDay();
              mutateAll();
              setToast({ msg: "Đã đồng bộ dữ liệu mới nhất", tone: "brand" });
            }}
            className="kbtn kbtn-secondary"
            title="Làm mới"
          >
            ↻
          </button>
          <button
            onClick={() => handleOpenExport("all")}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Xuất toàn bộ thời khóa biểu tất cả các lớp ra file Excel (Tùy chọn thứ & khung giờ)"
          >
            🏫 Xuất lịch toàn trường
          </button>
          <button
            onClick={() => handleOpenExport("current")}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Xuất thời khóa biểu của lớp đang chọn ra file Excel (Tùy chọn thứ & khung giờ)"
          >
            📥 Xuất excel
          </button>
          <button
            onClick={() => setImportOpen(true)}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Nhập thời khóa biểu từ file Excel / CSV"
          >
            📤 Nhập file
          </button>
          <button onClick={() => openCreate(selectedDay)} className="kbtn kbtn-primary">
            + Thêm hoạt động
          </button>
        </div>
      }
    >
      <p className="text-sm text-ink-soft -mt-3 mb-4">
        Lên lịch hoạt động cho từng lớp theo tuần. Hệ thống tự động phát hiện xung
        đột phòng/khung giờ.
      </p>

      {/* Cảnh báo xung đột TOÀN TRƯỜNG (Tone đỏ, đập vào mắt, bấm mở popup danh sách các lớp) */}
      {schoolConflictStats.totalConflicts > 0 && (
        <div
          onClick={() => setSchoolConflictsModalOpen(true)}
          role="button"
          tabIndex={0}
          className="card p-3.5 mb-4 flex items-center justify-between gap-3 cursor-pointer transition-all duration-200 hover:shadow-md border select-none group"
          style={{
            background: "#FDF2F0",
            borderColor: "#F2D5CE",
          }}
          title="Nhấn để xem danh sách các lớp bị xung đột lịch trên toàn trường"
        >
          <div className="flex items-start gap-3 min-w-0">
            <span className="text-2xl shrink-0 mt-0.5 animate-pulse">🚨</span>
            <div className="min-w-0">
              <div className="font-bold text-sm text-[#BB4A34] flex items-center gap-2 flex-wrap">
                <span>
                  Toàn trường: Phát hiện {schoolConflictStats.totalConflicts} tiết học bị xung đột tại {schoolConflictStats.classGroups.length} lớp
                </span>
                <span className="text-[11px] font-medium px-2 py-0.5 rounded-full bg-[#BB4A34]/15 text-[#BB4A34]">
                  Nhấn xem chi tiết &amp; sửa
                </span>
              </div>
              <div className="text-xs text-[#8C3423] mt-1 line-clamp-1">
                {schoolConflictStats.roomConflicts > 0 && `${schoolConflictStats.roomConflicts} lỗi trùng phòng học`}
                {schoolConflictStats.roomConflicts > 0 && schoolConflictStats.timeConflicts > 0 && " · "}
                {schoolConflictStats.timeConflicts > 0 && `${schoolConflictStats.timeConflicts} lỗi trùng giờ`}
                {" — Các lớp bị ảnh hưởng: "}
                <span className="font-semibold text-ink">
                  {schoolConflictStats.classGroups.map((g) => g.className).join(", ")}
                </span>
              </div>
            </div>
          </div>
          <div
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-control text-xs font-bold text-white shrink-0 shadow-sm transition group-hover:scale-105"
            style={{ background: "#BB4A34" }}
          >
            <span>Xem danh sách lớp ({schoolConflictStats.classGroups.length})</span>
            <span className="text-sm transition group-hover:translate-x-0.5">→</span>
          </div>
        </div>
      )}

      {/* Class selector */}
      {classes.length > 0 && (
        <div
          className="card p-3 mb-4 flex items-center gap-3"
          style={{ background: "#EFECE5" }}
        >
          <span className="text-sm font-semibold text-ink">Lớp:</span>
          <div className="w-72">
            <ClassFilterSelect
              classes={classes}
              value={selectedClassId ?? ""}
              onChange={(val) => setSelectedClassId(val || null)}
              placeholder="-- Chọn lớp --"
            />
          </div>
        </div>
      )}

      {/* Day tabs */}
      <div className="card mb-4 p-1.5 flex gap-1 overflow-x-auto">
        {DAY_LABELS.map((label, idx) => {
          const isActive = idx === selectedDay;
          const dayDOW = idx + 2;
          const dayHasConflict = (allSchedules || []).some(
            (s) => s.class_id === selectedClassId && s.day_of_week === dayDOW && allConflictReasons.has(s.id),
          );
          return (
            <button
              key={label}
              onClick={() => setSelectedDay(idx)}
              className="flex-1 px-3 py-2 rounded-control text-sm font-semibold whitespace-nowrap transition flex items-center justify-center gap-1.5"
              style={
                isActive
                  ? { background: "#16665a", color: "white" }
                  : { background: "transparent", color: "#605D57" }
              }
            >
              <span>{label}</span>
              {dayHasConflict && (
                <span
                  className="w-2 h-2 rounded-full"
                  style={{ background: isActive ? "#FCD34D" : "#DC2626" }}
                  title="Có tiết bị xung đột trong ngày này"
                />
              )}
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

      {/* Conflict banner của ngày đang chọn (Tone vàng, chuyển nút sửa tiết xung đột xuống đây) */}
      {conflicts.length > 0 && (
        <div
          className="mb-3 px-4 py-3 rounded-control flex items-center justify-between gap-3 shadow-sm"
          style={{ background: "#F6EED9", border: "1px solid #B0791B" }}
        >
          <div className="flex items-start gap-2.5 min-w-0">
            <span className="text-2xl shrink-0 mt-0.5">⚠️</span>
            <div className="min-w-0">
              <div className="font-bold text-sm" style={{ color: "#8A5E12" }}>
                {conflicts.length} xung đột phòng/khung giờ trong ngày {DAY_SHORT[selectedDay]}
                {conflicts.length > 1 && (
                  <span className="ml-2 text-[11px] font-normal px-2 py-0.5 rounded-full bg-[#8A5E12]/15 text-[#8A5E12]">
                    Tiết {(conflictCycleIndex % conflicts.length) + 1}/{conflicts.length}
                  </span>
                )}
              </div>
              <div className="text-xs mt-0.5 text-ink-soft line-clamp-1">
                {(() => {
                  const currConflict = conflicts[conflictCycleIndex % conflicts.length];
                  const reason = currConflict ? allConflictReasons.get(currConflict.id) : null;
                  return currConflict ? (
                    <span>
                      Tiết <strong>&quot;{currConflict.activity_name}&quot;</strong> ({currConflict.start_time} - {currConflict.end_time})
                      {reason && ` · ${reason}`}
                    </span>
                  ) : (
                    "Vui lòng điều chỉnh để tránh 2 hoạt động cùng phòng + cùng giờ."
                  );
                })()}
              </div>
            </div>
          </div>

          <button
            type="button"
            onClick={jumpToDayConflict}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-control text-xs font-bold text-white shrink-0 shadow-sm transition hover:scale-105 active:scale-95 cursor-pointer"
            style={{ background: "#B0791B" }}
            title="Nhảy tới và đánh dấu tiết học bị xung đột trong ngày này"
          >
            <span>Sửa tiết xung đột</span>
            <span className="text-sm">→</span>
          </button>
        </div>
      )}

      {/* Thông báo nếu ngày hiện tại không có lỗi nhưng tuần này lớp đang có lỗi ở ngày khác */}
      {conflicts.length === 0 && weeklyConflicts.length > 0 && (
        <div
          className="mb-3 px-4 py-2.5 rounded-control flex items-center justify-between gap-3 text-xs"
          style={{ background: "#FBF6ED", border: "1px dashed #D9A54C" }}
        >
          <div className="flex items-center gap-2 text-[#8A5E12] min-w-0">
            <span className="shrink-0">ℹ️</span>
            <span className="truncate">
              Ngày {DAY_LABELS[selectedDay]} không có xung đột. Lớp này có{" "}
              <strong>{weeklyConflicts.length} tiết bị xung đột</strong> vào các ngày khác trong tuần.
            </span>
          </div>
          <button
            type="button"
            onClick={() => {
              const target = weeklyConflicts[0];
              if (target) {
                setSelectedDay(Math.max(0, Math.min(4, target.day_of_week - 2)));
                setHighlightedId(target.id);
                setTimeout(() => {
                  const el = document.getElementById(`schedule-${target.id}`);
                  if (el) {
                    el.scrollIntoView({ behavior: "smooth", block: "center" });
                  }
                }, 200);
              }
            }}
            className="text-xs font-bold text-[#8A5E12] hover:underline flex items-center gap-1 shrink-0 cursor-pointer"
          >
            <span>Chuyển tới {DAY_LABELS[weeklyConflicts[0].day_of_week - 2]}</span>
            <span>→</span>
          </button>
        </div>
      )}

      {/* Schedule list */}
      <div className="card overflow-hidden">
        {!schedules && !scheduleError ? (
          <Spinner />
        ) : scheduleError ? (
          <div className="text-center py-12">
            <div className="text-bad font-semibold mb-2">
              {(scheduleError as any)?.status === 401
                ? "Phiên đăng nhập đã hết hạn. Đang chuyển về trang đăng nhập..."
                : `Không thể tải thời khóa biểu (${(scheduleError as any)?.detail || "Vui lòng thử lại"})`}
            </div>
            <button
              onClick={() => {
                mutateAll();
                mutateDay();
              }}
              className="kbtn kbtn-secondary mt-2"
            >
              Thử lại
            </button>
          </div>
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
          <div>
            <div
              className={`px-4 py-2 flex items-center justify-between border-b text-xs font-semibold transition-colors duration-200 ${selectedIds.length > 0
                ? "bg-[#FDF8F6] border-[#F2D5CE]"
                : "border-line"
                }`}
              style={selectedIds.length > 0 ? undefined : { background: "#EFECE5", color: "#605D57" }}
            >
              <div className="flex items-center gap-3">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    className="rounded cursor-pointer"
                    checked={allSelected}
                    ref={(el) => {
                      if (el) el.indeterminate = someSelected;
                    }}
                    onChange={toggleSelectAll}
                    title="Chọn tất cả hoạt động hiển thị"
                  />
                  <span>Chọn tất cả ({filteredSchedules.length})</span>
                </label>

                {selectedIds.length > 0 && (
                  <>
                    <span className="text-line-strong">|</span>
                    <div className="flex items-center gap-1.5 font-semibold text-[#BB4A34]">
                      <span className="w-5 h-5 rounded-full flex items-center justify-center text-[10px] text-white font-bold bg-[#BB4A34]">
                        {selectedIds.length}
                      </span>
                      <span>Đã chọn {selectedIds.length} hoạt động</span>
                    </div>
                  </>
                )}
              </div>

              <div className="flex items-center gap-2">
                {selectedIds.length > 0 && (
                  <>
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
                    <span className="text-line-strong">|</span>
                  </>
                )}
                <span className={selectedIds.length > 0 ? "text-ink font-semibold" : ""}>{DAY_LABELS[selectedDay]}</span>
              </div>
            </div>
            <ul>
              {filteredSchedules.map((s, idx) => {
                const hasConflict = conflictReasons.has(s.id);
                const reason = conflictReasons.get(s.id);
                const isHighlighted = highlightedId === s.id;
                const isSelected = selectedIds.includes(s.id);
                return (
                  <li
                    key={s.id}
                    id={`schedule-${s.id}`}
                    className={`flex items-start gap-3 px-4 py-3 transition-all duration-300 ${idx > 0 ? "border-t border-line" : ""
                      } ${isSelected
                        ? "bg-[#FDF8F6]"
                        : isHighlighted
                          ? "bg-[#FFF9EE] ring-2 ring-[#B0791B] ring-offset-2 z-10 relative rounded-control shadow-sm"
                          : ""
                      }`}
                  >
                    <div className="pt-2">
                      <input
                        type="checkbox"
                        className="rounded cursor-pointer"
                        checked={isSelected}
                        onChange={() => toggleSelect(s.id)}
                      />
                    </div>
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
          </div>
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
        <FormField label="Hoặc nhập giờ tự do (07:00 – 17:00)">
          <div className="grid grid-cols-2 gap-2">
            <div>
              <input
                type="time"
                min={WORKING_HOURS_START}
                max={WORKING_HOURS_END}
                className="kinput"
                value={form.start_time}
                onChange={(e) => setForm({ ...form, start_time: e.target.value, slot_id: null })}
                placeholder="Bắt đầu"
              />
              <span className="text-[11px] text-ink-faint mt-1 block">Từ 07:00 (Đón trẻ)</span>
            </div>
            <div>
              <input
                type="time"
                min={WORKING_HOURS_START}
                max={WORKING_HOURS_END}
                className="kinput"
                value={form.end_time}
                onChange={(e) => setForm({ ...form, end_time: e.target.value, slot_id: null })}
                placeholder="Kết thúc"
              />
              <span className="text-[11px] text-ink-faint mt-1 block">Đến 17:00 (Trả trẻ)</span>
            </div>
          </div>
        </FormField>
        <FormField label="Địa điểm / Phòng học">
          <div className="relative">
            <div className="relative flex items-center">
              <svg
                className="w-4 h-4 text-ink-faint absolute left-3 pointer-events-none"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
              <input
                type="text"
                className="kinput"
                style={{ paddingLeft: "36px", paddingRight: "32px" }}
                value={roomDropdownOpen ? roomSearch : form.room_name}
                onFocus={() => {
                  setRoomSearch(form.room_name);
                  setRoomDropdownOpen(true);
                }}
                onChange={(e) => {
                  setRoomSearch(e.target.value);
                  setForm({ ...form, room_name: e.target.value });
                  setRoomDropdownOpen(true);
                }}
                placeholder="Tìm hoặc gõ tên phòng / sân bãi..."
              />
              {form.room_name && (
                <button
                  type="button"
                  onClick={() => {
                    setForm({ ...form, room_name: "" });
                    setRoomSearch("");
                  }}
                  className="absolute right-2.5 text-xs text-ink-faint hover:text-ink w-5 h-5 rounded-full hover:bg-surface-sunken flex items-center justify-center transition"
                  title="Xóa địa điểm"
                >
                  ✕
                </button>
              )}
            </div>

            {/* Quick chips below */}
            <div className="flex flex-wrap gap-1.5 mt-2">
              <span className="text-[11px] text-ink-faint self-center mr-0.5">Gợi ý nhanh:</span>
              {[
                currentClassName ? `Phòng học ${currentClassName}` : "Phòng học của lớp",
                "Sân cỏ",
                "Sân trường",
                "Phòng Mỹ thuật & Tạo hình",
                "Phòng Âm nhạc & Vận động",
              ].map((chip) => {
                const isSelected = form.room_name.trim().toLowerCase() === chip.trim().toLowerCase();
                return (
                  <button
                    key={chip}
                    type="button"
                    onClick={() => {
                      setForm({ ...form, room_name: chip });
                      setRoomSearch("");
                      setRoomDropdownOpen(false);
                    }}
                    className={`px-2 py-0.5 rounded-full text-[11px] border transition ${isSelected
                      ? "bg-[#16665a] text-white border-transparent font-semibold shadow-xs"
                      : "bg-surface-sunken text-ink-soft hover:bg-white hover:text-ink border-line"
                      }`}
                  >
                    {chip}
                  </button>
                );
              })}
            </div>

            {/* Dropdown list */}
            {roomDropdownOpen && (
              <>
                <div
                  className="fixed inset-0 z-10"
                  onClick={() => setRoomDropdownOpen(false)}
                />
                <div
                  className="absolute z-20 left-0 right-0 mt-1 max-h-64 overflow-y-auto rounded-control bg-white border border-line-strong shadow-xl p-1.5 text-xs animate-in fade-in slide-in-from-top-1 duration-150"
                  style={{ backdropFilter: "blur(8px)" }}
                >
                  {/* Option to use custom typed text */}
                  {roomSearch.trim() && !exactMatchInList && (
                    <div
                      onClick={() => {
                        setForm({ ...form, room_name: roomSearch.trim() });
                        setRoomDropdownOpen(false);
                      }}
                      className="p-2 mb-1 rounded bg-[#EDF5F2] hover:bg-[#E0EFEA] text-[#16665A] font-semibold cursor-pointer flex items-center justify-between"
                    >
                      <span>➕ Sử dụng địa điểm: &ldquo;{roomSearch.trim()}&rdquo;</span>
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-white text-[#16665A] border border-[#C4DCD3]">
                        Nhập tự do
                      </span>
                    </div>
                  )}

                  {/* Filtered grouped rooms */}
                  {filteredRoomGroups.map((group) => (
                    <div key={group.title} className="mb-2 last:mb-0">
                      <div className="px-2 py-1 text-[10px] font-bold text-ink-faint uppercase tracking-wider flex items-center gap-1">
                        <span>{group.icon}</span>
                        <span>{group.title}</span>
                      </div>
                      {group.items.map((r) => {
                        const isSelected = form.room_name.trim().toLowerCase() === r.name.trim().toLowerCase();
                        return (
                          <div
                            key={r.id || r.name}
                            onClick={() => {
                              setForm({ ...form, room_name: r.name });
                              setRoomSearch("");
                              setRoomDropdownOpen(false);
                            }}
                            className={`p-2 rounded cursor-pointer flex items-center justify-between transition ${isSelected
                              ? "bg-[#16665a]/10 text-[#16665a] font-bold"
                              : "hover:bg-surface-sunken text-ink"
                              }`}
                          >
                            <span className="truncate">{r.name}</span>
                          </div>
                        );
                      })}
                    </div>
                  ))}

                  {filteredRoomGroups.every((g) => g.items.length === 0) && !roomSearch.trim() && (
                    <div className="p-3 text-center text-ink-faint">
                      Không tìm thấy phòng phù hợp. Bạn có thể gõ tên phòng trực tiếp vào ô tìm kiếm.
                    </div>
                  )}
                </div>
              </>
            )}
          </div>
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

      <ConfirmDialog
        open={confirmBulkDel}
        title={`Xóa ${selectedIds.length} hoạt động đã chọn?`}
        message={`Bạn có chắc muốn xóa vĩnh viễn ${selectedIds.length} hoạt động này khỏi thời khóa biểu? Thao tác này không thể hoàn tác.`}
        confirmLabel={bulkDeleting ? "Đang xóa..." : `Xóa ${selectedIds.length} hoạt động`}
        onConfirm={handleBulkDelete}
        onCancel={() => !bulkDeleting && setConfirmBulkDel(false)}
      />

      <ImportModal
        open={importOpen}
        onClose={() => setImportOpen(false)}
        title="Nhập thời khóa biểu từ file Excel"
        description="Tải lên file Excel (.xlsx, .xls) hoặc CSV để nạp thời khóa biểu. Hệ thống cho phép nạp và tự động cảnh báo nếu có tiết học bị trùng phòng."
        templateFilename={
          currentClassName
            ? `mau_nhap_thoi_khoa_bieu_${currentClassName.replace(/\s+/g, "_")}.xlsx`
            : "mau_nhap_thoi_khoa_bieu.xlsx"
        }
        sampleHeaders={[
          "Lớp",
          "Thứ",
          "Khung giờ",
          "Tên hoạt động",
          "Địa điểm / Phòng học",
          "Nội dung chi tiết",
        ]}
        sampleRow={[
          currentClassName || "Lớp Mầm A",
          "Thứ 2",
          "08:10 - 08:40",
          "Học hát & Vận động âm nhạc",
          "Phòng Âm nhạc & Vận động",
          "Tập bài hát Cháu yêu bà, vận động vỗ tay theo phách",
        ]}
        allowOverwrite={true}
        overwriteLabel="Ghi đè hoạt động nếu lớp đã có lịch ở cùng khung giờ"
        overwriteHint="Nếu bật: Cập nhật lại tiết học cũ ở cùng khung giờ. Nếu tắt: Vẫn tạo mới tiết học bình thường, hệ thống sẽ cảnh báo xung đột lịch trực quan ở ngoài bảng thời khóa biểu."
        onImportRows={handleImportRows}
        onSuccess={() => {
          setToast({ msg: "Đã nạp thời khóa biểu thành công", tone: "ok" });
        }}
      />

      {/* Modal tùy chọn xuất thời khóa biểu (theo thứ, theo khung giờ, ma trận / danh sách) */}
      {exportModalOpen && (
        <Modal
          open={exportModalOpen}
          onClose={() => setExportModalOpen(false)}
          title="📥 Tùy chọn xuất thời khóa biểu ra Excel"
          size="md"
          footer={
            <div className="flex items-center justify-end gap-2 w-full">
              <button
                type="button"
                onClick={() => setExportModalOpen(false)}
                className="kbtn kbtn-secondary text-sm"
              >
                Hủy
              </button>
              <button
                type="button"
                onClick={executeExport}
                className="kbtn kbtn-primary text-sm flex items-center gap-1.5"
              >
                <span>📥 Tải file Excel (.xlsx)</span>
              </button>
            </div>
          }
        >
          <div className="space-y-4 text-xs">
            {/* 1. Phạm vi xuất */}
            <div>
              <label className="block text-xs font-semibold text-ink mb-1.5">
                1. Phạm vi xuất
              </label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, scope: "current" }))}
                  className={`p-3 rounded-card text-left transition relative cursor-pointer ${exportConfig.scope === "current"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] shadow-sm ring-2 ring-[#16665a]/25 text-[#16665a]"
                    : "border border-line bg-surface text-ink hover:border-lineStrong hover:bg-canvas/50"
                    }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="font-bold text-xs flex items-center gap-1.5">
                      <span>🏫 Lớp đang chọn</span>
                    </div>
                    {exportConfig.scope === "current" ? (
                      <span className="w-4 h-4 rounded-full bg-[#16665a] text-white flex items-center justify-center text-[10px] font-bold">
                        ✓
                      </span>
                    ) : (
                      <span className="w-4 h-4 rounded-full border border-lineStrong bg-white" />
                    )}
                  </div>
                  <div className={`text-[11px] mt-1 truncate ${exportConfig.scope === "current" ? "text-[#16665a]/80 font-medium" : "text-ink-soft"
                    }`}>
                    {currentClassName || "Chưa chọn lớp"}
                  </div>
                </button>
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, scope: "all" }))}
                  className={`p-3 rounded-card text-left transition relative cursor-pointer ${exportConfig.scope === "all"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] shadow-sm ring-2 ring-[#16665a]/25 text-[#16665a]"
                    : "border border-line bg-surface text-ink hover:border-lineStrong hover:bg-canvas/50"
                    }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="font-bold text-xs flex items-center gap-1.5">
                      <span>🌐 Toàn trường</span>
                    </div>
                    {exportConfig.scope === "all" ? (
                      <span className="w-4 h-4 rounded-full bg-[#16665a] text-white flex items-center justify-center text-[10px] font-bold">
                        ✓
                      </span>
                    ) : (
                      <span className="w-4 h-4 rounded-full border border-lineStrong bg-white" />
                    )}
                  </div>
                  <div className={`text-[11px] mt-1 ${exportConfig.scope === "all" ? "text-[#16665a]/80 font-medium" : "text-ink-soft"
                    }`}>
                    Mỗi lớp 1 sheet riêng biệt
                  </div>
                </button>
              </div>
            </div>

            {/* 2. Định dạng file */}
            <div>
              <label className="block text-xs font-semibold text-ink mb-1.5">
                2. Định dạng bảng biểu
              </label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, format: "matrix" }))}
                  className={`p-3 rounded-card text-left transition relative cursor-pointer ${exportConfig.format === "matrix"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] shadow-sm ring-2 ring-[#16665a]/25 text-[#16665a]"
                    : "border border-line bg-surface text-ink hover:border-lineStrong hover:bg-canvas/50"
                    }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="font-bold text-xs flex items-center gap-1.5">
                      <span>📊 Ma trận thời khóa biểu</span>
                    </div>
                    {exportConfig.format === "matrix" ? (
                      <span className="w-4 h-4 rounded-full bg-[#16665a] text-white flex items-center justify-center text-[10px] font-bold">
                        ✓
                      </span>
                    ) : (
                      <span className="w-4 h-4 rounded-full border border-lineStrong bg-white" />
                    )}
                  </div>
                  <div className={`text-[11px] mt-1 leading-tight ${exportConfig.format === "matrix" ? "text-[#16665a]/80 font-medium" : "text-ink-soft"
                    }`}>
                    Cột Thứ 2 → Thứ 6, hàng là các khung giờ
                  </div>
                </button>
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, format: "list" }))}
                  className={`p-3 rounded-card text-left transition relative cursor-pointer ${exportConfig.format === "list"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] shadow-sm ring-2 ring-[#16665a]/25 text-[#16665a]"
                    : "border border-line bg-surface text-ink hover:border-lineStrong hover:bg-canvas/50"
                    }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="font-bold text-xs flex items-center gap-1.5">
                      <span>📋 Danh sách chi tiết</span>
                    </div>
                    {exportConfig.format === "list" ? (
                      <span className="w-4 h-4 rounded-full bg-[#16665a] text-white flex items-center justify-center text-[10px] font-bold">
                        ✓
                      </span>
                    ) : (
                      <span className="w-4 h-4 rounded-full border border-lineStrong bg-white" />
                    )}
                  </div>
                  <div className={`text-[11px] mt-1 leading-tight ${exportConfig.format === "list" ? "text-[#16665a]/80 font-medium" : "text-ink-soft"
                    }`}>
                    Mỗi hoạt động 1 hàng, đầy đủ phòng học và ghi chú
                  </div>
                </button>
              </div>
            </div>

            {/* 3. Lọc theo thứ trong tuần */}
            <div>
              <label className="block text-xs font-semibold text-ink mb-1.5">
                3. Lọc theo thứ trong tuần
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, dayFilter: "all" }))}
                  className={`p-2.5 rounded-control text-center transition text-xs cursor-pointer ${exportConfig.dayFilter === "all"
                    ? "border-2 border-[#16665a] bg-[#16665a] text-white font-bold ring-2 ring-[#16665a]/25 shadow-sm"
                    : "border border-line bg-surface text-ink hover:bg-sunken/60 hover:border-lineStrong"
                    }`}
                >
                  📅 Cả tuần (T2 - T6)
                </button>
                {[2, 3, 4, 5, 6].map((d) => {
                  const isCurrentViewingDay = d === selectedDay + 2;
                  const isSelected = exportConfig.dayFilter === d;
                  return (
                    <button
                      key={d}
                      type="button"
                      onClick={() => setExportConfig((c) => ({ ...c, dayFilter: d }))}
                      className={`p-2.5 rounded-control text-center transition text-xs cursor-pointer relative ${isSelected
                        ? "border-2 border-[#16665a] bg-[#16665a] text-white font-bold ring-2 ring-[#16665a]/25 shadow-sm"
                        : "border border-line bg-surface text-ink hover:bg-sunken/60 hover:border-lineStrong"
                        }`}
                      title={isCurrentViewingDay ? `Thứ ${d} (Đang mở trên màn hình)` : `Thứ ${d}`}
                    >
                      <div className="flex items-center justify-center gap-1.5">
                        <span>Thứ {d}</span>
                        {isCurrentViewingDay && (
                          <span
                            className="text-xs shrink-0"
                            title="Ngày đang mở trên màn hình lịch"
                          >
                            📍
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
              <div className="mt-1.5 px-0.5 flex items-center justify-between text-[11px] text-ink-soft">
                <span>
                  📍 <strong>{DAY_LABELS[selectedDay]}</strong> là ngày bạn đang mở trên bảng lịch.
                </span>
                {exportConfig.dayFilter !== selectedDay + 2 && (
                  <button
                    type="button"
                    onClick={() => setExportConfig((c) => ({ ...c, dayFilter: selectedDay + 2 }))}
                    className="text-[#16665a] hover:underline font-semibold cursor-pointer"
                  >
                    Chọn {DAY_LABELS[selectedDay]} →
                  </button>
                )}
              </div>
            </div>

            {/* 4. Lọc theo khung giờ / buổi */}
            <div>
              <label className="block text-xs font-semibold text-ink mb-1.5">
                4. Lọc theo khung giờ / Buổi học
              </label>
              <div className="grid grid-cols-3 gap-2">
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, sessionFilter: "all" }))}
                  className={`p-2.5 rounded-control text-center transition text-xs cursor-pointer ${exportConfig.sessionFilter === "all"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] text-[#16665a] font-bold ring-2 ring-[#16665a]/25 shadow-sm"
                    : "border border-line bg-surface text-ink hover:bg-sunken/60 hover:border-lineStrong"
                    }`}
                >
                  ☀️ Cả ngày (Tất cả)
                </button>
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, sessionFilter: "morning" }))}
                  className={`p-2.5 rounded-control text-center transition text-xs cursor-pointer ${exportConfig.sessionFilter === "morning"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] text-[#16665a] font-bold ring-2 ring-[#16665a]/25 shadow-sm"
                    : "border border-line bg-surface text-ink hover:bg-sunken/60 hover:border-lineStrong"
                    }`}
                >
                  🌅 Buổi sáng (&lt; 12:00)
                </button>
                <button
                  type="button"
                  onClick={() => setExportConfig((c) => ({ ...c, sessionFilter: "afternoon" }))}
                  className={`p-2.5 rounded-control text-center transition text-xs cursor-pointer ${exportConfig.sessionFilter === "afternoon"
                    ? "border-2 border-[#16665a] bg-[#E6EFEC] text-[#16665a] font-bold ring-2 ring-[#16665a]/25 shadow-sm"
                    : "border border-line bg-surface text-ink hover:bg-sunken/60 hover:border-lineStrong"
                    }`}
                >
                  🌇 Buổi chiều (≥ 12:00)
                </button>
              </div>
            </div>
          </div>
        </Modal>
      )}

      {/* Modal popup danh sách các lớp bị xung đột lịch trên toàn trường */}
      {schoolConflictsModalOpen && (
        <Modal
          open={schoolConflictsModalOpen}
          onClose={() => setSchoolConflictsModalOpen(false)}
          title={`🚨 Danh sách xung đột lịch toàn trường (${schoolConflictStats.totalConflicts} tiết tại ${schoolConflictStats.classGroups.length} lớp)`}
          size="lg"
          footer={
            <div className="flex items-center justify-between w-full">
              <span className="text-xs text-ink-soft">
                💡 Bấm vào nút <strong>&quot;Điều chỉnh&quot;</strong> để hệ thống tự động chuyển sang lớp và ngày bị xung đột.
              </span>
              <button
                type="button"
                onClick={() => setSchoolConflictsModalOpen(false)}
                className="kbtn kbtn-secondary text-xs"
              >
                Đóng
              </button>
            </div>
          }
        >
          <div className="space-y-3.5">
            <div className="p-3 rounded-control bg-[#FDF2F0] border border-[#F2D5CE] text-xs text-[#8C3423] flex items-center justify-between flex-wrap gap-2">
              <div>
                <strong>Tổng cộng:</strong> {schoolConflictStats.totalConflicts} tiết học đang bị xung đột
                ({schoolConflictStats.roomConflicts} trùng phòng học, {schoolConflictStats.timeConflicts} trùng khung giờ) trên phạm vi toàn trường.
              </div>
            </div>

            <div className="space-y-3 max-h-[60vh] overflow-y-auto pr-1">
              {schoolConflictStats.classGroups.map((group) => {
                const isCurrentClass = group.classId === selectedClassId;
                return (
                  <div
                    key={group.classId}
                    className={`p-3.5 rounded-card border transition ${isCurrentClass
                      ? "bg-brand/5 border-brand/40 shadow-sm"
                      : "bg-sunken/40 border-line hover:border-ink-faint"
                      }`}
                  >
                    <div className="flex items-center justify-between gap-2 mb-2 pb-2 border-b border-line/60">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-sm text-ink">
                          {group.className}
                        </span>
                        {group.gradeLabel && (
                          <span className="text-xs text-ink-soft">
                            ({group.gradeLabel})
                          </span>
                        )}
                        {isCurrentClass && (
                          <Pill tone="brand">Lớp đang xem</Pill>
                        )}
                      </div>
                      <div className="flex items-center gap-2">
                        <Pill tone="bad">
                          {group.conflicts.length} xung đột
                        </Pill>
                        {group.classId !== "unassigned" && (
                          <button
                            type="button"
                            onClick={() => handleJumpToClassConflict(group.classId, group.conflicts[0]?.schedule)}
                            className="kbtn text-xs text-white font-bold px-2.5 py-1 flex items-center gap-1 shadow-sm cursor-pointer"
                            style={{ background: "#16665a" }}
                            title={`Chuyển ngay sang ${group.className} để xử lý lịch`}
                          >
                            <span>Điều chỉnh</span>
                            <span>→</span>
                          </button>
                        )}
                      </div>
                    </div>

                    <div className="space-y-1.5 text-xs">
                      {group.conflicts.map((c, idx) => (
                        <div
                          key={c.schedule.id || idx}
                          onClick={() => {
                            if (group.classId !== "unassigned") {
                              handleJumpToClassConflict(group.classId, c.schedule);
                            }
                          }}
                          className="flex items-start justify-between gap-2 p-2 rounded-control bg-white border border-line/50 hover:border-brand/40 hover:bg-brand/5 cursor-pointer transition"
                        >
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="font-semibold text-ink">
                                {c.dayLabel} ({c.timeRange}):
                              </span>
                              <span className="font-bold text-brand-strong">
                                {c.schedule.activity_name}
                              </span>
                              {c.schedule.room_name && (
                                <span className="text-ink-soft text-[11px] px-1.5 py-0.5 rounded bg-sunken">
                                  📍 {c.schedule.room_name}
                                </span>
                              )}
                            </div>
                            <div className="text-[#BB4A34] text-[11px] mt-0.5 font-medium">
                              ⚠️ {c.reason}
                            </div>
                          </div>
                          <span className="text-[11px] text-brand-strong font-semibold shrink-0 mt-0.5">
                            Sửa ↗
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </Modal>
      )}

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

function parseDayOfWeek(val: any): number | null {
  if (val === undefined || val === null) return null;
  const s = String(val).trim().toLowerCase();
  if (!s) return null;

  if (/^[2-7]$/.test(s)) return parseInt(s, 10);
  if (/^(t|thứ\s*|thu\s*)2$/i.test(s) || /^(thứ|thu)?\s*hai$/i.test(s) || /^(mon|monday)$/i.test(s)) return 2;
  if (/^(t|thứ\s*|thu\s*)3$/i.test(s) || /^(thứ|thu)?\s*ba$/i.test(s) || /^(tue|tuesday)$/i.test(s)) return 3;
  if (/^(t|thứ\s*|thu\s*)4$/i.test(s) || /^(thứ|thu)?\s*(tư|tu)$/i.test(s) || /^(wed|wednesday)$/i.test(s)) return 4;
  if (/^(t|thứ\s*|thu\s*)5$/i.test(s) || /^(thứ|thu)?\s*(năm|nam)$/i.test(s) || /^(thu|thursday)$/i.test(s)) return 5;
  if (/^(t|thứ\s*|thu\s*)6$/i.test(s) || /^(thứ|thu)?\s*(sáu|sau)$/i.test(s) || /^(fri|friday)$/i.test(s)) return 6;
  if (/^(t|thứ\s*|thu\s*)7$/i.test(s) || /^(thứ|thu)?\s*(bảy|bay)$/i.test(s) || /^(sat|saturday)$/i.test(s)) return 7;
  if (/^(cn|chủ\s*nhật|chu\s*nhat|sun|sunday)$/i.test(s)) return 8;

  return null;
}

function parseTimeRange(val: any): { start: string; end: string } | null {
  if (!val) return null;
  const s = String(val).trim();
  if (!s) return null;

  // Handles: 07:00 - 07:30, 07:00-07:30, 7h00 - 7h30, 7:00 - 7:30, 07:00 đến 07:30, 07:00 -> 07:30
  const match = s.match(/(\d{1,2})[h:](\d{2})?\s*(?:[-–—~]|đến|to|->)\s*(\d{1,2})[h:](\d{2})?/i);
  if (match) {
    const h1 = match[1].padStart(2, "0");
    const m1 = (match[2] || "00").padStart(2, "0");
    const h2 = match[3].padStart(2, "0");
    const m2 = (match[4] || "00").padStart(2, "0");
    return {
      start: `${h1}:${m1}`,
      end: `${h2}:${m2}`,
    };
  }

  const times = s.match(/\b\d{1,2}:\d{2}\b/g);
  if (times && times.length >= 2) {
    return {
      start: times[0].padStart(5, "0"),
      end: times[1].padStart(5, "0"),
    };
  }

  return null;
}