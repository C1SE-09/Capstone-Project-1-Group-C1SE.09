/**
 * pages/index.tsx
 * ===============
 * Trang chủ Web Admin (dev team) — restyle theo theme KinderLog.
 * Stats bug report được giữ nguyên.
 */

import { useEffect, useState } from "react";
import useSWR from "swr";
import Link from "next/link";
import { useRouter } from "next/router";
import AdminLayout from "@/components/AdminLayout";
import { Spinner } from "@/components/ui-school";
import { apiFetch, clearToken, getToken } from "@/lib/api";
import { formatDate } from "@/lib/format";

interface Stats {
  total: number;
  by_status: Record<string, number>;
  new_last_7_days: number;
  critical_open: number;
  generated_at: string;
}

export default function DashboardPage() {
  const router = useRouter();
  const [tokenReady, setTokenReady] = useState(false);

  useEffect(() => {
    // Nếu đang là school-admin mà vào / → đẩy sang /school-admin
    if (getToken("schoolAdmin")) {
      router.replace("/school-admin");
      return;
    }
    if (!getToken("adminApp")) {
      router.replace("/login");
    } else {
      setTokenReady(true);
    }
  }, [router]);

  const { data: stats, error } = useSWR<Stats>(
    tokenReady ? "/api/bug-reports/stats" : null,
    (url) => apiFetch<Stats>(url, { account: "adminApp" }),
    { refreshInterval: 30000 },
  );

  if (!tokenReady || !stats) {
    return (
      <AdminLayout currentPage="dashboard">
        {error ? (
          <div className="card p-5 max-w-md">
            <div className="font-bold text-bad mb-1 text-sm">Lỗi tải dữ liệu</div>
            <div className="text-xs text-ink-soft mb-3">
              {error?.detail ||
                "Phiên làm việc có thể đã hết hạn hoặc không kết nối được máy chủ."}
            </div>
            <button
              onClick={() => {
                clearToken("adminApp");
                router.replace("/login");
              }}
              className="kbtn kbtn-danger"
            >
              Đăng nhập lại
            </button>
          </div>
        ) : (
          <Spinner />
        )}
      </AdminLayout>
    );
  }

  const openCount =
    (stats.by_status["open"] || 0) + (stats.by_status["in_progress"] || 0);

  return (
    <AdminLayout currentPage="dashboard">
      <div className="max-w-3xl space-y-4">
        <h1 className="text-2xl font-bold text-ink tracking-tight">
          Trang chủ · Web Admin
        </h1>
        <p className="text-sm text-ink-soft">
          Tổng quan bug reports gửi từ giáo viên &amp; phụ huynh qua ứng dụng
          mobile.
        </p>

        <div className="card p-6 mt-3">
          <div className="flex items-start justify-between gap-4">
            <div className="flex items-center gap-3">
              <div
                className="w-12 h-12 flex items-center justify-center rounded-control text-2xl"
                style={{ background: "#F6EED9" }}
              >
                🐛
              </div>
              <div>
                <h2 className="text-lg font-bold text-ink">Bug Report</h2>
                <p className="text-xs text-ink-soft">
                  Báo cáo lỗi từ giáo viên &amp; phụ huynh
                </p>
              </div>
            </div>
            <Link
              href="/bug-reports"
              className="text-sm font-semibold hover:underline"
              style={{ color: "#16665a" }}
            >
              Xem tất cả →
            </Link>
          </div>

          <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
            <KpiTile
              label="Tổng số report"
              value={stats.total}
              tone="brand"
              icon="📋"
            />
            <KpiTile
              label="Đang mở"
              value={openCount}
              tone="warn"
              icon="⏳"
              hint={`${stats.by_status["open"] || 0} mới · ${
                stats.by_status["in_progress"] || 0
              } đang xử lý`}
            />
            <KpiTile
              label="Critical chưa xử lý"
              value={stats.critical_open}
              tone="bad"
              icon="🔥"
              hint={stats.critical_open > 0 ? "Cần ưu tiên" : "Tất cả ổn"}
            />
          </div>

          <div className="mt-4 pt-4 border-t border-line text-xs text-ink-faint flex justify-between flex-wrap gap-2">
            <span>
              Mới trong 7 ngày:{" "}
              <span className="font-bold text-ink">
                {stats.new_last_7_days}
              </span>
            </span>
            <span>Cập nhật: {formatDate(stats.generated_at)}</span>
          </div>
        </div>

        <div className="card p-4 bg-warn-tint border-warn/30">
          <div className="text-sm">
            <span className="font-bold" style={{ color: "#8A5E12" }}>
              💡 Ghi chú:
            </span>{" "}
            <span className="text-ink-soft">
              Tài khoản này (<b>Web Admin</b>) là tài khoản riêng cho dev team quản
              lý bug reports. Admin trường (quản lý giáo viên / học sinh / phụ
              huynh) đăng nhập tại cùng trang này nhưng sẽ được tự động điều
              hướng vào khu vực riêng.
            </span>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

function KpiTile({
  label,
  value,
  tone,
  icon,
  hint,
}: {
  label: string;
  value: number;
  tone: "brand" | "warn" | "bad";
  icon: string;
  hint?: string;
}) {
  const map = {
    brand: { bg: "#E6EFEC", fg: "#16665a" },
    warn: { bg: "#F6EED9", fg: "#B0791B" },
    bad: { bg: "#F6E6E1", fg: "#BB4A34" },
  };
  const c = map[tone];
  return (
    <div
      className="rounded-control p-4 border"
      style={{ background: c.bg, borderColor: c.fg }}
    >
      <div className="flex items-center justify-between mb-1">
        <span
          className="text-[11px] font-bold uppercase tracking-wider"
          style={{ color: c.fg }}
        >
          {label}
        </span>
        <span className="text-lg opacity-60">{icon}</span>
      </div>
      <div className="text-3xl font-extrabold" style={{ color: c.fg }}>
        {value}
      </div>
      {hint && (
        <div className="text-[11px] mt-1" style={{ color: c.fg, opacity: 0.85 }}>
          {hint}
        </div>
      )}
    </div>
  );
}