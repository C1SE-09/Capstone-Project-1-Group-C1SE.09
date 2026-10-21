/**
 * pages/login.tsx
 * ===============
 * Trang đăng nhập CHUNG cho cả Admin Web (dev team) và School Admin.
 *
 * Flow:
 *   1. User nhập username/email + password.
 *   2. Thử gọi /api/school-admin/login.
 *      - Nếu OK (role=admin trong bảng users) → set token school_admin → /school-admin
 *      - Nếu 403 (không phải admin) → fallback gọi /api/admin-auth/login.
 *   3. Nếu /api/admin-auth/login OK → set token admin_app → /
 *      (trang dashboard bug report của web admin).
 *
 * UI: y hệt Flutter LoginScreen (KColors palette + BeVietnamPro font).
 */

import { useRouter } from "next/router";
import { useState } from "react";
import {
  ApiError,
  adminAppLoginRequest,
  setStoredAdmin,
  setStoredSchoolAdmin,
  setRefreshToken,
  setToken,
  schoolAdminLoginRequest,
} from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPwd, setShowPwd] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const trimmedId = identifier.trim();
      const isEmail = trimmedId.includes("@");

      if (isEmail) {
        // Ưu tiên 1: Đăng nhập Web Admin (Dev Team / Bug Reports) nếu nhập định dạng email
        try {
          const res = await adminAppLoginRequest({
            email: trimmedId.toLowerCase(),
            password,
          });
          setToken(res.access_token, "adminApp");
          setStoredAdmin(res.admin);
          router.replace("/");
          return;
        } catch (adminErr) {
          // Thử tiếp School Admin (phòng trường hợp admin trường dùng email đăng nhập)
          try {
            const res = await schoolAdminLoginRequest({
              username: trimmedId,
              password,
            });
            setToken(res.access_token, "schoolAdmin");
            setRefreshToken(res.refresh_token);
            setStoredSchoolAdmin({
              user_id: res.user_id,
              username: res.username,
              full_name: res.full_name || res.username,
              role: "admin",
              school_id: res.school_id ?? null,
              school_name: res.school_name ?? null,
            });
            router.replace("/school-admin");
            return;
          } catch {
            throw adminErr;
          }
        }
      } else {
        // Ưu tiên 2: Đăng nhập School Admin (Quản trị trường) nếu nhập username
        try {
          const res = await schoolAdminLoginRequest({
            username: trimmedId,
            password,
          });
          setToken(res.access_token, "schoolAdmin");
          setRefreshToken(res.refresh_token);
          setStoredSchoolAdmin({
            user_id: res.user_id,
            username: res.username,
            full_name: res.full_name || res.username,
            role: "admin",
            school_id: res.school_id ?? null,
            school_name: res.school_name ?? null,
          });
          router.replace("/school-admin");
          return;
        } catch (schoolErr) {
          // Fallback thử tiếp Web Admin (nếu username cũng là alias hoặc admin app)
          try {
            const res = await adminAppLoginRequest({
              email: trimmedId.toLowerCase(),
              password,
            });
            setToken(res.access_token, "adminApp");
            setStoredAdmin(res.admin);
            router.replace("/");
            return;
          } catch {
            throw schoolErr;
          }
        }
      }
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status === 401) {
          setError("Tên đăng nhập hoặc mật khẩu không chính xác.");
        } else if (err.status === 403) {
          setError(err.detail || "Tài khoản không có quyền truy cập quản trị.");
        } else {
          setError(err.detail || "Đăng nhập thất bại. Vui lòng thử lại sau.");
        }
      } else {
        setError("Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng hoặc thử lại sau.");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-canvas p-4">
      <div className="w-full max-w-md">
        {/* Logo (giống Flutter app: rounded teal + school icon) */}
        <div className="text-center mb-8">
          <div
            className="inline-flex items-center justify-center mb-3 text-white"
            style={{
              width: 56,
              height: 56,
              borderRadius: 16,
              background:
                "linear-gradient(135deg, #16665a 0%, rgba(22,102,90,0.8) 100%)",
              boxShadow: "0 4px 12px rgba(22,102,90,0.3)",
            }}
          >
            <svg
              width="30"
              height="30"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M12 3C7 3 4 6.5 4 9.5C4 11.4 5.1 12.9 6.7 13.8C5.6 14.6 5 15.7 5 16.8C5 18.7 6.8 20 9.5 20H14.5C17.2 20 19 18.7 19 16.8C19 15.7 18.4 14.6 17.3 13.8C18.9 12.9 20 11.4 20 9.5C20 6.5 17 3 12 3Z"
                fill="white"
              />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-ink tracking-tight">
            KinderLog
          </h1>
          <p className="text-sm mt-1 text-ink-soft">
            Hệ thống sổ liên lạc & báo cáo mầm non
          </p>
        </div>

        {/* Form card */}
        <div className="card p-8 shadow-soft">
          <h2 className="text-lg font-bold text-ink mb-1">Đăng nhập</h2>
          <p className="text-xs text-ink-soft mb-6">
            Nhập thông tin tài khoản của bạn để tiếp tục
          </p>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="klabel">
                Tên đăng nhập, Gmail hoặc Số điện thoại
              </label>
              <input
                type="text"
                required
                autoComplete="username"
                autoFocus
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                placeholder="admin.truong@gmail.com"
                className="kinput"
              />
            </div>

            <div>
              <label className="klabel">Mật khẩu</label>
              <div className="relative">
                <input
                  type={showPwd ? "text" : "password"}
                  required
                  minLength={6}
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="kinput pr-24"
                />
                <button
                  type="button"
                  onClick={() => setShowPwd(!showPwd)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-ink-soft hover:text-ink font-medium"
                >
                  {showPwd ? "Ẩn" : "Hiện"}
                </button>
              </div>
            </div>

            {error && (
              <div className="bg-bad-tint border border-bad/30 text-bad px-3.5 py-2.5 rounded-control text-sm flex items-start gap-2">
                <span className="mt-0.5">⚠️</span>
                <span>{error}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="kbtn kbtn-primary w-full justify-center"
              style={{ height: 48, fontSize: 15, letterSpacing: 0.5 }}
            >
              {loading ? "Đang đăng nhập..." : "ĐĂNG NHẬP"}
            </button>
          </form>
        </div>

        <div className="text-center text-xs text-ink-faint mt-6">
          © 2026 KinderLog · Admin Web
        </div>
      </div>
    </div>
  );
}