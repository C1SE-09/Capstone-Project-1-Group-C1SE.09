/**
 * pages/index.tsx
 * ===============
 * Dashboard Tổng quan Hệ thống (Web Admin / Dev Team).
 * 100% chuẩn Figma Frame 02: "GV · Admin Web · 02 — Dashboard hệ thống" (#454:3192)
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

interface BugReportItem {
  id: string;
  title: string;
  sender_type: string;
  sender_name?: string;
  severity: string;
  status: string;
  created_at: string;
}

export default function DashboardPage() {
  const router = useRouter();
  const [tokenReady, setTokenReady] = useState(false);

  useEffect(() => {
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
    (url: string) => apiFetch<Stats>(url, { account: "adminApp" }),
    { refreshInterval: 30000 },
  );

  const { data: recentReports } = useSWR<{ items: BugReportItem[] }>(
    tokenReady ? "/api/bug-reports?limit=5" : null,
    (url: string) => apiFetch<{ items: BugReportItem[] }>(url, { account: "adminApp" }),
  );

  if (!tokenReady || !stats) {
    return (
      <AdminLayout currentPage="dashboard">
        {error ? (
          <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-8 max-w-md">
            <div className="font-bold text-[#A93832] mb-1 text-base">Lỗi tải dữ liệu</div>
            <div className="text-sm text-[#65727D] mb-4">
              {error?.detail || "Phiên làm việc đã hết hạn hoặc không kết nối được máy chủ."}
            </div>
            <button
              onClick={() => {
                clearToken("adminApp");
                router.replace("/login");
              }}
              className="px-5 py-2.5 bg-[#A93832] text-white rounded-full font-bold text-sm"
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

  const openCount = (stats.by_status["open"] || 0) + (stats.by_status["in_progress"] || 0);

  return (
    <AdminLayout currentPage="dashboard">
      <div className="space-y-8">
        {/* Header */}
        <div>
          <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
            Tổng quan hệ thống
          </h1>
          <p className="text-sm text-[#65727D] mt-1">
            Tổng quan bug reports gửi từ giáo viên &amp; phụ huynh qua ứng dụng KinderLog.
          </p>
        </div>

        {/* ─── 4 Thẻ KPI Garden Voice ─── */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
            <div className="flex items-center justify-between text-[#65727D]">
              <span className="text-xs font-bold uppercase tracking-wider">Tổng số báo lỗi</span>
              <span className="text-xl">📋</span>
            </div>
            <div className="text-3xl font-extrabold text-[#102737] mt-2">
              {stats.total}
            </div>
            <div className="text-xs text-[#8C9BA5] mt-1">
              +{stats.new_last_7_days} trong 7 ngày qua
            </div>
          </div>

          <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
            <div className="flex items-center justify-between text-[#B0791B]">
              <span className="text-xs font-bold uppercase tracking-wider">Đang chờ xử lý</span>
              <span className="text-xl">⏳</span>
            </div>
            <div className="text-3xl font-extrabold text-[#B0791B] mt-2">
              {openCount}
            </div>
            <div className="text-xs text-[#B0791B] mt-1 font-medium">
              {stats.by_status["open"] || 0} mới · {stats.by_status["in_progress"] || 0} đang làm
            </div>
          </div>

          <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
            <div className="flex items-center justify-between text-[#A93832]">
              <span className="text-xs font-bold uppercase tracking-wider">Sự cố Critical</span>
              <span className="text-xl">🔥</span>
            </div>
            <div className="text-3xl font-extrabold text-[#A93832] mt-2">
              {stats.critical_open}
            </div>
            <div className="text-xs text-[#A93832] mt-1 font-medium">
              {stats.critical_open > 0 ? "Cần giải quyết ngay" : "Hệ thống ổn định"}
            </div>
          </div>

          <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
            <div className="flex items-center justify-between text-[#087F70]">
              <span className="text-xs font-bold uppercase tracking-wider">Trường đối tác</span>
              <span className="text-xl">🏫</span>
            </div>
            <div className="text-3xl font-extrabold text-[#087F70] mt-2">
              1
            </div>
            <div className="text-xs text-[#087F70] mt-1 font-medium">
              Đang hoạt động trên VPS
            </div>
          </div>
        </div>

        {/* ─── Khối danh sách trường và Báo lỗi mới nhất ─── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          
          {/* Cột trái (7 cols): Báo lỗi mới nhất */}
          <div className="lg:col-span-7 bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft flex flex-col">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="font-extrabold text-base text-[#102737]">
                  Báo lỗi mới nhất
                </h2>
                <p className="text-xs text-[#65727D]">
                  Cần phản hồi và phân loại từ đội ngũ vận hành
                </p>
              </div>
              <Link
                href="/bug-reports"
                className="text-xs font-bold text-[#087F70] hover:underline"
              >
                Xem tất cả →
              </Link>
            </div>

            <div className="divide-y divide-[#E5E8EB] flex-1">
              {recentReports?.items && recentReports.items.length > 0 ? (
                recentReports.items.map((item) => (
                  <Link
                    key={item.id}
                    href={`/bug-reports/${item.id}`}
                    className="py-3.5 flex items-center justify-between gap-4 hover:bg-[#F6F7F8] px-2 rounded-[12px] transition"
                  >
                    <div className="min-w-0">
                      <div className="font-bold text-sm text-[#102737] truncate">
                        {item.title}
                      </div>
                      <div className="text-xs text-[#65727D] mt-0.5">
                        {item.sender_name || "Người dùng"} ({item.sender_type}) · {formatDate(item.created_at)}
                      </div>
                    </div>
                    <span
                      className={`shrink-0 text-xs font-bold px-2.5 py-1 rounded-full ${
                        item.severity === "critical"
                          ? "bg-[#FDEAE5] text-[#A93832]"
                          : item.severity === "high"
                          ? "bg-[#FFF0D9] text-[#B0791B]"
                          : "bg-[#E6F3EB] text-[#087F70]"
                      }`}
                    >
                      {item.severity}
                    </span>
                  </Link>
                ))
              ) : (
                <div className="py-8 text-center text-xs text-[#8C9BA5]">
                  Chưa có báo lỗi mới.
                </div>
              )}
            </div>
          </div>

          {/* Cột phải (5 cols): Trường đang hoạt động */}
          <div className="lg:col-span-5 bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft flex flex-col justify-between">
            <div>
              <h2 className="font-extrabold text-base text-[#102737]">
                Trường đang hoạt động
              </h2>
              <p className="text-xs text-[#65727D] mt-0.5 mb-4">
                Môi trường vận hành thực tế tại mầm non
              </p>

              <div className="p-4 rounded-[18px] bg-[#F6F7F8] border border-[#E5E8EB] flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#087F70] text-white flex items-center justify-center font-bold text-lg shrink-0">
                  🏫
                </div>
                <div className="min-w-0 flex-1">
                  <div className="font-bold text-sm text-[#102737] truncate">
                    Trường Mầm non Hoa Mai
                  </div>
                  <div className="text-xs text-[#087F70] font-semibold flex items-center gap-1.5 mt-0.5">
                    <span className="w-2 h-2 rounded-full bg-[#087F70] animate-pulse" />
                    Đang hoạt động · VPS 160.191.87.202
                  </div>
                </div>
              </div>
            </div>

            <div className="pt-6 border-t border-[#E5E8EB] mt-6">
              <Link
                href="/school-admin"
                className="w-full h-11 bg-[#E6F3EB] hover:bg-[#D1E9DE] text-[#087F70] font-bold text-xs rounded-full flex items-center justify-center gap-2 transition"
              >
                Mở Cổng Quản Trị Trường →
              </Link>
            </div>
          </div>

        </div>
      </div>
    </AdminLayout>
  );
}
