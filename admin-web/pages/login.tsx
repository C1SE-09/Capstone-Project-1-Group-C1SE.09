/**
 * pages/login.tsx
 * ===============
 * Trang đăng nhập cho Web Admin.
 */

import { useRouter } from "next/router";
import { useState } from "react";
import { apiFetch, ApiError, setStoredAdmin, setToken } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPwd, setShowPwd] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const res = await apiFetch<{
        access_token: string;
        admin: {
          admin_user_id: string;
          email: string;
          full_name: string;
          is_super_admin: boolean;
        };
      }>("/api/admin-auth/login", {
        method: "POST",
        body: { email: email.trim().toLowerCase(), password },
        auth: false, // không cần token khi login
      });

      setToken(res.access_token);
      setStoredAdmin(res.admin);

      // Redirect về dashboard
      router.replace("/");
    } catch (err) {
      if (err instanceof ApiError) {
        setError(err.detail);
      } else {
        setError("Đăng nhập thất bại. Vui lòng thử lại.");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-brand-50 via-white to-brand-100 p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex w-16 h-16 rounded-2xl bg-brand-600 items-center justify-center text-white font-bold text-3xl mb-3">
            K
          </div>
          <h1 className="text-2xl font-bold text-gray-900">KinderLog Admin</h1>
          <p className="text-sm text-gray-500 mt-1">
            Đăng nhập để quản lý bug reports
          </p>
        </div>

        {/* Form card */}
        <div className="bg-white rounded-2xl shadow-lg border border-gray-200 p-8">
          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">
                Email
              </label>
              <input
                type="email"
                required
                autoComplete="username"
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@kinderlog.dev"
                className="w-full px-3.5 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">
                Mật khẩu
              </label>
              <div className="relative">
                <input
                  type={showPwd ? "text" : "password"}
                  required
                  minLength={6}
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full px-3.5 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-brand-500 focus:border-brand-500 outline-none pr-12"
                />
                <button
                  type="button"
                  onClick={() => setShowPwd(!showPwd)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-500 hover:text-gray-700"
                >
                  {showPwd ? "Ẩn" : "Hiện"}
                </button>
              </div>
            </div>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-3.5 py-2.5 rounded-lg text-sm">
                ⚠️ {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-brand-600 hover:bg-brand-700 disabled:bg-brand-400 text-white font-semibold py-2.5 rounded-lg text-sm transition"
            >
              {loading ? "Đang đăng nhập..." : "Đăng nhập"}
            </button>
          </form>

          <div className="mt-6 pt-5 border-t border-gray-100 text-center text-xs text-gray-500">
            <span className="block">Tài khoản này tách biệt với tài khoản giáo viên / phụ huynh.</span>
            <span className="block mt-0.5">Nếu quên mật khẩu, liên hệ super admin.</span>
          </div>
        </div>

        <div className="text-center text-xs text-gray-400 mt-6">
          © 2026 KinderLog · Admin Web v1.0
        </div>
      </div>
    </div>
  );
}
