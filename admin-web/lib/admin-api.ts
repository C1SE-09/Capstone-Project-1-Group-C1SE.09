/**
 * lib/admin-api.ts
 * =================
 * Type-safe wrapper cho các API school-admin CRUD.
 * Đồng bộ với backend/app/api/endpoints/admin.py + admin_dashboard.py.
 */

import { apiFetch, apiFetchBlob } from "@/lib/api";

/* ════════ Classes ════════ */
export interface SchoolClass {
  id: string;
  name: string;
  grade_label: string;
  room_number: string;
  capacity?: number | null;
  student_count?: number;
}

export interface ClassPayload {
  name: string;
  grade_label?: string | null;
  room_number?: string | null;
  capacity?: number | null;
}

export function getClasses(): Promise<SchoolClass[]> {
  return apiFetch<SchoolClass[]>("/api/admin/classes", { account: "schoolAdmin" });
}

export function createClass(data: ClassPayload) {
  return apiFetch<{ id: string; message: string }>("/api/admin/classes", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}

export function updateClass(id: string, data: ClassPayload) {
  return apiFetch<{ message: string }>(`/api/admin/classes/${id}`, {
    method: "PUT",
    body: data,
    account: "schoolAdmin",
  });
}

export function deleteClass(id: string) {
  return apiFetch<{ message: string }>(`/api/admin/classes/${id}`, {
    method: "DELETE",
    account: "schoolAdmin",
  });
}

export function deleteClassesBatch(ids: string[]) {
  return apiFetch<{ message: string; deleted_count: number; blocked?: string[] }>(`/api/admin/classes/batch-delete`, {
    method: "POST",
    body: { ids },
    account: "schoolAdmin",
  });
}

/* ════════ Teachers ════════ */
export interface Teacher {
  id: string;
  full_name: string;
  email: string;
  phone: string;
  username: string | null;
  class_id: string | null;
  class_ids: string[];
  class_name: string;
  classes: { id: string; name: string }[];
  status: string;
}

export interface TeacherPayload {
  full_name: string;
  email: string;
  phone: string;
  username?: string | null;
  password?: string | null;
  class_id?: string | null;
  class_ids?: string[] | null;
  status?: string;
}

export function getTeachers() {
  return apiFetch<Teacher[]>("/api/admin/teachers", { account: "schoolAdmin" });
}

export function createTeacher(data: TeacherPayload) {
  return apiFetch<{ id: string; message: string }>("/api/admin/teachers", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}

export function updateTeacher(id: string, data: TeacherPayload) {
  return apiFetch<{ message: string }>(`/api/admin/teachers/${id}`, {
    method: "PUT",
    body: data,
    account: "schoolAdmin",
  });
}

export function deleteTeacher(id: string) {
  return apiFetch<{ message: string }>(`/api/admin/teachers/${id}`, {
    method: "DELETE",
    account: "schoolAdmin",
  });
}

export function deleteTeachersBatch(ids: string[]) {
  return apiFetch<{ message: string; deleted_count: number }>(`/api/admin/teachers/batch-delete`, {
    method: "POST",
    body: { ids },
    account: "schoolAdmin",
  });
}

/* ════════ Parents ════════ */
export interface Parent {
  id: string;
  full_name: string;
  phone: string;
  email: string;
  username: string | null;
  status: string;
  relationship: string;
  children_summary: string;
  child_id: string | null;
  child_ids: string[];
  children: { id: string; name: string; class_name: string; class_id?: string | null }[];
}

export interface ParentPayload {
  full_name: string;
  phone: string;
  email?: string | null;
  relationship?: string | null;
  username?: string | null;
  password?: string | null;
  child_id?: string | null;
  child_ids?: string[] | null;
  status?: string;
}

export function getParents() {
  return apiFetch<Parent[]>("/api/admin/parents", { account: "schoolAdmin" });
}

export function createParent(data: ParentPayload) {
  return apiFetch<{ id: string; message: string }>("/api/admin/parents", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}

export function updateParent(id: string, data: ParentPayload) {
  return apiFetch<{ message: string }>(`/api/admin/parents/${id}`, {
    method: "PUT",
    body: data,
    account: "schoolAdmin",
  });
}

export function deleteParent(id: string) {
  return apiFetch<{ message: string }>(`/api/admin/parents/${id}`, {
    method: "DELETE",
    account: "schoolAdmin",
  });
}

export function deleteParentsBatch(ids: string[]) {
  return apiFetch<{ message: string; deleted_count: number }>(`/api/admin/parents/batch-delete`, {
    method: "POST",
    body: { ids },
    account: "schoolAdmin",
  });
}

/* ════════ Children (Students) ════════ */
export interface ChildParent {
  id: string;
  name: string;
  phone: string;
  email: string;
  relationship: string;
  is_primary: boolean;
  can_pickup: boolean;
}

export interface Child {
  id: string;
  full_name: string;
  nickname: string;
  class_id: string | null;
  class_name: string;
  parent_id: string | null;
  parent_name: string | null;
  parent_phone: string | null;
  parents: ChildParent[];
  parent_ids: string[];
  parents_summary: string;
  date_of_birth: string | null;
  gender: string;
  note: string;
  allergy_status: string; // unknown | none | present
  care_notes: string;
  health_version: number;
  status: string;
}

export interface ChildPayload {
  full_name: string;
  nickname?: string | null;
  class_id?: string | null;
  parent_id?: string | null;
  parent_ids?: string[] | null;
  parent_items?: { parent_id: string; relationship: string; is_primary: boolean; can_pickup: boolean }[] | null;
  medical_allergies?: string | null;
  allergy_status?: string;
  care_notes?: string | null;
  date_of_birth?: string | null;
  gender?: string;
  status?: string;
}

export function getChildren() {
  return apiFetch<Child[]>("/api/admin/children", { account: "schoolAdmin" });
}

export function createChild(data: ChildPayload) {
  return apiFetch<{ id: string; message: string }>("/api/admin/children", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}

export function updateChild(id: string, data: Partial<ChildPayload>) {
  return apiFetch<{ message: string }>(`/api/admin/children/${id}`, {
    method: "PUT",
    body: data,
    account: "schoolAdmin",
  });
}

export function deleteChild(id: string) {
  return apiFetch<{ message: string }>(`/api/admin/children/${id}`, {
    method: "DELETE",
    account: "schoolAdmin",
  });
}

export function deleteChildrenBatch(ids: string[]) {
  return apiFetch<{ message: string; deleted_count: number }>(`/api/admin/children/batch-delete`, {
    method: "POST",
    body: { ids },
    account: "schoolAdmin",
  });
}

/* ════════ Schedules & Time Slots ════════ */
export interface TimeSlot {
  id: string;
  name: string;
  start_time: string;
  end_time: string;
  order_index: number;
}

export interface Schedule {
  id: string;
  activity_name: string;
  content: string;
  class_id?: string;
  room_name: string;
  time_range: string;
  slot_id: string | null;
  start_time: string | null;
  end_time: string | null;
  day_of_week: number;
  is_active: boolean;
}

export interface SchedulePayload {
  class_id?: string | null;
  activity_name: string;
  content?: string | null;
  room_name?: string | null;
  slot_id?: string | null;
  start_time?: string | null;
  end_time?: string | null;
  day_of_week: number;
}

export function getTimeSlots() {
  return apiFetch<TimeSlot[]>("/api/admin/time-slots", { account: "schoolAdmin" });
}

export function getSchedules(
  classIdOrDay?: string | number | null,
  dayOfWeek?: number,
) {
  let classId: string | null = null;
  let day: number | undefined = undefined;

  if (typeof classIdOrDay === "number") {
    day = classIdOrDay;
  } else if (typeof classIdOrDay === "string") {
    classId = classIdOrDay;
    day = dayOfWeek;
  } else {
    day = dayOfWeek;
  }

  const query: Record<string, any> = {};
  if (classId) query.class_id = classId;
  if (day !== undefined) query.day_of_week = day;

  return apiFetch<Schedule[]>("/api/admin/schedules", {
    query,
    account: "schoolAdmin",
  });
}

export function createSchedule(data: SchedulePayload) {
  return apiFetch<{ id: string; message: string }>("/api/admin/schedules", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}

export function updateSchedule(id: string, data: Partial<SchedulePayload>) {
  return apiFetch<{ message: string }>(`/api/admin/schedules/${id}`, {
    method: "PUT",
    body: data,
    account: "schoolAdmin",
  });
}

export function deleteSchedule(id: string) {
  return apiFetch<{ message: string }>(`/api/admin/schedules/${id}`, {
    method: "DELETE",
    account: "schoolAdmin",
  });
}

export function deleteSchedulesBatch(ids: string[]) {
  return apiFetch<{ message: string; deleted_count: number }>(`/api/admin/schedules/batch-delete`, {
    method: "POST",
    body: { ids },
    account: "schoolAdmin",
  });
}

/* ════════ Rooms & Facilities ════════ */
export interface Room {
  id: string;
  name: string;
  room_type: "CLASSROOM" | "FUNCTIONAL" | "OUTDOOR" | "COMMON";
  class_id: string | null;
  capacity?: number | null;
  is_shared: boolean;
}

export function getRooms(classId?: string | null) {
  const query: Record<string, any> = {};
  if (classId) query.class_id = classId;
  return apiFetch<Room[]>("/api/admin/rooms", {
    query,
    account: "schoolAdmin",
  });
}

export function createRoom(data: {
  name: string;
  room_type?: string;
  class_id?: string | null;
  capacity?: number;
  is_shared?: boolean;
}) {
  return apiFetch<{ id: string; message: string }>("/api/admin/rooms", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}

/* ════════ Availability check (for duplicate username/email/phone) ════════ */
export interface AvailabilityCheck {
  username_exists: boolean;
  email_exists: boolean;
  phone_exists: boolean;
}

export function checkAvailability(
  type: "teacher" | "parent",
  params: { username?: string; email?: string; phone?: string; exclude_id?: string },
) {
  return apiFetch<AvailabilityCheck>("/api/admin/check-availability", {
    query: { type, ...params } as any,
    account: "schoolAdmin",
  });
}

/* ════════ Health Exam (sổ sức khoẻ — template + import) ════════ */
export interface HealthExamRowIssue {
  row_number: number;
  sheet_name?: string | null;
  child_id?: string | null;
  full_name?: string | null;
  errors: string[];
  warnings: string[];
}

export interface HealthExamImportResult {
  total_rows: number;
  success_count: number;
  failed_count: number;
  created_count: number;
  updated_count: number;
  errors: HealthExamRowIssue[];
}

/** Một dòng trong bảng sổ sức khoẻ — theo học sinh (có thể chưa có số liệu). */
export interface HealthExamRecord {
  id?: string | null;
  child_id: string;
  full_name: string;
  nickname?: string | null;
  class_id?: string | null;
  class_name?: string | null;
  date_of_birth?: string | null;
  gender?: string | null;
  examination_date?: string | null;
  height?: number | null;
  weight?: number | null;
  bmi?: number | null;
  health_category?: string | null;
  health_category_label?: string | null;
  general_conclusion?: string | null;
  created_by_name?: string | null;
  has_record?: boolean;
}

export interface HealthExamRecordsResult {
  total: number;
  records: HealthExamRecord[];
  stats: { normal?: number; underweight?: number; overweight?: number };
}

/** Lấy danh sách bản ghi sổ sức khoẻ (có thể lọc theo lớp / ngày ghi nhận). */
export function getHealthExamRecords(params?: {
  class_id?: string;
  examination_date?: string;
}) {
  return apiFetch<HealthExamRecordsResult>("/api/health-exam/records", {
    query: params as any,
    account: "schoolAdmin",
  });
}

export async function downloadHealthExamTemplate(
  classId?: string,
  examinationDate?: string,
  filename?: string
) {
  const { blob, headers } = await apiFetchBlob("/api/health-exam/template", {
    query: {
      ...(classId ? { class_id: classId } : {}),
      examination_date: examinationDate,
    },
  });
  // Lấy tên file gợi ý từ header Content-Disposition của backend
  let outName = filename || "Mau_So_Suc_Khoe.xlsx";
  const disp = headers.get("Content-Disposition");
  if (disp) {
    const utf8Match = disp.match(/filename\*=UTF-8''([^;]+)/i);
    const asciiMatch = disp.match(/filename="([^"]+)"/i);
    try {
      if (utf8Match) outName = decodeURIComponent(utf8Match[1]);
      else if (asciiMatch) outName = asciiMatch[1];
    } catch {
      /* giữ tên mặc định */
    }
  }
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = outName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.URL.revokeObjectURL(url);
}

/** Gửi file Excel kết quả lên backend, nhận báo cáo từng dòng. */
export function importHealthExamFile(classId: string | null, file: File) {
  const form = new FormData();
  if (classId) form.append("class_id", classId);
  form.append("file", file, file.name);
  return apiFetch<HealthExamImportResult>("/api/health-exam/import", {
    method: "POST",
    body: form,
    isFormData: true,
    account: "schoolAdmin",
  });
}

/** Sửa số liệu 1 dòng sổ sức khoẻ (chiều cao, cân nặng, kết luận chung).
 *  Cho phép bỏ trống chiều cao hoặc cân nặng — chỉ cần có 1 trong 3 thông tin. */
export function updateHealthExamRecord(
  id: string,
  data: {
    height?: number | null;
    weight?: number | null;
    general_conclusion?: string | null;
  },
) {
  return apiFetch<HealthExamRecord>(`/api/health-exam/records/${id}`, {
    method: "PUT",
    body: data,
    account: "schoolAdmin",
  });
}

/** Tạo mới bản ghi sức khoẻ cho bé chưa có số liệu.
 *  Cho phép bỏ trống chiều cao hoặc cân nặng — chỉ cần có 1 trong 3 thông tin. */
export function createHealthExamRecord(data: {
  child_id: string;
  height?: number | null;
  weight?: number | null;
  general_conclusion?: string | null;
  examination_date?: string | null;
}) {
  return apiFetch<HealthExamRecord>("/api/health-exam/records", {
    method: "POST",
    body: data,
    account: "schoolAdmin",
  });
}