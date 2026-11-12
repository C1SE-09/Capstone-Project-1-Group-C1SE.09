/**
 * pages/school-admin/index.tsx
 * ============================
 * Tổng quan Trường học (School Admin / Ban Giám Hiệu).
 * 100% chuẩn Figma Frame 05: "GV · Admin Web · 05 — Trường: Tổng quan" (#454:3537)
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";
import Link from "next/link";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import { ProgressBar, Spinner } from "@/components/ui-school";
import { ApiError, getStoredSchoolAdmin, getToken } from "@/lib/api";
import { apiFetch } from "@/lib/api";

interface OverviewStats {
  total_schools: number;
  total_classes: number;
  total_children: number;
  total_teachers: number;
  total_parents: number;
  today_reports_count: number;
  today_sent_reports_count: number;
  today_draft_reports_count: number;
  today_completion_rate: number;
}

interface ClassProgress {
  class_id: string;
  class_name: string;
  grade_label: string;
  teacher_name: string;
  total_children: number;
  reported_children: number;
  pending_children: number;
  completion_rate: number;
}

interface ReportTrend {
  report_date: string;
  total_reports: number;
  sent_reports: number;
  draft_reports: number;
}

function fmtPercent(p: number) {
  const val = p > 1 ? p : p * 100;
  return `${val.toFixed(val < 100 && val % 1 !== 0 ? 1 : 0)}%`;
}

function toneFromRate(r: number): "ok" | "warn" | "bad" {
  const normalized = r > 1 ? r / 100 : r;
  if (normalized >= 0.8) return "ok";
  if (normalized >= 0.4) return "warn";
  return "bad";
}

export default function SchoolAdminOverviewPage() {
  const [ready, setReady] = useState(false);
  const [schoolName, setSchoolName] = useState("");

  useEffect(() => {
    const stored = getStoredSchoolAdmin();
    if (!getToken() || !stored) {
      window.location.href = "/login";
      return;
    }
    setSchoolName(stored.school_name || "Trường Mầm Non Hoa Mai");
    setReady(true);
  }, []);

  const { data: stats, error: statsErr } = useSWR<OverviewStats>(
    ready ? "/api/admin/dashboard/stats" : null,
    (url) => apiFetch<OverviewStats>(url, { account: "schoolAdmin" }),
    { refreshInterval: 30000 },
  );

  const { data: classesProgress } = useSWR<ClassProgress[]>(
    ready ? "/api/admin/dashboard/classes-progress" : null,
    (url) => apiFetch<ClassProgress[]>(url, { account: "schoolAdmin" }),
    { refreshInterval: 30000 },
  );

  const { data: trends } = useSWR<ReportTrend[]>(
    ready ? ["/api/admin/dashboard/report-trends", { days: 7 }] : null,
    ([url, q]) =>
      apiFetch<ReportTrend[]>(url, {
        query: q as Record<string, string | number>,
        account: "schoolAdmin",
      }),
    { refreshInterval: 60000 },
  );

  if (!ready) return null;

  return (
    <SchoolAdminLayout active="overview" pageTitle="Tổng quan trường">
      <div className="space-y-8">
        
        {/* Header (Figma 454:3567 & 3568) */}
        <div>
          <h1 className="text-2xl font-extrabold text-[#102737] tracking-tight">
            Tổng quan trường
          </h1>
          <p className="text-sm text-[#65727D] mt-1">
            {schoolName} · Năm học 2026–2027
          </p>
        </div>

        {statsErr && (
          <div className="p-4 bg-[#FDEAE5] border border-[#A93832]/30 text-[#A93832] rounded-[16px] text-sm">
            <div className="font-bold">Không thể tải dữ liệu thống kê</div>
            <div className="text-xs mt-0.5">
              {statsErr instanceof ApiError ? statsErr.detail : "Vui lòng kiểm tra lại kết nối đến máy chủ."}
            </div>
          </div>
        )}

        {!stats ? (
          <Spinner />
        ) : (
          <>
            {/* ─── 4 Thẻ KPI Trường học (Figma 454:3569) ─── */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              
              {/* Thẻ 1: Học sinh */}
              <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
                <div className="flex items-center justify-between text-[#65727D]">
                  <span className="text-xs font-bold uppercase tracking-wider">Tổng số học sinh</span>
                  <span className="text-xl">👶</span>
                </div>
                <div className="text-3xl font-extrabold text-[#102737] mt-2">
                  {stats.total_children}
                </div>
                <div className="text-xs text-[#087F70] font-semibold mt-1">
                  🏫 {stats.total_classes} lớp đang học
                </div>
              </div>

              {/* Thẻ 2: Giáo viên */}
              <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
                <div className="flex items-center justify-between text-[#65727D]">
                  <span className="text-xs font-bold uppercase tracking-wider">Đội ngũ giáo viên</span>
                  <span className="text-xl">👩‍🏫</span>
                </div>
                <div className="text-3xl font-extrabold text-[#087F70] mt-2">
                  {stats.total_teachers}
                </div>
                <div className="text-xs text-[#8C9BA5] mt-1">
                  Giáo viên đứng lớp &amp; bảo mẫu
                </div>
              </div>

              {/* Thẻ 3: Phụ huynh */}
              <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
                <div className="flex items-center justify-between text-[#65727D]">
                  <span className="text-xs font-bold uppercase tracking-wider">Phụ huynh liên kết</span>
                  <span className="text-xl">👨‍👩‍👧</span>
                </div>
                <div className="text-3xl font-extrabold text-[#4B6F8C] mt-2">
                  {stats.total_parents}
                </div>
                <div className="text-xs text-[#8C9BA5] mt-1">
                  Tài khoản đang nhận báo cáo
                </div>
              </div>

              {/* Thẻ 4: Tiến độ báo cáo ngày */}
              <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft">
                <div className="flex items-center justify-between text-[#65727D]">
                  <span className="text-xs font-bold uppercase tracking-wider">Báo cáo ngày hôm nay</span>
                  <span className="text-xl">📋</span>
                </div>
                <div className="text-3xl font-extrabold text-[#087F70] mt-2">
                  {fmtPercent(stats.today_completion_rate)}
                </div>
                <div className="mt-2">
                  <ProgressBar
                    value={stats.today_completion_rate}
                    tone={toneFromRate(stats.today_completion_rate)}
                    height={6}
                  />
                </div>
                <div className="flex items-center justify-between text-[11px] font-bold text-[#65727D] mt-2">
                  <span className="text-[#087F70]">✓ {stats.today_sent_reports_count} đã gửi</span>
                  <span className="text-[#B0791B]">📝 {stats.today_draft_reports_count} nháp</span>
                </div>
              </div>

            </div>

            {/* ─── Khối Chức năng Quản lý nhanh (Figma 454:3574 & 3575) ─── */}
            <div>
              <div className="text-xs font-bold uppercase tracking-wider text-[#8C9BA5] mb-3">
                Chức năng quản lý chính
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <Link
                  href="/school-admin/teachers"
                  className="group bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft hover:border-[#087F70] hover:shadow-pop transition flex flex-col justify-between"
                >
                  <div>
                    <div className="w-10 h-10 rounded-2xl bg-[#E6F3EB] text-[#087F70] flex items-center justify-center font-bold text-xl mb-3 group-hover:scale-105 transition">
                      👩‍🏫
                    </div>
                    <div className="font-extrabold text-base text-[#102737] group-hover:text-[#087F70] transition">
                      Quản lý Giáo viên
                    </div>
                    <p className="text-xs text-[#65727D] mt-1 line-clamp-2">
                      Nhập và sửa trực tiếp trên lưới Web Grid, phân công lớp và Excel.
                    </p>
                  </div>
                  <div className="mt-4 pt-3 border-t border-[#E5E8EB] flex items-center justify-between text-xs font-bold text-[#087F70]">
                    <span>Vào quản lý</span>
                    <span>→</span>
                  </div>
                </Link>

                <Link
                  href="/school-admin/students"
                  className="group bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft hover:border-[#087F70] hover:shadow-pop transition flex flex-col justify-between"
                >
                  <div>
                    <div className="w-10 h-10 rounded-2xl bg-[#E6F3EB] text-[#087F70] flex items-center justify-center font-bold text-xl mb-3 group-hover:scale-105 transition">
                      👶
                    </div>
                    <div className="font-extrabold text-base text-[#102737] group-hover:text-[#087F70] transition">
                      Quản lý Học sinh
                    </div>
                    <p className="text-xs text-[#65727D] mt-1 line-clamp-2">
                      Hồ sơ học sinh toàn trường, tóm tắt thông tin sức khỏe và phân lớp.
                    </p>
                  </div>
                  <div className="mt-4 pt-3 border-t border-[#E5E8EB] flex items-center justify-between text-xs font-bold text-[#087F70]">
                    <span>Vào quản lý</span>
                    <span>→</span>
                  </div>
                </Link>

                <Link
                  href="/school-admin/parents"
                  className="group bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft hover:border-[#087F70] hover:shadow-pop transition flex flex-col justify-between"
                >
                  <div>
                    <div className="w-10 h-10 rounded-2xl bg-[#E6F3EB] text-[#087F70] flex items-center justify-center font-bold text-xl mb-3 group-hover:scale-105 transition">
                      👨‍👩‍👧
                    </div>
                    <div className="font-extrabold text-base text-[#102737] group-hover:text-[#087F70] transition">
                      Quản lý Phụ huynh
                    </div>
                    <p className="text-xs text-[#65727D] mt-1 line-clamp-2">
                      Danh sách phụ huynh, tài khoản liên kết và số điện thoại liên lạc.
                    </p>
                  </div>
                  <div className="mt-4 pt-3 border-t border-[#E5E8EB] flex items-center justify-between text-xs font-bold text-[#087F70]">
                    <span>Vào quản lý</span>
                    <span>→</span>
                  </div>
                </Link>

                <Link
                  href="/school-admin/schedules"
                  className="group bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft hover:border-[#087F70] hover:shadow-pop transition flex flex-col justify-between"
                >
                  <div>
                    <div className="w-10 h-10 rounded-2xl bg-[#E6F3EB] text-[#087F70] flex items-center justify-center font-bold text-xl mb-3 group-hover:scale-105 transition">
                      📅
                    </div>
                    <div className="font-extrabold text-base text-[#102737] group-hover:text-[#087F70] transition">
                      Thời khóa biểu
                    </div>
                    <p className="text-xs text-[#65727D] mt-1 line-clamp-2">
                      Lịch theo lớp và theo tuần, kiểm tra xung đột phòng và giờ.
                    </p>
                  </div>
                  <div className="mt-4 pt-3 border-t border-[#E5E8EB] flex items-center justify-between text-xs font-bold text-[#087F70]">
                    <span>Vào quản lý</span>
                    <span>→</span>
                  </div>
                </Link>
              </div>
            </div>

            {/* ─── Tiến độ lớp & Biểu đồ xu hướng ─── */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
              
              {/* Tiến độ báo cáo theo lớp (7 cols) */}
              <div className="lg:col-span-7 bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h2 className="font-extrabold text-base text-[#102737]">
                      Tiến độ báo cáo theo lớp hôm nay
                    </h2>
                    <p className="text-xs text-[#65727D]">
                      {(classesProgress ?? []).length} lớp đang theo dõi theo thời gian thực
                    </p>
                  </div>
                </div>

                {!classesProgress ? (
                  <Spinner />
                ) : classesProgress.length === 0 ? (
                  <div className="py-8 text-center text-xs text-[#8C9BA5]">
                    Không có lớp học nào đang hoạt động.
                  </div>
                ) : (
                  <div className="divide-y divide-[#E5E8EB] max-h-[360px] overflow-y-auto">
                    {classesProgress.map((c) => {
                      const tone = toneFromRate(c.completion_rate);
                      return (
                        <div key={c.class_id} className="py-3 px-1">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <div className="font-bold text-sm text-[#102737]">
                                {c.class_name}
                              </div>
                              <div className="text-xs text-[#65727D]">
                                GV: {c.teacher_name} · {c.grade_label}
                              </div>
                            </div>
                            <div className="text-right">
                              <div
                                className="font-extrabold text-sm"
                                style={{
                                  color:
                                    tone === "ok"
                                      ? "#087F70"
                                      : tone === "warn"
                                      ? "#B0791B"
                                      : "#A93832",
                                }}
                              >
                                {fmtPercent(c.completion_rate)}
                              </div>
                              <div className="text-[11px] text-[#8C9BA5]">
                                {c.reported_children}/{c.total_children} bé
                              </div>
                            </div>
                          </div>
                          <div className="mt-2">
                            <ProgressBar
                              value={c.completion_rate}
                              tone={tone}
                              height={5}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Biểu đồ xu hướng 7 ngày (5 cols) */}
              <div className="lg:col-span-5 bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft flex flex-col justify-between">
                <div>
                  <h2 className="font-extrabold text-base text-[#102737]">
                    Xu hướng báo cáo 7 ngày
                  </h2>
                  <p className="text-xs text-[#65727D] mt-0.5">
                    Tổng số sổ liên lạc gửi phụ huynh
                  </p>

                  <div className="flex items-center gap-4 text-xs mt-3 mb-2">
                    <div className="flex items-center gap-1.5">
                      <span className="w-2.5 h-2.5 rounded-full bg-[#087F70]" />
                      <span className="font-bold text-[#087F70]">
                        Đã gửi ({trends?.reduce((s, t) => s + t.sent_reports, 0) ?? 0})
                      </span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <span className="w-2.5 h-2.5 rounded-full bg-[#B0791B]" />
                      <span className="font-bold text-[#B0791B]">
                        Bản nháp ({trends?.reduce((s, t) => s + t.draft_reports, 0) ?? 0})
                      </span>
                    </div>
                  </div>
                </div>

                <div className="mt-2">
                  <TrendChart data={trends} isLoading={!trends} />
                </div>
              </div>

            </div>

          </>
        )}
      </div>
    </SchoolAdminLayout>
  );
}

/* ════════ Mini SVG trend chart ════════ */
function TrendChart({
  data = [],
  isLoading = false,
}: {
  data?: ReportTrend[];
  isLoading?: boolean;
}) {
  const [containerWidth, setContainerWidth] = useState<number>(0);
  const roRef = useRef<ResizeObserver | null>(null);

  const containerRef = useCallback((el: HTMLDivElement | null) => {
    if (roRef.current) {
      roRef.current.disconnect();
      roRef.current = null;
    }
    if (el) {
      const update = () => {
        if (el.clientWidth > 0) {
          setContainerWidth(el.clientWidth);
        }
      };
      update();
      if (typeof ResizeObserver !== "undefined") {
        const ro = new ResizeObserver(update);
        ro.observe(el);
        roRef.current = ro;
      }
    }
  }, []);

  useEffect(() => {
    return () => {
      if (roRef.current) {
        roRef.current.disconnect();
        roRef.current = null;
      }
    };
  }, []);

  const [hoverIndex, setHoverIndex] = useState<number | null>(null);

  const { w, h, padding, points, total } = useMemo(() => {
    const w = containerWidth > 0 ? containerWidth : 480;
    const h = 180;
    const padding = 20;
    const max = Math.max(
      1,
      ...data.map((d) => Math.max(d.sent_reports, d.draft_reports)),
    );
    const total = data.length;
    const innerW = w - padding * 2;
    const innerH = h - padding * 2;
    const points = data.map((d, i) => {
      const x = padding + (innerW * i) / Math.max(1, total - 1);
      const sentY = padding + innerH - (d.sent_reports / max) * innerH;
      const draftY = padding + innerH - (d.draft_reports / max) * innerH;
      return {
        x,
        sentY,
        draftY,
        label: d.report_date,
        sent: d.sent_reports,
        draft: d.draft_reports,
      };
    });
    return { w, h, padding, points, total };
  }, [data, containerWidth]);

  const bottomY = h - padding;
  const topY = padding;
  const sentCurve = toSmoothPath(
    points.map((p) => ({ x: p.x, y: p.sentY })),
    topY,
    bottomY,
  );
  const draftCurve = toSmoothPath(
    points.map((p) => ({ x: p.x, y: p.draftY })),
    topY,
    bottomY,
  );

  const hoveredPoint = hoverIndex !== null ? points[hoverIndex] : null;

  return (
    <div ref={containerRef} className="relative w-full select-none pt-1 min-h-[200px]">
      {isLoading ? (
        <div className="flex items-center justify-center h-[180px]">
          <Spinner />
        </div>
      ) : data.length === 0 ? (
        <div className="flex items-center justify-center h-[180px] text-[#65727D] text-xs">
          Chưa có dữ liệu xu hướng.
        </div>
      ) : containerWidth === 0 ? (
        <div className="flex items-center justify-center h-[180px]">
          <Spinner />
        </div>
      ) : (
        <>
          <svg
            viewBox={`0 0 ${w} ${h}`}
            className="w-full block overflow-visible"
            style={{ height: h }}
          >
            {[0, 0.33, 0.66, 1].map((p, idx) => {
              const y = padding + (h - padding * 2) * (1 - p);
              return (
                <line
                  key={idx}
                  x1={padding}
                  x2={w - padding}
                  y1={y}
                  y2={y}
                  stroke="#E5E8EB"
                  strokeDasharray="3 3"
                />
              );
            })}

            {draftCurve && (
              <path
                d={draftCurve}
                fill="none"
                stroke="#B0791B"
                strokeWidth={2}
                strokeDasharray="4 4"
              />
            )}

            {sentCurve && (
              <path
                d={sentCurve}
                fill="none"
                stroke="#087F70"
                strokeWidth={2.5}
                strokeLinecap="round"
              />
            )}

            {points.map((p, i) => {
              const isHovered = hoverIndex === i;
              return (
                <g key={i}>
                  <circle
                    cx={p.x}
                    cy={p.sentY}
                    r={isHovered ? 5.5 : 3.5}
                    fill="#087F70"
                    stroke="#fff"
                    strokeWidth={isHovered ? 2.5 : 1.5}
                  />
                  <circle
                    cx={p.x}
                    cy={p.draftY}
                    r={isHovered ? 5 : 3}
                    fill="#B0791B"
                    stroke="#fff"
                    strokeWidth={isHovered ? 2 : 1.5}
                  />
                </g>
              );
            })}

            {points.map((p, i) => {
              const colW = (w - padding * 2) / Math.max(1, total - 1);
              return (
                <rect
                  key={i}
                  x={p.x - colW / 2}
                  y={0}
                  width={colW}
                  height={h}
                  fill="transparent"
                  className="cursor-pointer"
                  onMouseEnter={() => setHoverIndex(i)}
                  onMouseLeave={() => setHoverIndex(null)}
                />
              );
            })}
          </svg>

          {hoveredPoint && (
            <div
              className="absolute pointer-events-none bg-[#102737] text-white text-[11px] py-1.5 px-3 rounded-[10px] shadow-pop -translate-x-1/2 -translate-y-full z-20 whitespace-nowrap"
              style={{
                left: `${hoveredPoint.x}px`,
                top: `${Math.min(hoveredPoint.sentY, hoveredPoint.draftY) + 10}px`,
              }}
            >
              <div className="font-bold border-b border-white/20 pb-0.5 mb-1 text-center">
                Ngày {formatDateLabel(hoveredPoint.label)}
              </div>
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-[#087F70]" />
                <span>Đã gửi: <b>{hoveredPoint.sent}</b></span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-[#B0791B]" />
                <span>Bản nháp: <b>{hoveredPoint.draft}</b></span>
              </div>
            </div>
          )}

          <div className="relative w-full h-6 mt-1">
            {points.map((p, i) => {
              const isHovered = hoverIndex === i;
              return (
                <div
                  key={i}
                  className={`absolute -translate-x-1/2 text-center text-[11px] transition-all cursor-pointer ${
                    isHovered
                      ? "font-bold text-[#102737] scale-105"
                      : "font-medium text-[#65727D]"
                  }`}
                  style={{ left: `${p.x}px` }}
                  onMouseEnter={() => setHoverIndex(i)}
                  onMouseLeave={() => setHoverIndex(null)}
                >
                  {formatDateLabel(p.label)}
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

function toSmoothPath(
  points: { x: number; y: number }[],
  minY?: number,
  maxY?: number,
) {
  if (points.length === 0) return "";
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`;
  let d = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i - 1] ?? points[i];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[i + 2] ?? p2;

    if (Math.abs(p1.y - p2.y) < 0.001) {
      d += ` C ${p1.x + (p2.x - p1.x) / 3} ${p1.y}, ${p2.x - (p2.x - p1.x) / 3} ${p2.y}, ${p2.x} ${p2.y}`;
      continue;
    }

    let cp1x = p1.x + (p2.x - p0.x) / 6;
    let cp1y = p1.y + (p2.y - p0.y) / 6;
    let cp2x = p2.x - (p3.x - p1.x) / 6;
    let cp2y = p2.y - (p3.y - p1.y) / 6;

    const segMinY = Math.min(p1.y, p2.y);
    const segMaxY = Math.max(p1.y, p2.y);
    cp1y = Math.min(segMaxY, Math.max(segMinY, cp1y));
    cp2y = Math.min(segMaxY, Math.max(segMinY, cp2y));

    if (minY !== undefined) {
      cp1y = Math.max(minY, cp1y);
      cp2y = Math.max(minY, cp2y);
    }
    if (maxY !== undefined) {
      cp1y = Math.min(maxY, cp1y);
      cp2y = Math.min(maxY, cp2y);
    }

    d += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`;
  }
  return d;
}

function formatDateLabel(iso: string) {
  if (!iso) return "";
  const parts = iso.split("-");
  if (parts.length !== 3) return iso;
  return `${parts[2]}/${parts[1]}`;
}
