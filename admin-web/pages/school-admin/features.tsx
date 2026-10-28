/**
 * pages/school-admin/features.tsx
 * ================================
 * Hub cho 4 danh mục CRUD: Giáo viên, Học sinh, Phụ huynh, Thời khóa biểu.
 * Pattern y hệt Flutter AdminDashboardScreen.tab_features:
 *   - 4 nút danh mục dạng wrap 2x2 (mobile) / row (desktop).
 *   - Click vào mỗi danh mục → /school-admin/teachers | students | parents | schedules.
 */

import Link from "next/link";
import { useEffect, useState } from "react";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import { getStoredSchoolAdmin, getToken } from "@/lib/api";
import {
  getParents,
  getTeachers,
  getChildren,
  getHealthExamRecords,
  getSchedules,
  getRooms,
  Room,
} from "@/lib/admin-api";

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

interface Tile {
  href: string;
  label: string;
  desc: string;
  icon: string;
  iconBg: string;
  iconColor: string;
  count?: number;
  badge?: number;
}

export default function SchoolAdminFeaturesPage() {
  const [ready, setReady] = useState(false);
  const [counts, setCounts] = useState<{
    teachers: number;
    students: number;
    parents: number;
    schedules: number;
    conflicts: number;
    healthExams: number;
  }>({
    teachers: 0,
    students: 0,
    parents: 0,
    schedules: 0,
    conflicts: 0,
    healthExams: 0,
  });

  useEffect(() => {
    const stored = getStoredSchoolAdmin();
    if (!getToken() || !stored) {
      window.location.href = "/login";
      return;
    }
    setReady(true);

    (async () => {
      try {
        const [teachers, students, parents, schedules, rooms, healthExams] =
          await Promise.all([
            getTeachers().catch(() => []),
            getChildren().catch(() => []),
            getParents().catch(() => []),
            getSchedules().catch(() => []),
            getRooms().catch(() => []),
            getHealthExamRecords()
              .then((r) => r.total)
              .catch(() => 0),
          ]);

        // Đếm số cặp tiết học bị xung đột trong tuần (loại trừ các khu vực sinh hoạt chung)
        let conflicts = 0;
        for (let i = 0; i < schedules.length; i++) {
          for (let j = i + 1; j < schedules.length; j++) {
            const a = schedules[i];
            const b = schedules[j];
            if (a.day_of_week !== b.day_of_week) continue;
            if (
              a.start_time &&
              b.start_time &&
              a.end_time &&
              b.end_time
            ) {
              const aS = toMin(a.start_time);
              const aE = toMin(a.end_time);
              const bS = toMin(b.start_time);
              const bE = toMin(b.end_time);
              if (aS < bE && aE > bS) {
                const sameClass = Boolean(a.class_id && b.class_id && a.class_id === b.class_id);
                const isShared = isSharedLocation(a.room_name, rooms);
                const sameRoom = Boolean(
                  !isShared &&
                  a.room_name &&
                  b.room_name &&
                  a.room_name.trim().toLowerCase() === b.room_name.trim().toLowerCase()
                );
                if (sameClass || sameRoom) {
                  conflicts++;
                }
              }
            }
          }
        }
        setCounts({
          teachers: teachers.length,
          students: students.length,
          parents: parents.length,
          schedules: schedules.length,
          conflicts,
          healthExams: typeof healthExams === "number" ? healthExams : 0,
        });
      } catch (_) {
        /* swallow */
      }
    })();
  }, []);

  if (!ready) return null;

  const tiles: Tile[] = [
    {
      href: "/school-admin/teachers",
      label: "Giáo viên",
      desc: "Quản lý tài khoản, lớp phụ trách",
      icon: "👨‍🏫",
      iconBg: "#E6EFEC",
      iconColor: "#16665a",
      count: counts.teachers,
    },
    {
      href: "/school-admin/students",
      label: "Học sinh",
      desc: "Hồ sơ, phụ huynh liên kết, dị ứng",
      icon: "🧒",
      iconBg: "#F6EED9",
      iconColor: "#8A5E12",
      count: counts.students,
    },
    {
      href: "/school-admin/parents",
      label: "Phụ huynh",
      desc: "Tài khoản, liên kết với học sinh",
      icon: "👪",
      iconBg: "#E7EEF3",
      iconColor: "#4B6F8C",
      count: counts.parents,
    },
    {
      href: "/school-admin/schedules",
      label: "Thời khóa biểu",
      desc: "Lịch học tuần, phát hiện xung đột",
      icon: "📅",
      iconBg: "#F6E6E1",
      iconColor: "#BB4A34",
      count: counts.schedules,
      badge: counts.conflicts,
    },
    {
      href: "/school-admin/health-exam",
      label: "Sổ sức khoẻ",
      desc: "Theo dõi sức khoẻ học sinh",
      icon: "📒",
      iconBg: "#E6EFEC",
      iconColor: "#16665a",
      count: counts.healthExams,
    },
  ];

  return (
    <SchoolAdminLayout active="features" pageTitle="Chức năng quản trị hệ thống">
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        {tiles.map((tile) => (
          <Link
            key={tile.href}
            href={tile.href}
            className="card p-4 hover:shadow-card transition group"
          >
            <div
              className="w-12 h-12 flex items-center justify-center rounded-control text-2xl mb-3"
              style={{ background: tile.iconBg, color: tile.iconColor }}
            >
              {tile.icon}
            </div>
            <div className="font-bold text-ink">{tile.label}</div>
            <div className="text-xs text-ink-soft mt-0.5 mb-2 line-clamp-2">
              {tile.desc}
            </div>
            <div className="flex items-center justify-between mt-2">
              <span className="text-xs text-ink-faint">
                {tile.count !== undefined ? `${tile.count} mục` : "Nhập Excel"}
              </span>
              {tile.badge ? (
                <span
                  className="text-[11px] font-bold px-1.5 py-0.5 rounded-full"
                  style={{ background: "#F6EED9", color: "#8A5E12" }}
                >
                  {tile.badge} xung đột
                </span>
              ) : null}
            </div>
          </Link>
        ))}
      </div>
    </SchoolAdminLayout>
  );
}

function toMin(t: string): number {
  const [h, m] = t.split(":").map((x) => parseInt(x, 10));
  if (isNaN(h) || isNaN(m)) return 0;
  return h * 60 + m;
}