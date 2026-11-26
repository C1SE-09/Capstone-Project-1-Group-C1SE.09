/**
 * pages/school-admin/account.tsx
 * ===============================
 * Tài khoản Quản trị trường — 100% chuẩn Figma Frame 10: "GV · Admin Web · 10 — Trường: Tài khoản" (#454:4031)
 */

import { useEffect, useState } from "react";
import { useRouter } from "next/router";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import {
  FormField,
  Toast,
} from "@/components/ui-school";
import {
  ApiError,
  apiFetch,
  getStoredSchoolAdmin,
  getToken,
  logoutAccount,
} from "@/lib/api";
import { useLanguage } from "@/lib/language-context";
import { formatSchoolName } from "@/lib/locale-helper";

export default function SchoolAdminAccountPage() {
  const router = useRouter();
  const { lang } = useLanguage();
  const [ready, setReady] = useState(false);
  const [info, setInfo] = useState<{
    full_name: string;
    username: string;
    school_name?: string | null;
  } | null>(null);
  const [currentPw, setCurrentPw] = useState("");
  const [newPw, setNewPw] = useState("");
  const [confirmPw, setConfirmPw] = useState("");
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "bad" } | null>(null);

  useEffect(() => {
    if (!getToken() || !getStoredSchoolAdmin()) {
      router.replace("/login");
      return;
    }
    const stored = getStoredSchoolAdmin()!;
    setInfo({
      full_name: stored.full_name,
      username: stored.username,
      school_name: stored.school_name,
    });
    setReady(true);
  }, [router]);

  async function handleLogout() {
    await logoutAccount("schoolAdmin");
    router.replace("/login");
  }

  async function handleChangePassword() {
    if (newPw.length < 6) {
      setToast({ msg: lang === "en" ? "New password must be at least 6 characters" : "Mật khẩu mới phải có ít nhất 6 ký tự", tone: "bad" });
      return;
    }
    if (newPw !== confirmPw) {
      setToast({ msg: lang === "en" ? "Confirmation password does not match" : "Mật khẩu xác nhận không khớp", tone: "bad" });
      return;
    }
    if (currentPw === newPw) {
      setToast({ msg: lang === "en" ? "New password cannot be the same as current password" : "Mật khẩu mới không được trùng mật khẩu hiện tại", tone: "bad" });
      return;
    }
    setSaving(true);
    try {
      await apiFetch("/api/auth/change-password", {
        method: "POST",
        body: {
          current_password: currentPw,
          new_password: newPw,
          logout_other_devices: true,
        },
        account: "schoolAdmin",
      });
      setCurrentPw("");
      setNewPw("");
      setConfirmPw("");
      setToast({ msg: lang === "en" ? "Password changed successfully" : "Đổi mật khẩu thành công", tone: "ok" });
    } catch (err) {
      const detail = err instanceof ApiError ? err.detail : (lang === "en" ? "Unable to change password" : "Không thể đổi mật khẩu");
      setToast({ msg: detail, tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  if (!ready || !info) return null;

  return (
    <SchoolAdminLayout active="account" pageTitle={lang === "en" ? "School Admin Account" : "Tài khoản quản trị trường"}>
      <div className="max-w-3xl space-y-6">
        
        {/* Header */}
        <div>
          <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
            {lang === "en" ? "School Admin Account" : "Tài khoản quản trị trường"}
          </h1>
          <p className="text-sm text-[#65727D] mt-1">
            {lang === "en" ? "Account details, security settings, and administration role." : "Thông tin tài khoản, bảo mật và quyền hạn quản lý."}
          </p>
        </div>

        {/* ─── Profile Card (Figma 454:4063) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-7 shadow-soft">
          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5">
            <div className="w-16 h-16 rounded-full bg-[#087F70] flex items-center justify-center font-extrabold text-2xl text-white shadow-sm shrink-0">
              {info.full_name.charAt(0).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-xl font-extrabold text-[#102737]">
                {info.full_name}
              </div>
              <div className="text-xs font-semibold text-[#65727D] mt-0.5">
                {lang === "en" ? "Username: " : "Tên đăng nhập: "}@{info.username}
              </div>
              {info.school_name && (
                <div className="text-xs text-[#087F70] font-bold mt-1.5 flex items-center gap-1.5">
                  <span>🏫</span>
                  <span>{formatSchoolName(info.school_name, lang)}</span>
                </div>
              )}
            </div>
            <span className="px-3.5 py-1.5 rounded-full bg-[#E6F3EB] text-[#087F70] font-bold text-xs">
              {lang === "en" ? "School Admin" : "Quản trị viên trường"}
            </span>
          </div>
        </div>

        {/* ─── Change Password Card (Figma 454:4069) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-7 shadow-soft">
          <h2 className="text-base font-extrabold text-[#102737] mb-1">
            {lang === "en" ? "Change Password" : "Đổi mật khẩu"}
          </h2>
          <p className="text-xs text-[#65727D] mb-5">
            {lang === "en"
              ? "After changing your password, sessions on other devices will be signed out automatically for security."
              : "Sau khi đổi mật khẩu thành công, các phiên đăng nhập trên thiết bị khác sẽ tự động bị đăng xuất để đảm bảo an toàn."}
          </p>

          <div className="space-y-4 max-w-md">
            <FormField label={lang === "en" ? "Current Password" : "Mật khẩu hiện tại"} required>
              <input
                type="password"
                className="w-full h-11 px-4 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] focus:outline-none focus:border-[#087F70]"
                value={currentPw}
                onChange={(e) => setCurrentPw(e.target.value)}
                autoComplete="current-password"
                placeholder="••••••••"
              />
            </FormField>

            <FormField label={lang === "en" ? "New Password" : "Mật khẩu mới"} required hint={lang === "en" ? "Minimum 6 characters" : "Tối thiểu 6 ký tự"}>
              <input
                type="password"
                className="w-full h-11 px-4 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] focus:outline-none focus:border-[#087F70]"
                value={newPw}
                onChange={(e) => setNewPw(e.target.value)}
                autoComplete="new-password"
                placeholder="••••••••"
              />
            </FormField>

            <FormField label={lang === "en" ? "Confirm New Password" : "Xác nhận mật khẩu mới"} required>
              <input
                type="password"
                className="w-full h-11 px-4 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] focus:outline-none focus:border-[#087F70]"
                value={confirmPw}
                onChange={(e) => setConfirmPw(e.target.value)}
                autoComplete="new-password"
                placeholder="••••••••"
              />
            </FormField>

            <button
              onClick={handleChangePassword}
              disabled={saving}
              className="px-6 py-2.5 bg-[#087F70] hover:bg-[#06695E] text-white font-bold text-xs rounded-full shadow-sm transition disabled:opacity-50"
            >
              {saving ? (lang === "en" ? "Saving..." : "Đang lưu...") : (lang === "en" ? "Update Password" : "Cập nhật mật khẩu")}
            </button>
          </div>
        </div>

        {/* ─── Logout Card (Figma 454:4079) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-7 shadow-soft flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-base font-extrabold text-[#102737]">
              {lang === "en" ? "Log Out" : "Đăng xuất khỏi hệ thống"}
            </h2>
            <p className="text-xs text-[#65727D] mt-0.5">
              {lang === "en" ? "End the current session on this browser." : "Kết thúc phiên làm việc hiện tại trên trình duyệt này."}
            </p>
          </div>
          <button
            onClick={handleLogout}
            className="px-5 py-2.5 bg-[#FDEAE5] hover:bg-[#FCD9D1] text-[#A93832] font-bold text-xs rounded-full transition shrink-0 flex items-center gap-2"
          >
            <span>🚪</span>
            <span>{lang === "en" ? "Log out" : "Đăng xuất"}</span>
          </button>
        </div>

        {/* Footer */}
        <div className="text-center text-xs text-[#8C9BA5] pt-2">
          {lang === "en" ? "KinderLog Garden Voice v2.0 · School Administration Portal" : "KinderLog Garden Voice v2.0 · Cổng Quản Trị Nhà Trường"}
        </div>
      </div>

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}
