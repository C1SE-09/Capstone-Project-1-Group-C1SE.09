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
  clearToken,
  getStoredSchoolAdmin,
  getToken,
} from "@/lib/api";

export default function SchoolAdminAccountPage() {
  const router = useRouter();
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

  function handleLogout() {
    clearToken("schoolAdmin");
    router.replace("/login");
  }

  async function handleChangePassword() {
    if (newPw.length < 6) {
      setToast({ msg: "Mật khẩu mới phải có ít nhất 6 ký tự", tone: "bad" });
      return;
    }
    if (newPw !== confirmPw) {
      setToast({ msg: "Mật khẩu xác nhận không khớp", tone: "bad" });
      return;
    }
    if (currentPw === newPw) {
      setToast({ msg: "Mật khẩu mới không được trùng mật khẩu hiện tại", tone: "bad" });
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
      setToast({ msg: "Đổi mật khẩu thành công", tone: "ok" });
    } catch (err) {
      const detail = err instanceof ApiError ? err.detail : "Không thể đổi mật khẩu";
      setToast({ msg: detail, tone: "bad" });
    } finally {
      setSaving(false);
    }
  }

  if (!ready || !info) return null;

  return (
    <SchoolAdminLayout active="account" pageTitle="Tài khoản quản trị trường">
      <div className="max-w-3xl space-y-6">
        
        {/* Header */}
        <div>
          <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
            Tài khoản quản trị trường
          </h1>
          <p className="text-sm text-[#65727D] mt-1">
            Thông tin tài khoản, bảo mật và quyền hạn quản lý.
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
                Tên đăng nhập: @{info.username}
              </div>
              {info.school_name && (
                <div className="text-xs text-[#087F70] font-bold mt-1.5 flex items-center gap-1.5">
                  <span>🏫</span>
                  <span>{info.school_name}</span>
                </div>
              )}
            </div>
            <span className="px-3.5 py-1.5 rounded-full bg-[#E6F3EB] text-[#087F70] font-bold text-xs">
              Quản trị viên trường
            </span>
          </div>
        </div>

        {/* ─── Change Password Card (Figma 454:4069) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-7 shadow-soft">
          <h2 className="text-base font-extrabold text-[#102737] mb-1">
            Đổi mật khẩu
          </h2>
          <p className="text-xs text-[#65727D] mb-5">
            Sau khi đổi mật khẩu thành công, các phiên đăng nhập trên thiết bị khác sẽ tự động bị đăng xuất để đảm bảo an toàn.
          </p>

          <div className="space-y-4 max-w-md">
            <FormField label="Mật khẩu hiện tại" required>
              <input
                type="password"
                className="w-full h-11 px-4 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] focus:outline-none focus:border-[#087F70]"
                value={currentPw}
                onChange={(e) => setCurrentPw(e.target.value)}
                autoComplete="current-password"
                placeholder="••••••••"
              />
            </FormField>

            <FormField label="Mật khẩu mới" required hint="Tối thiểu 6 ký tự">
              <input
                type="password"
                className="w-full h-11 px-4 rounded-[12px] border border-[#E5E8EB] text-sm text-[#102737] focus:outline-none focus:border-[#087F70]"
                value={newPw}
                onChange={(e) => setNewPw(e.target.value)}
                autoComplete="new-password"
                placeholder="••••••••"
              />
            </FormField>

            <FormField label="Xác nhận mật khẩu mới" required>
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
              {saving ? "Đang lưu..." : "Cập nhật mật khẩu"}
            </button>
          </div>
        </div>

        {/* ─── Logout Card (Figma 454:4079) ─── */}
        <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-7 shadow-soft flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-base font-extrabold text-[#102737]">
              Đăng xuất khỏi hệ thống
            </h2>
            <p className="text-xs text-[#65727D] mt-0.5">
              Kết thúc phiên làm việc hiện tại trên trình duyệt này.
            </p>
          </div>
          <button
            onClick={handleLogout}
            className="px-5 py-2.5 bg-[#FDEAE5] hover:bg-[#FCD9D1] text-[#A93832] font-bold text-xs rounded-full transition shrink-0 flex items-center gap-2"
          >
            <span>🚪</span>
            <span>Đăng xuất</span>
          </button>
        </div>

        {/* Footer */}
        <div className="text-center text-xs text-[#8C9BA5] pt-2">
          KinderLog Garden Voice v2.0 · Cổng Quản Trị Nhà Trường
        </div>
      </div>

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}
