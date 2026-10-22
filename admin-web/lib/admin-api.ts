/**
 * lib/admin-api.ts
 * =================
 * Type-safe wrapper cho các API school-admin CRUD.
 * Đồng bộ với backend/app/api/endpoints/admin.py + admin_dashboard.py.
 */

import { apiFetch } from "@/lib/api";

/* ════════ Classes ════════ */
export interface SchoolClass {
  id: string;
  name: string;
  grade_label: string;
  room_number: string;
}

export function getClasses(): Promise<SchoolClass[]> {
  return apiFetch<SchoolClass[]>("/api/admin/classes", { account: "schoolAdmin" });
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

export function updateChild(id: string, data: ChildPayload) {
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