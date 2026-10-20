/**
 * pages/school-admin/account.tsx
 * ===============================
 * Tab Tài khoản của admin trường — y hệt Flutter AdminDashboardScreen.tab_account:
 *   - Avatar + tên + username + trường.
 *   - Form đổi mật khẩu (current → new → confirm).
 *   - Nút đăng xuất.
 *   - Thông tin phiên đang hoạt động.
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
    <SchoolAdminLayout active="account" pageTitle="Tài khoản của tôi">
      <div className="max-w-2xl space-y-4">
        {/* Profile card */}
        <div className="card p-6">
          <div className="flex items-center gap-4">
            <div
              className="w-16 h-16 flex items-center justify-center rounded-full font-bold text-2xl text-white"
              style={{ background: "#16665a" }}
            >
              {info.full_name.charAt(0).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-xl font-extrabold text-ink">
                {info.full_name}
              </div>
              <div className="text-sm text-ink-soft">@{info.username}</div>
              {info.school_name && (
                <div className="text-sm text-ink-soft mt-1">
                  🏫 {info.school_name}
                </div>
              )}
              <div className="mt-2">
                <span
                  className="ktag"
                  style={{ background: "#E6EFEC", color: "#114F46" }}
                >
                  Admin trường
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Change password */}
        <div className="card p-6">
          <h2 className="font-bold text-ink mb-1">Đổi mật khẩu</h2>
          <p className="text-sm text-ink-soft mb-4">
            Sau khi đổi, các thiết bị khác sẽ tự động bị đăng xuất.
          </p>
          <FormField label="Mật khẩu hiện tại" required>
            <input
              type="password"
              className="kinput"
              value={currentPw}
              onChange={(e) => setCurrentPw(e.target.value)}
              autoComplete="current-password"
            />
          </FormField>
          <FormField label="Mật khẩu mới" required hint="Ít nhất 6 ký tự">
            <input
              type="password"
              className="kinput"
              value={newPw}
              onChange={(e) => setNewPw(e.target.value)}
              autoComplete="new-password"
            />
          </FormField>
          <FormField label="Xác nhận mật khẩu mới" required>
            <input
              type="password"
              className="kinput"
              value={confirmPw}
              onChange={(e) => setConfirmPw(e.target.value)}
              autoComplete="new-password"
            />
          </FormField>
          <button
            onClick={handleChangePassword}
            disabled={saving}
            className="kbtn kbtn-primary mt-2"
          >
            {saving ? "Đang lưu..." : "Đổi mật khẩu"}
          </button>
        </div>

        {/* Logout */}
        <div className="card p-6">
          <h2 className="font-bold text-ink mb-1">Đăng xuất</h2>
          <p className="text-sm text-ink-soft mb-4">
            Kết thúc phiên làm việc hiện tại trên trình duyệt này.
          </p>
          <button onClick={handleLogout} className="kbtn kbtn-danger">
            🚪 Đăng xuất
          </button>
        </div>

        {/* Footer */}
        <div className="text-center text-xs text-ink-faint">
          KinderLog · School Admin Web v1.0
        </div>
      </div>

      {toast && (
        <Toast message={toast.msg} tone={toast.tone} onClose={() => setToast(null)} />
      )}
    </SchoolAdminLayout>
  );
}