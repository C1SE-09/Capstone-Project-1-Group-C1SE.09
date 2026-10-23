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
  ImportModal,
  ImportResult,
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
  const [importOpen, setImportOpen] = useState(false);

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
  }, [allSchedules, selectedClassId, classMap, rooms]);

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

  function handleExportExcel(exportAll = false) {
    const headers = [
      "Lớp",
      "Thứ",
      "Khung giờ",
      "Tên hoạt động",
      "Địa điểm / Phòng học",
      "Nội dung chi tiết",
    ];

    if (exportAll) {
      if (!allSchedules || allSchedules.length === 0) {
        setToast({ msg: "Chưa có hoạt động nào trong toàn trường để xuất", tone: "warn" });
        return;
      }

      const sheets: ExcelSheetData[] = [];

      // Duyệt qua từng lớp học để tạo sheet riêng
      for (const cl of classes) {
        const cScheds = allSchedules
          .filter((s) => s.class_id === cl.id)
          .sort((a, b) => {
            if (a.day_of_week !== b.day_of_week) return a.day_of_week - b.day_of_week;
            return (a.start_time || "").localeCompare(b.start_time || "");
          });

        if (cScheds.length > 0) {
          const cRows = cScheds.map((s) => [
            cl.name,
            DAY_LABELS[s.day_of_week - 2] || `Thứ ${s.day_of_week}`,
            s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : ""),
            s.activity_name,
            s.room_name || "",
            s.content || "",
          ]);
          sheets.push({
            sheetName: cl.name,
            headers,
            rows: cRows,
          });
        }
      }

      // Các hoạt động chưa phân lớp (nếu có)
      const unassignedScheds = allSchedules
        .filter((s) => !s.class_id || !classMap.has(s.class_id))
        .sort((a, b) => {
          if (a.day_of_week !== b.day_of_week) return a.day_of_week - b.day_of_week;
          return (a.start_time || "").localeCompare(b.start_time || "");
        });

      if (unassignedScheds.length > 0) {
        const unassignedRows = unassignedScheds.map((s) => [
          "Chưa phân lớp",
          DAY_LABELS[s.day_of_week - 2] || `Thứ ${s.day_of_week}`,
          s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : ""),
          s.activity_name,
          s.room_name || "",
          s.content || "",
        ]);
        sheets.push({
          sheetName: "Chưa phân lớp",
          headers,
          rows: unassignedRows,
        });
      }

      if (sheets.length === 0) {
        setToast({ msg: "Chưa có hoạt động nào trong toàn trường để xuất", tone: "warn" });
        return;
      }

      exportMultiSheetToExcel("thoi_khoa_bieu_toan_truong.xlsx", sheets);
      setToast({
        msg: `Đã xuất thời khóa biểu toàn trường ra ${sheets.length} sheet (theo từng lớp)`,
        tone: "ok",
      });
      return;
    }

    if (!selectedClassId) {
      setToast({ msg: "Vui lòng chọn một lớp để xuất thời khóa biểu", tone: "warn" });
      return;
    }

    const classScheds = (allSchedules ?? [])
      .filter((s) => s.class_id === selectedClassId)
      .sort((a, b) => {
        if (a.day_of_week !== b.day_of_week) return a.day_of_week - b.day_of_week;
        return (a.start_time || "").localeCompare(b.start_time || "");
      });

    const rows =
      classScheds.length > 0
        ? classScheds.map((s) => [
          currentClassName || "Lớp",
          DAY_LABELS[s.day_of_week - 2] || `Thứ ${s.day_of_week}`,
          s.time_range || (s.start_time && s.end_time ? `${s.start_time} - ${s.end_time}` : ""),
          s.activity_name,
          s.room_name || "",
          s.content || "",
        ])
        : [
          [
            currentClassName || "Lớp Mầm A",
            "Thứ 2",
            "07:00 - 07:30",
            "Đón trẻ, thể dục buổi sáng",
            "Sân cỏ",
            "Khởi động ngày mới, tập bài thể dục theo nhạc",
          ],
          [
            currentClassName || "Lớp Mầm A",
            "Thứ 2",
            "08:10 - 08:40",
            "Học hát & Vận động âm nhạc",
            "Phòng Âm nhạc & Vận động",
            "Tập bài hát Cháu yêu bà, vỗ tay theo phách",
          ],
        ];

    const filename = currentClassName
      ? `thoi_khoa_bieu_${currentClassName.replace(/\s+/g, "_")}.xlsx`
      : "thoi_khoa_bieu.xlsx";

    exportToExcel(filename, "ThoiKhoaBieu", headers, rows);
    setToast({
      msg: `Đã xuất ${classScheds.length} hoạt động của ${currentClassName || "lớp"} ra file Excel`,
      tone: "ok",
    });
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
            onClick={() => handleExportExcel(true)}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Xuất toàn bộ thời khóa biểu tất cả các lớp ra file Excel"
          >
            🏫 Xuất lịch toàn trường
          </button>
          <button
            onClick={() => handleExportExcel(false)}
            className="kbtn kbtn-secondary text-sm flex items-center gap-1.5"
            title="Xuất thời khóa biểu của lớp đang chọn ra file Excel"
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

      {/* Cảnh báo xung đột NẰM TRÊN PHẦN CHỌN LỚP (Chỉ hiện khi có xung đột) */}
      {selectedClassId && allSchedules && weeklyConflicts.length > 0 && (
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
              className={`px-4 py-2 flex items-center justify-between border-b text-xs font-semibold transition-colors duration-200 ${
                selectedIds.length > 0
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
                    className={`flex items-start gap-3 px-4 py-3 transition-all duration-300 ${
                      idx > 0 ? "border-t border-line" : ""
                    } ${
                      isSelected
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