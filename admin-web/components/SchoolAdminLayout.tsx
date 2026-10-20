/**
 * components/SchoolAdminLayout.tsx
 * ================================
 * Layout cho School Admin Web — y hệt AdminDashboardScreen bên Flutter:
 *   - Sidebar trái (desktop) với logo + menu chính.
 *   - Topbar trên cùng với school name + user menu.
 *   - Vùng content cuộn độc lập.
 *
 * Tabs: Tổng quan / Chức năng / Tài khoản (mapping sang route).
 */

import Link from "next/link";
import { useRouter } from "next/router";
import { ReactNode, useEffect, useState } from "react";
import {
  clearToken,
  getStoredSchoolAdmin,
  setToken,
  getToken,
} from "@/lib/api";

interface Props {
  children: ReactNode;
  /** Tab hiện tại để highlight menu. */
  active: "overview" | "features" | "account" | string;
  /** Tiêu đề trang (hiển thị ở topbar). */
  pageTitle?: string;
  /** Nội dung phụ ở header (vd: nút "Thêm"). */
  pageAction?: ReactNode;
}

interface NavLinkSpec {
  id: string;
  label: string;
  icon: string;
  href: string;
}

const PRIMARY_NAV: NavLinkSpec[] = [
  { id: "overview", label: "Tổng quan", icon: "grid_view", href: "/school-admin" },
  {
    id: "features",
    label: "Chức năng",
    icon: "tune",
    href: "/school-admin/features",
  },
  {
    id: "account",
    label: "Tài khoản",
    icon: "person",
    href: "/school-admin/account",
  },
];

// SVG icon (inline để khỏi cần icon library)
function Icon({ name, className = "ic" }: { name: string; className?: string }) {
  const size = 20;
  switch (name) {
    case "grid_view":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
          <path d="M3 11h8V3H3v8zm0 10h8v-8H3v8zm10 0h8v-8h-8v8zm0-18v8h8V3h-8z" />
        </svg>
      );
    case "tune":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
          <path d="M3 17v2h6v-2H3zM3 5v2h10V5H3zm10 16v-2h8v-2h-8v-2h-2v6h2zM7 9v2H3v2h4v2h2V9H7zm14 4v-2H11v2h10zm-6-4h2V7h4V5h-4V3h-2v6z" />
        </svg>
      );
    case "person":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
          <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
        </svg>
      );
    case "logout":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
          <path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z" />
        </svg>
      );
    case "spinner":
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={`${className} animate-spin`}>
          <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" opacity="0.25" />
          <path d="M12 2a10 10 0 0 1 10 10" stroke="currentColor" strokeWidth="3" />
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
      <div className="min-h-screen flex items-center justify-center bg-canvas">
        <Icon name="spinner" className="text-brand-400" />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-canvas">
      {/* ─────────── Sidebar ─────────── */}
      <aside className="hidden lg:flex w-64 bg-white border-r border-line flex-col">
        {/* Brand header */}
        <div className="px-5 py-5 border-b border-line">
          <div className="flex items-center gap-3">
            <div
              className="flex items-center justify-center text-white"
              style={{
                width: 38,
                height: 38,
                borderRadius: 8,
                background:
                  "linear-gradient(135deg, #16665a 0%, rgba(22,102,90,0.8) 100%)",
              }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="white">
                <path d="M12 3C7 3 4 6.5 4 9.5C4 11.4 5.1 12.9 6.7 13.8C5.6 14.6 5 15.7 5 16.8C5 18.7 6.8 20 9.5 20H14.5C17.2 20 19 18.7 19 16.8C19 15.7 18.4 14.6 17.3 13.8C18.9 12.9 20 11.4 20 9.5C20 6.5 17 3 12 3Z" />
              </svg>
            </div>
            <div>
              <div className="font-bold text-ink text-sm tracking-tight">
                KinderLog
              </div>
              <div className="text-xs text-ink-soft">Admin trường</div>
            </div>
          </div>
        </div>

        {/* Primary nav */}
        <nav className="flex-1 px-3 py-4 space-y-1">
          {PRIMARY_NAV.map((item) => {
            const isActive = item.id === active;
            return (
              <Link
                key={item.id}
                href={item.href}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-control text-sm font-medium transition ${
                  isActive
                    ? "bg-brand-50 text-brand-600"
                    : "text-ink-soft hover:bg-sunken"
                }`}
                style={isActive ? { background: "#E6EFEC", color: "#114F46" } : {}}
              >
                <span style={{ color: isActive ? "#16665a" : "#605D57" }}>
                  <Icon name={item.icon} />
                </span>
                {item.label}
              </Link>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-line text-xs text-ink-faint">
          <div>v1.0.0 · School Admin Web</div>
        </div>
      </aside>

      {/* ─────────── Main column ─────────── */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Topbar */}
        <header
          className="bg-white border-b border-line flex items-center"
          style={{ height: 64, padding: "0 20px" }}
        >
          {/* Mobile brand */}
          <div className="lg:hidden flex items-center gap-2 mr-3">
            <div
              className="flex items-center justify-center text-white"
              style={{ width: 32, height: 32, borderRadius: 8, background: "#16665a" }}
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="white">
                <path d="M12 3C7 3 4 6.5 4 9.5C4 11.4 5.1 12.9 6.7 13.8C5.6 14.6 5 15.7 5 16.8C5 18.7 6.8 20 9.5 20H14.5C17.2 20 19 18.7 19 16.8C19 15.7 18.4 14.6 17.3 13.8C18.9 12.9 20 11.4 20 9.5C20 6.5 17 3 12 3Z" />
              </svg>
            </div>
            <span className="font-bold text-ink">KinderLog</span>
          </div>

          <div className="flex-1 min-w-0">
            <div className="text-[11px] font-semibold text-ink-faint uppercase tracking-wider">
              Trường
            </div>
            <div className="text-sm font-bold text-ink truncate">
              {info?.school_name || "Trường Mầm Non"}
            </div>
          </div>

          {pageAction && <div className="hidden md:flex mr-3">{pageAction}</div>}

          <div className="relative">
            <button
              onClick={() => setShowMenu(!showMenu)}
              className="flex items-center gap-2 px-2.5 py-1.5 rounded-control hover:bg-sunken"
            >
              <div
                className="flex items-center justify-center font-bold text-sm text-white"
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: 999,
                  background: "#16665a",
                }}
              >
                {info?.full_name?.charAt(0).toUpperCase() || "A"}
              </div>
              <div className="text-left hidden sm:block">
                <div className="text-sm font-semibold text-ink leading-tight">
                  {info?.full_name}
                </div>
                <div className="text-xs text-ink-soft leading-tight">
                  @{info?.username}
                </div>
              </div>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="#757169">
                <path d="M7 10l5 5 5-5z" />
              </svg>
            </button>

            {showMenu && (
              <div
                className="absolute right-0 mt-2 w-64 bg-white rounded-card shadow-pop border border-line z-50"
                style={{ top: "100%" }}
              >
                <div className="px-4 py-3 border-b border-line">
                  <div className="font-semibold text-sm text-ink">
                    {info?.full_name}
                  </div>
                  <div className="text-xs text-ink-soft truncate">
                    @{info?.username}
                  </div>
                </div>
                <button
                  onClick={() => {
                    setShowMenu(false);
                    router.push("/school-admin/account");
                  }}
                  className="w-full text-left px-4 py-2.5 text-sm text-ink hover:bg-sunken flex items-center gap-2"
                >
                  <Icon name="person" /> Tài khoản của tôi
                </button>
                <button
                  onClick={handleLogout}
                  className="w-full text-left px-4 py-2.5 text-sm text-bad hover:bg-bad-tint flex items-center gap-2 rounded-b-card"
                >
                  <Icon name="logout" /> Đăng xuất
                </button>
              </div>
            )}
          </div>
        </header>

        {/* Page title strip */}
        {pageTitle && (
          <div className="bg-white px-6 py-4 border-b border-line">
            <h1 className="text-xl font-bold text-ink">{pageTitle}</h1>
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-auto">
          <div className="max-w-7xl mx-auto p-4 lg:p-6">{children}</div>
        </div>

        {/* Mobile bottom nav (y hệt Flutter NavigationBar) */}
        <nav className="lg:hidden bg-white border-t border-line flex justify-around py-2">
          {PRIMARY_NAV.map((item) => {
            const isActive = item.id === active;
            return (
              <Link
                key={item.id}
                href={item.href}
                className="flex flex-col items-center gap-1 py-1.5 px-4"
                style={{ color: isActive ? "#16665a" : "#605D57" }}
              >
                <Icon name={item.icon} />
                <span className="text-[11px] font-semibold">{item.label}</span>
              </Link>
            );
          })}
        </nav>
      </div>
    </div>
  );
}