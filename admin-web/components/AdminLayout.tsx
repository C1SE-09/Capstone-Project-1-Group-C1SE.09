/**
 * components/AdminLayout.tsx
 * ==========================
 * Layout chính cho các trang admin: header + sidebar + content.
 */

import { useRouter } from "next/router";
import Link from "next/link";
import { ReactNode, useEffect, useState } from "react";
import { clearToken, getStoredAdmin, getToken } from "@/lib/api";
import { Spinner } from "@/components/ui";

interface Props {
  children: ReactNode;
  currentPage?: "dashboard" | "bug-reports";
}

export default function AdminLayout({ children, currentPage = "dashboard" }: Props) {
  const router = useRouter();
  const [adminName, setAdminName] = useState<string>("");
  const [adminEmail, setAdminEmail] = useState<string>("");
  const [showMenu, setShowMenu] = useState(false);
  const [isAuthorized, setIsAuthorized] = useState<boolean>(false);

  useEffect(() => {
    const token = getToken();
    const admin = getStoredAdmin();
    if (token && admin) {
      setAdminName(admin.full_name);
      setAdminEmail(admin.email);
      setIsAuthorized(true);
    } else {
      clearToken();
      router.replace("/login");
    }
  }, [router]);

  const handleLogout = () => {
    clearToken();
    router.replace("/login");
  };

  if (!isAuthorized) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Spinner />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-gray-50">
      {/* ================== SIDEBAR ================== */}
      <aside className="w-60 bg-white border-r border-gray-200 flex flex-col">
        {/* Logo */}
        <div className="px-5 py-5 border-b border-gray-200">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 rounded-lg bg-brand-600 flex items-center justify-center text-white font-bold text-lg">
              K
            </div>
            <div>
              <div className="font-bold text-gray-900 text-sm">KinderLog</div>
              <div className="text-xs text-gray-500">Admin Web</div>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1">
          <Link
            href="/"
            className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium ${
              currentPage === "dashboard"
                ? "bg-brand-50 text-brand-700"
                : "text-gray-700 hover:bg-gray-100"
            }`}
          >
            <span>📊</span> Trang chủ
          </Link>
          <Link
            href="/bug-reports"
            className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium ${
              currentPage === "bug-reports"
                ? "bg-brand-50 text-brand-700"
                : "text-gray-700 hover:bg-gray-100"
            }`}
          >
            <span>🐛</span> Quản lý Bug Report
          </Link>
        </nav>

        {/* Footer */}
        <div className="px-3 py-3 border-t border-gray-200 text-xs text-gray-400">
          <div>v1.0.0</div>
        </div>
      </aside>

      {/* ================== MAIN ================== */}
      <main className="flex-1 flex flex-col min-w-0">
        {/* Topbar */}
        <header className="h-14 bg-white border-b border-gray-200 px-6 flex items-center justify-end relative">
          <button
            onClick={() => setShowMenu(!showMenu)}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-gray-100"
          >
            <div className="w-8 h-8 rounded-full bg-brand-100 text-brand-700 flex items-center justify-center font-semibold text-sm">
              {adminName ? adminName.charAt(0).toUpperCase() : "A"}
            </div>
            <div className="text-left hidden sm:block">
              <div className="text-sm font-medium text-gray-900">{adminName || "Admin"}</div>
              <div className="text-xs text-gray-500">{adminEmail}</div>
            </div>
            <span className="text-gray-400">▾</span>
          </button>

          {showMenu && (
            <div className="absolute right-6 top-12 w-56 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
              <div className="px-4 py-3 border-b border-gray-100">
                <div className="font-medium text-sm text-gray-900">{adminName}</div>
                <div className="text-xs text-gray-500 truncate">{adminEmail}</div>
              </div>
              <button
                onClick={handleLogout}
                className="w-full text-left px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 rounded-b-lg"
              >
                🚪 Đăng xuất
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
