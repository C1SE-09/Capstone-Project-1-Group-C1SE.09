/**
 * pages/login.tsx
 * ===============
 * Trang đăng nhập CHUNG cho Admin Web (Quản trị hệ thống) & School Admin (Quản trị trường).
 * 100% chuẩn Figma Frame 01: "GV · Admin Web · 01 — Đăng nhập web" (#454:3161)
 *
 * Flow:
 *   1. User nhập username hoặc email + password.
 *   2. Nếu là email (@) → gọi /api/admin-auth/login → / (Dashboard Bug Reports).
 *   3. Nếu là username (hoặc fallback) → gọi /api/school-admin/login → /school-admin.
 */

import { useRouter } from "next/router";
import { useState } from "react";
import {
  ApiError,
  adminAppLoginRequest,
  setStoredAdmin,
  setStoredSchoolAdmin,
  setRefreshToken,
  setSessionId,
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
        // Ưu tiên 1: Đăng nhập Web Admin (Dev Team / Bug Reports)
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
          // Fallback thử School Admin
          try {
            const res = await schoolAdminLoginRequest({
              username: trimmedId,
              password,
            });
            setToken(res.access_token, "schoolAdmin");
            setRefreshToken(res.refresh_token);
            setSessionId(res.session_id);
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
        // Ưu tiên 2: Đăng nhập School Admin (Quản trị trường)
        try {
          const res = await schoolAdminLoginRequest({
            username: trimmedId,
            password,
          });
          setToken(res.access_token, "schoolAdmin");
          setRefreshToken(res.refresh_token);
          setSessionId(res.session_id);
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
          // Fallback thử Web Admin
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
    } catch (err: unknown) {
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
    <div className="min-h-screen bg-[#FFFFFF] flex items-center justify-center p-6 md:p-12 font-sans selection:bg-[#E6F3EB]">
      <div className="w-full max-w-[1100px] grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
        
        {/* ─── Cột trái: Thương hiệu & Minh họa vườn (Figma Frame #463:1885) ─── */}
        <div className="lg:col-span-6 flex flex-col gap-6">
          <div className="text-[#06695E] font-extrabold text-4xl lg:text-5xl tracking-tight leading-tight">
            KinderLog
          </div>
          <div className="text-[#102737] font-extrabold text-2xl lg:text-3xl leading-snug">
            Mỗi ngày một chút lớn khôn
          </div>
          
          <div className="w-full max-w-[460px] h-[175px] rounded-[24px] overflow-hidden shadow-soft border border-[#E5E8EB]">
            <img
              src="/images/teacher_garden.png"
              alt="Khu vườn KinderLog"
              className="w-full h-full object-cover"
            />
          </div>

          <p className="text-[#65727D] text-base leading-relaxed max-w-[460px]">
            Cùng nhà trường kết nối giáo viên, phụ huynh và những ngày đến lớp của bé một cách trọn vẹn và an tâm nhất.
          </p>

          <div className="flex items-center gap-6 pt-2 text-xs font-semibold text-[#8C9BA5]">
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-[#087F70]" />
              Quản trị trường học
            </div>
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-[#4B6F8C]" />
              Quản trị hệ thống
            </div>
          </div>
        </div>

        {/* ─── Cột phải: Form Đăng nhập (Figma Frame #463:1890) ─── */}
        <div className="lg:col-span-6 flex justify-center lg:justify-end">
          <div className="w-full max-w-[440px] bg-white rounded-[28px] border border-[#E5E8EB] p-8 lg:p-10 shadow-pop">
            <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
              Cổng quản trị web
            </h1>
            <p className="text-sm text-[#65727D] mt-1 mb-8">
              Đăng nhập để quản lý trường và vận hành hệ thống KinderLog
            </p>

            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-[#102737] mb-2">
                  Tên đăng nhập hoặc Email
                </label>
                <input
                  type="text"
                  required
                  autoFocus
                  autoComplete="username"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  placeholder="admin@kinderlog.edu.vn hoặc user"
                  className="w-full h-12 px-4 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] placeholder:text-[#8C9BA5] focus:outline-none focus:border-[#087F70] focus:ring-2 focus:ring-[#087F70]/10 transition"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-[#102737] mb-2">
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
                    className="w-full h-12 pl-4 pr-12 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] placeholder:text-[#8C9BA5] focus:outline-none focus:border-[#087F70] focus:ring-2 focus:ring-[#087F70]/10 transition"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPwd(!showPwd)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-xs font-bold text-[#65727D] hover:text-[#087F70]"
                  >
                    {showPwd ? "Ẩn" : "Hiện"}
                  </button>
                </div>
              </div>

              {error && (
                <div className="bg-[#FDEAE5] border border-[#A93832]/30 text-[#A93832] p-3 rounded-[12px] text-xs font-medium flex items-start gap-2">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" className="shrink-0 mt-0.5">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" />
                  </svg>
                  <span>{error}</span>
                </div>
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full h-12 bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-sm rounded-[24px] shadow-sm flex items-center justify-center gap-2 transition disabled:opacity-50"
              >
                {loading ? (
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                ) : (
                  "Đăng nhập cổng quản trị"
                )}
              </button>
            </form>

            <div className="mt-8 pt-6 border-t border-[#E5E8EB] text-center text-xs font-medium text-[#65727D]">
              Email dành cho quản trị hệ thống. Tên đăng nhập dành cho quản trị trường.
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
