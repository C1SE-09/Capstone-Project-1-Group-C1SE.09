/**
 * components/AdminLayout.tsx
 * ==========================
 * Layout cho Web Admin (dev team) — quản lý bug reports.
 * Đã restyle theo theme KinderLog (brand teal #16665A) để đồng bộ với School Admin.
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
      <div className="min-h-screen flex items-center justify-center bg-canvas">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-brand-400" />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-canvas">
      {/* ─────── Sidebar ─────── */}
      <aside className="w-64 bg-white flex flex-col border-r border-line">
        {/* Logo */}
        <div className="px-5 py-5 border-b border-line">
          <div className="flex items-center gap-2.5">
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
              <div className="text-xs text-ink-soft">Admin Web</div>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1">
          <Link
            href="/"
            className={`flex items-center gap-3 px-3 py-2.5 rounded-control text-sm font-semibold transition ${
              currentPage === "dashboard"
                ? ""
                : "text-ink-soft hover:bg-sunken"
            }`}
            style={
              currentPage === "dashboard"
                ? { background: "#E6EFEC", color: "#114F46" }
                : {}
            }
          >
            <span
              style={{ color: currentPage === "dashboard" ? "#16665a" : "#605D57" }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z" />
              </svg>
            </span>
            Trang chủ
          </Link>
          <Link
            href="/bug-reports"
            className={`flex items-center gap-3 px-3 py-2.5 rounded-control text-sm font-semibold transition ${
              currentPage === "bug-reports"
                ? ""
                : "text-ink-soft hover:bg-sunken"
            }`}
            style={
              currentPage === "bug-reports"
                ? { background: "#E6EFEC", color: "#114F46" }
                : {}
            }
          >
            <span
              style={{ color: currentPage === "bug-reports" ? "#16665a" : "#605D57" }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M20 8h-2.81c-.45-.78-1.07-1.45-1.82-1.96L17 4.41 15.59 3l-2.17 1.59C12.96 4.51 12.49 4.41 12 4.41s-.96.1-1.41.18L5 5l1.41 4.41C5.66 7.55 5.05 8.22 4.6 9H2v2h2.09c-.05.33-.09.66-.09 1v1H2v2h2v1c0 .34.04.67.09 1H2v2h2.81c1.04 1.79 2.97 3 5.19 3s4.15-1.21 5.19-3H20v-2h-3.09c.05-.33.09-.66.09-1v-1h3v-2h-3v-1c0-.34-.04-.67-.09-1H20V8zm-6 7h-4v-2h4v2zm0-4h-4v-2h4v2z" />
              </svg>
            </span>
            Quản lý Bug Report
          </Link>
        </nav>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-line text-xs text-ink-faint">
          <div>v1.0.0 · Admin Web</div>
        </div>
      </aside>

      {/* ─────── Main ─────── */}
      <main className="flex-1 flex flex-col min-w-0">
        {/* Topbar */}
        <header className="h-16 bg-white border-b border-line px-6 flex items-center justify-end relative">
          <button
            onClick={() => setShowMenu(!showMenu)}
            className="flex items-center gap-2 px-3 py-1.5 rounded-control hover:bg-sunken"
          >
            <div
              className="w-9 h-9 rounded-full flex items-center justify-center font-bold text-white"
              style={{ background: "#16665a" }}
            >
              {admin?.full_name?.charAt(0).toUpperCase() || "A"}
            </div>
            <div className="text-left hidden sm:block">
              <div className="text-sm font-semibold text-ink leading-tight">
                {admin?.full_name || "Admin"}
              </div>
              <div className="text-xs text-ink-soft leading-tight">
                {admin?.email}
              </div>
            </div>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="#757169">
              <path d="M7 10l5 5 5-5z" />
            </svg>
          </button>

          {showMenu && (
            <div className="absolute right-6 top-14 w-72 bg-white rounded-card shadow-pop border border-line z-50">
              <div className="px-4 py-3 border-b border-line">
                <div className="font-semibold text-sm text-ink">
                  {admin?.full_name}
                </div>
                <div className="text-xs text-ink-soft truncate">
                  {admin?.email}
                </div>
                {admin?.is_super_admin && (
                  <div className="mt-1">
                    <span
                      className="ktag"
                      style={{ background: "#F6EED9", color: "#8A5E12" }}
                    >
                      Super Admin
                    </span>
                  </div>
                )}
              </div>
              <button
                onClick={handleLogout}
                className="w-full text-left px-4 py-2.5 text-sm text-bad hover:bg-bad-tint rounded-b-card flex items-center gap-2"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z" />
                </svg>
                Đăng xuất
              </button>
            </div>
          )}
        </header>

        {/* Content */}
        <div className="flex-1 overflow-auto p-6">{children}</div>
      </main>
    </div>
  );
}