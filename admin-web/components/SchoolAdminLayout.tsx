/**
 * components/SchoolAdminLayout.tsx
 * ================================
 * Layout cho School Admin Web — 100% chuẩn Figma Garden Voice (Frame 05 - 10):
 *   - Sidebar trái 236px với logo, tên trường và 8 mục menu chức năng.
 *   - Menu active: nền #E6F3EB, chữ #087F70, bo góc 10px.
 *   - Ảnh minh họa khu vườn ở chân sidebar (180x68, bo góc 16px).
 *   - Topbar hiển thị tên trường, niên khóa 2026–2027 và user menu.
 */

import Link from "next/link";
import { useRouter } from "next/router";
import { ReactNode, useEffect, useState } from "react";
import {
  clearToken,
  getStoredSchoolAdmin,
  getToken,
} from "@/lib/api";

interface Props {
  children: ReactNode;
  active: "overview" | "teachers" | "students" | "parents" | "schedules" | "classes" | "health-exam" | "account" | "features" | string;
  pageTitle?: string;
  pageAction?: ReactNode;
}

interface NavLinkSpec {
  id: string;
  label: string;
  icon: string;
  href: string;
}

const PRIMARY_NAV: NavLinkSpec[] = [
  { id: "overview", label: "Tổng quan trường", icon: "dashboard", href: "/school-admin" },
  { id: "teachers", label: "Quản lý Giáo viên", icon: "school", href: "/school-admin/teachers" },
  { id: "students", label: "Quản lý Học sinh", icon: "child", href: "/school-admin/students" },
  { id: "parents", label: "Quản lý Phụ huynh", icon: "family", href: "/school-admin/parents" },
  { id: "schedules", label: "Thời khóa biểu", icon: "calendar", href: "/school-admin/schedules" },
  { id: "classes", label: "Quản lý Lớp học", icon: "class", href: "/school-admin/classes" },
  { id: "health-exam", label: "Khám sức khỏe", icon: "health", href: "/school-admin/health-exam" },
  { id: "account", label: "Tài khoản trường", icon: "person", href: "/school-admin/account" },
];

function NavIcon({ name }: { name: string }) {
  const size = 18;
  switch (name) {
    case "dashboard":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z" />
        </svg>
      );
    case "school":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 3L1 9l4 2.18v6L12 21l7-3.82v-6l2-1.09V17h2V9L12 3zm6.82 6L12 12.72 5.18 9 12 5.28 18.82 9z" />
        </svg>
      );
    case "child":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2a4 4 0 100 8 4 4 0 000-8zm-5 11c-2.67 0-8 1.34-8 4v3h16v-3c0-2.66-5.33-4-8-4z" />
        </svg>
      );
    case "family":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
        </svg>
      );
    case "calendar":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M19 4h-1V2h-2v2H8V2H6v2H5c-1.11 0-1.99.9-1.99 2L3 20c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10zm0-12H5V6h14v2z" />
        </svg>
      );
    case "class":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M4 6H2v14c0 1.1.9 2 2 2h14v-2H4V6zm16-4H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H8V4h12v12z" />
        </svg>
      );
    case "health":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z" />
        </svg>
      );
    case "person":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
        </svg>
      );
    default:
      return null;
  }
}

export default function SchoolAdminLayout({
  children,
  active,
  pageTitle,
  pageAction,
}: Props) {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [info, setInfo] = useState<{
    full_name: string;
    username: string;
    school_name?: string | null;
  } | null>(null);
  const [showMenu, setShowMenu] = useState(false);

  useEffect(() => {
    const stored = getStoredSchoolAdmin();
    const token = getToken("schoolAdmin");
    if (!token || !stored) {
      router.replace("/login");
      return;
    }
    setInfo({
      full_name: stored.full_name,
      username: stored.username,
      school_name: stored.school_name,
    });
    setReady(true);
  }, [router]);

  const handleLogout = () => {
    clearToken("schoolAdmin");
    router.replace("/login");
  };

  if (!ready) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#087F70]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-[#FFFFFF] text-[#102737] font-sans">
      {/* ─────────── Sidebar (Chuẩn Figma 236px) ─────────── */}
      <aside className="hidden lg:flex w-[236px] min-h-screen bg-white border-r border-[#E5E8EB] flex-col shrink-0 sticky top-0 h-screen">
        {/* Brand header */}
        <div className="p-[20px_14px_16px] border-b border-[#E5E8EB]">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-[#087F70] flex items-center justify-center text-white font-extrabold text-lg shadow-sm">
              K
            </div>
            <div className="overflow-hidden">
              <div className="font-extrabold text-[#06695E] text-base leading-tight tracking-tight">
                KinderLog
              </div>
              <div className="text-[11px] font-medium text-[#65727D] truncate" title={info?.school_name || "Quản trị trường"}>
                {info?.school_name || "Quản trị trường"}
              </div>
            </div>
          </div>
        </div>

        {/* Primary nav */}
        <nav className="flex-1 p-[14px_10px] space-y-1 overflow-y-auto">
          {PRIMARY_NAV.map((item) => {
            const isActive = item.id === active;
            return (
              <Link
                key={item.id}
                href={item.href}
                className={`flex items-center gap-2.5 px-3 py-2.5 rounded-[10px] text-sm font-semibold transition ${
                  isActive
                    ? "bg-[#E6F3EB] text-[#087F70]"
                    : "text-[#65727D] hover:bg-[#F6F7F8] hover:text-[#102737]"
                }`}
              >
                <NavIcon name={item.icon} />
                <span className="truncate">{item.label}</span>
              </Link>
            );
          })}

          <div className="pt-4 pb-1 px-3 text-[11px] font-bold text-[#8C9BA5] uppercase tracking-wider">
            Phân hệ khác
          </div>

          <Link
            href="/"
            className="flex items-center gap-2.5 px-3 py-2.5 rounded-[10px] text-sm font-semibold text-[#65727D] hover:bg-[#F6F7F8] hover:text-[#087F70] transition"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M20 8h-2.81c-.45-.78-1.07-1.45-1.82-1.96L17 4.41 15.59 3l-2.17 1.59C12.96 4.51 12.49 4.41 12 4.41s-.96.1-1.41.18L5 5l1.41 4.41C5.66 7.55 5.05 8.22 4.6 9H2v2h2.09c-.05.33-.09.66-.09 1v1H2v2h2v1c0 .34.04.67.09 1H2v2h2.81c1.04 1.79 2.97 3 5.19 3s4.15-1.21 5.19-3H20v-2h-3.09c.05-.33.09-.66.09-1v-1h3v-2h-3v-1c0-.34-.04-.67-.09-1H20V8zm-6 7h-4v-2h4v2zm0-4h-4v-2h4v2z" />
            </svg>
            Quản trị Bug Report
          </Link>
        </nav>

        {/* Garden Voice Illustration ở chân Sidebar (Figma 180x68) */}
        <div className="p-3 mt-auto border-t border-[#E5E8EB]/60">
          <img
            src="/images/teacher_garden.png"
            alt="Khu vườn KinderLog"
            className="w-[180px] h-[68px] object-cover rounded-[16px] mx-auto shadow-sm"
          />
          <div className="mt-2 text-center text-[11px] font-medium text-[#8C9BA5]">
            Trường Mầm non · 2026–2027
          </div>
        </div>
      </aside>

      {/* ─────────── Main column ─────────── */}
      <div className="flex-1 flex flex-col min-w-0 bg-[#FFFFFF]">
        {/* Topbar */}
        <header className="h-16 bg-white border-b border-[#E5E8EB] px-8 flex items-center justify-between sticky top-0 z-40">
          <div>
            <div className="font-bold text-base text-[#102737] leading-tight">
              {pageTitle || "Cổng Quản Trị Nhà Trường"}
            </div>
            <div className="text-xs text-[#65727D]">
              {info?.school_name || "Trường Mầm non"} · Năm học 2026–2027
            </div>
          </div>

          <div className="flex items-center gap-3">
            {pageAction && <div>{pageAction}</div>}

            <div className="relative">
              <button
                onClick={() => setShowMenu(!showMenu)}
                className="flex items-center gap-2.5 px-3 py-1.5 rounded-[10px] hover:bg-[#F6F7F8] transition"
              >
                <div className="w-8 h-8 rounded-full bg-[#087F70] text-white font-bold flex items-center justify-center text-xs">
                  {info?.full_name?.charAt(0).toUpperCase() || "T"}
                </div>
                <div className="text-left hidden sm:block">
                  <div className="text-sm font-bold text-[#102737] leading-tight">
                    {info?.full_name}
                  </div>
                  <div className="text-[11px] text-[#65727D] leading-tight">
                    @{info?.username}
                  </div>
                </div>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="#65727D">
                  <path d="M7 10l5 5 5-5z" />
                </svg>
              </button>

              {showMenu && (
                <div className="absolute right-0 top-12 w-64 bg-white rounded-[16px] shadow-pop border border-[#E5E8EB] p-2 z-50 animate-in fade-in slide-in-from-top-1">
                  <div className="px-3 py-2 border-b border-[#E5E8EB]">
                    <div className="font-bold text-sm text-[#102737]">
                      {info?.full_name}
                    </div>
                    <div className="text-xs text-[#65727D]">
                      @{info?.username}
                    </div>
                  </div>
                  <Link
                    href="/school-admin/account"
                    className="w-full mt-1 flex items-center gap-2 px-3 py-2 text-sm font-semibold text-[#102737] hover:bg-[#F6F7F8] rounded-[10px] transition"
                  >
                    <NavIcon name="person" />
                    Cài đặt tài khoản
                  </Link>
                  <button
                    onClick={handleLogout}
                    className="w-full mt-1 flex items-center gap-2 px-3 py-2 text-sm font-semibold text-[#A93832] hover:bg-[#FDEAE5] rounded-[10px] transition"
                  >
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z" />
                    </svg>
                    Đăng xuất
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Content body */}
        <main className="flex-1 p-8 overflow-y-auto max-w-[1400px] w-full mx-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
