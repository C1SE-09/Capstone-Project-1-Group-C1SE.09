/**
 * pages/index.tsx
 * ===============
 * Trang chủ - 1 box tổng quan bug report.
 * Click "Xem tất cả" để vào trang quản lý chi tiết.
 */

import { useEffect, useState } from "react";
import useSWR from "swr";
import Link from "next/link";
import { useRouter } from "next/router";
import AdminLayout from "@/components/AdminLayout";
import { Card, Spinner } from "@/components/ui";
import { apiFetch, getToken } from "@/lib/api";
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
    if (!getToken()) {
      router.replace("/login");
    } else {
      setTokenReady(true);
    }
  }, [router]);

  const { data: stats, error } = useSWR<Stats>(
    tokenReady ? "/api/bug-reports/stats" : null,
    (url) => apiFetch<Stats>(url),
    { refreshInterval: 30000 },
  );

  if (!tokenReady || !stats) {
    return (
      <AdminLayout currentPage="dashboard">
        {error ? (
          <div className="text-red-600 p-4">Lỗi tải dữ liệu. Hãy thử lại.</div>
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
        <h1 className="text-2xl font-bold text-gray-900">Trang chủ</h1>

        <Card className="p-6">
          <div className="flex items-start justify-between gap-4">
            <div className="flex items-center gap-3">
              <span className="text-3xl">🐛</span>
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Bug Report</h2>
                <p className="text-xs text-gray-500">
                  Tổng quan báo cáo lỗi từ giáo viên &amp; phụ huynh
                </p>
              </div>
            </div>
            <Link
              href="/bug-reports"
              className="text-sm text-brand-600 hover:text-brand-700 font-medium whitespace-nowrap"
            >
              Xem tất cả →
            </Link>
          </div>

          <div className="mt-5 grid grid-cols-3 gap-4">
            <div>
              <div className="text-xs text-gray-500 uppercase tracking-wide">
                Tổng
              </div>
              <div className="mt-1 text-2xl font-bold text-gray-900">
                {stats.total}
              </div>
            </div>
            <div>
              <div className="text-xs text-gray-500 uppercase tracking-wide">
                Đang mở
              </div>
              <div className="mt-1 text-2xl font-bold text-amber-600">
                {openCount}
              </div>
              <div className="text-[10px] text-gray-400">
                {stats.by_status["open"] || 0} mới ·{" "}
                {stats.by_status["in_progress"] || 0} xử lý
              </div>
            </div>
            <div>
              <div className="text-xs text-gray-500 uppercase tracking-wide">
                Critical
              </div>
              <div
                className={`mt-1 text-2xl font-bold ${
                  stats.critical_open > 0 ? "text-red-600" : "text-gray-400"
                }`}
              >
                {stats.critical_open}
              </div>
              <div className="text-[10px] text-gray-400">chưa xử lý</div>
            </div>
          </div>

          <div className="mt-4 pt-4 border-t border-gray-100 text-xs text-gray-400">
            Mới trong 7 ngày: {stats.new_last_7_days} · Cập nhật:{" "}
            {formatDate(stats.generated_at)}
          </div>
        </Card>
      </div>
    </AdminLayout>
  );
}
