/**
 * components/AdminLayout.tsx
 * ==========================
 * Layout cho Web Admin (quản lý hệ thống & bug reports).
 * Chuẩn Figma Garden Voice (Frame 02, 03, 04):
 *   - Sidebar rộng 236px, viền phải #E5E8EB
 *   - Menu active nền #E6F3EB, chữ #087F70, bo góc 10px
 *   - Ảnh minh họa khu vườn ở chân sidebar (180x68, bo góc 16px)
 */

import { useRouter } from "next/router";
import Link from "next/link";
import { ReactNode, useEffect, useState } from "react";
import {
  clearToken,
  getStoredAdmin,
  getToken,
  type AdminAppInfo,
} from "@/lib/api";

interface Props {
  children: ReactNode;
  currentPage?: "dashboard" | "bug-reports";
}

export default function AdminLayout({ children, currentPage = "dashboard" }: Props) {
  const router = useRouter();
  const [admin, setAdmin] = useState<AdminAppInfo | null>(null);
  const [showMenu, setShowMenu] = useState(false);
  const [isAuthorized, setIsAuthorized] = useState(false);

  useEffect(() => {
    const token = getToken("adminApp");
    const a = getStoredAdmin();
    if (token && a) {
      setAdmin(a);
      setIsAuthorized(true);
    } else {
      clearToken("adminApp");
      router.replace("/login");
    }
  }, [router]);

  const handleLogout = () => {
    clearToken("adminApp");
    router.replace("/login");
  };

  if (!isAuthorized) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#087F70]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-[#FFFFFF] text-[#102737] font-sans">
      {/* ─────── Sidebar (Chuẩn Figma 236px) ─────── */}
      <aside className="w-[236px] min-h-screen bg-white flex flex-col border-r border-[#E5E8EB] shrink-0 sticky top-0 h-screen">
        {/* Brand Header */}
        <div className="p-[20px_14px_16px] border-b border-[#E5E8EB]">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-[#087F70] flex items-center justify-center text-white font-extrabold text-lg shadow-sm">
              K
            </div>
            <div>
              <div className="font-extrabold text-[#06695E] text-base leading-tight tracking-tight">
                KinderLog
              </div>
              <div className="text-[11px] font-medium text-[#65727D]">
                Quản trị hệ thống
              </div>
            </div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-[14px_10px] space-y-1.5 overflow-y-auto">
          <Link
            href="/"
            className={`flex items-center gap-2.5 px-3 py-2.5 rounded-[10px] text-sm font-semibold transition ${
              currentPage === "dashboard"
                ? "bg-[#E6F3EB] text-[#087F70]"
                : "text-[#65727D] hover:bg-[#F6F7F8] hover:text-[#102737]"
            }`}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z" />
            </svg>
            Tổng quan hệ thống
          </Link>

          <Link
            href="/bug-reports"
            className={`flex items-center justify-between px-3 py-2.5 rounded-[10px] text-sm font-semibold transition ${
              currentPage === "bug-reports"
                ? "bg-[#E6F3EB] text-[#087F70]"
                : "text-[#65727D] hover:bg-[#F6F7F8] hover:text-[#102737]"
            }`}
          >
            <div className="flex items-center gap-2.5">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M20 8h-2.81c-.45-.78-1.07-1.45-1.82-1.96L17 4.41 15.59 3l-2.17 1.59C12.96 4.51 12.49 4.41 12 4.41s-.96.1-1.41.18L5 5l1.41 4.41C5.66 7.55 5.05 8.22 4.6 9H2v2h2.09c-.05.33-.09.66-.09 1v1H2v2h2v1c0 .34.04.67.09 1H2v2h2.81c1.04 1.79 2.97 3 5.19 3s4.15-1.21 5.19-3H20v-2h-3.09c.05-.33.09-.66.09-1v-1h3v-2h-3v-1c0-.34-.04-.67-.09-1H20V8zm-6 7h-4v-2h4v2zm0-4h-4v-2h4v2z" />
              </svg>
              <span>Báo lỗi ứng dụng</span>
            </div>
          </Link>

          <div className="pt-4 pb-1 px-3 text-[11px] font-bold text-[#8C9BA5] uppercase tracking-wider">
            Chuyển phân hệ
          </div>

          <Link
            href="/school-admin"
            className="flex items-center gap-2.5 px-3 py-2.5 rounded-[10px] text-sm font-semibold text-[#65727D] hover:bg-[#F6F7F8] hover:text-[#087F70] transition"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 3L1 9l4 2.18v6L12 21l7-3.82v-6l2-1.09V17h2V9L12 3zm6.82 6L12 12.72 5.18 9 12 5.28 18.82 9zM17 15.99l-5 2.73-5-2.73v-3.72L12 15l5-2.73v3.72z" />
            </svg>
            Quản trị trường học
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
            KinderLog Garden Voice v2.0
          </div>
        </div>
      </aside>

      {/* ─────── Main Content Area ─────── */}
      <main className="flex-1 flex flex-col min-w-0 bg-[#FFFFFF]">
        {/* Topbar */}
        <header className="h-16 bg-white border-b border-[#E5E8EB] px-8 flex items-center justify-between sticky top-0 z-40">
          <div className="text-sm font-medium text-[#65727D]">
            Cổng điều hành & Hỗ trợ kỹ thuật KinderLog
          </div>

          <div className="relative">
            <button
              onClick={() => setShowMenu(!showMenu)}
              className="flex items-center gap-2.5 px-3 py-1.5 rounded-[10px] hover:bg-[#F6F7F8] transition"
            >
              <div className="w-8 h-8 rounded-full bg-[#087F70] text-white font-bold flex items-center justify-center text-xs">
                {admin?.full_name?.charAt(0).toUpperCase() || "A"}
              </div>
              <div className="text-left hidden sm:block">
                <div className="text-sm font-bold text-[#102737] leading-tight">
                  {admin?.full_name || "Admin"}
                </div>
                <div className="text-[11px] text-[#65727D] leading-tight">
                  {admin?.email}
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
                    {admin?.full_name}
                  </div>
                  <div className="text-xs text-[#65727D] truncate">
                    {admin?.email}
                  </div>
                </div>
                <button
                  onClick={handleLogout}
                  className="w-full mt-1.5 flex items-center gap-2 px-3 py-2 text-sm font-semibold text-[#A93832] hover:bg-[#FDEAE5] rounded-[10px] transition"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z" />
                  </svg>
                  Đăng xuất
                </button>
              </div>
            )}
          </div>
        </header>

        {/* Page Body */}
        <div className="flex-1 p-8 overflow-y-auto max-w-[1400px] w-full mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
}
