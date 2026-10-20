/**
 * pages/school-admin/index.tsx
 * ============================
 * Trang Tổng quan (Overview) — y hệt AdminDashboardScreen.tab_Overview:
 *   - Thẻ KPI: tiến độ báo cáo ngày (sent/draft), tổng số học sinh, GV & PH.
 *   - Tiến độ báo cáo theo từng lớp.
 *   - Biểu đồ xu hướng 7 ngày (custom SVG).
 */

import { useEffect, useMemo, useState } from "react";
import useSWR from "swr";
import SchoolAdminLayout from "@/components/SchoolAdminLayout";
import { KpiCard, Pill, ProgressBar, Spinner } from "@/components/ui-school";
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
  return `${(p * 100).toFixed(p < 1 ? 1 : 0)}%`;
}

function toneFromRate(r: number): "ok" | "warn" | "bad" {
  if (r >= 0.8) return "ok";
  if (r >= 0.4) return "warn";
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
    setSchoolName(stored.school_name || "Trường Mầm Non");
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
        query: q as any,
        account: "schoolAdmin",
      }),
    { refreshInterval: 60000 },
  );

  if (!ready) return null;

  return (
    <SchoolAdminLayout active="overview" pageTitle="Tổng quan hệ thống">
      <p className="text-sm text-ink-soft -mt-3 mb-5">
        Theo dõi hoạt động trường học, tiến độ báo cáo và tài nguyên hệ thống
        theo thời gian thực · {schoolName}
      </p>

      {statsErr && (
        <div className="card p-4 mb-5 bg-bad-tint border-bad/30 text-bad">
          <div className="font-semibold text-sm">Không thể tải thống kê</div>
          <div className="text-xs mt-1">
            {statsErr instanceof ApiError ? statsErr.detail : "Vui lòng thử lại."}
          </div>
        </div>
      )}

      {!stats ? (
        <Spinner />
      ) : (
        <>
          {/* Row 1: Completion */}
          <KpiCard
            icon="📋"
            title="Tiến độ báo cáo ngày"
            subtitle="Theo dõi tỷ lệ hoàn thành sổ liên lạc hôm nay"
            value={fmtPercent(stats.today_completion_rate)}
            tone={toneFromRate(stats.today_completion_rate)}
          >
            <div className="mt-3">
              <ProgressBar
                value={stats.today_completion_rate}
                tone={toneFromRate(stats.today_completion_rate)}
                height={8}
              />
            </div>
            <div className="grid grid-cols-2 gap-2 mt-3">
              <div
                className="rounded-control px-3 py-2 flex items-center justify-center gap-2 text-xs font-bold"
                style={{ background: "#E7F1EA", color: "#3F8B5C" }}
              >
                <span>✓</span>
                {stats.today_sent_reports_count} đã gửi
              </div>
              <div
                className="rounded-control px-3 py-2 flex items-center justify-center gap-2 text-xs font-bold"
                style={{ background: "#F6EED9", color: "#8A5E12" }}
              >
                <span>📝</span>
                {stats.today_draft_reports_count} bản nháp
              </div>
            </div>
          </KpiCard>

          {/* Row 2: Children + People */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-3">
            <KpiCard
              icon="👶"
              title="Tổng số học sinh"
              value={
                <span>
                  {stats.total_children}{" "}
                  <span className="text-base font-medium text-ink-soft">bé</span>
                </span>
              }
              rightSlot={
                <div
                  className="flex items-center gap-1 text-[11px] font-semibold px-2 py-1 rounded-control"
                  style={{ background: "#EFECE5", color: "#605D57" }}
                >
                  🏫 {stats.total_classes} lớp đang hoạt động
                </div>
              }
            />

            <KpiCard
              icon="👨‍👩‍👧"
              title="Nhân sự & Phụ huynh"
              tone="info"
              value={
                <div className="grid grid-cols-2 gap-2 mt-1">
                  <div className="flex items-center gap-2">
                    <div
                      className="w-9 h-9 flex items-center justify-center rounded-full text-base"
                      style={{ background: "#E6EFEC", color: "#16665a" }}
                    >
                      🎓
                    </div>
                    <div>
                      <div className="font-extrabold text-lg text-ink leading-tight">
                        {stats.total_teachers}
                      </div>
                      <div className="text-[11px] text-ink-soft">Giáo viên</div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <div
                      className="w-9 h-9 flex items-center justify-center rounded-full text-base"
                      style={{ background: "#E7EEF3", color: "#4B6F8C" }}
                    >
                      👪
                    </div>
                    <div>
                      <div className="font-extrabold text-lg text-ink leading-tight">
                        {stats.total_parents}
                      </div>
                      <div className="text-[11px] text-ink-soft">Phụ huynh</div>
                    </div>
                  </div>
                </div>
              }
            />
          </div>

          {/* Row 3: Class progress */}
          <div className="card mt-5 overflow-hidden">
            <div className="px-5 py-4 border-b border-line">
              <div className="font-bold text-ink">
                Tiến độ báo cáo theo lớp học trong ngày
              </div>
              <div className="text-xs text-ink-soft mt-0.5">
                {(classesProgress ?? []).length} lớp phù hợp · Cập nhật thời
                gian thực
              </div>
            </div>
            {!classesProgress ? (
              <Spinner />
            ) : classesProgress.length === 0 ? (
              <div className="text-center py-12 text-ink-soft text-sm">
                Không tìm thấy lớp hoặc giáo viên phù hợp.
              </div>
            ) : (
              <ul>
                {classesProgress.map((c, idx) => {
                  const tone = toneFromRate(c.completion_rate);
                  return (
                    <li
                      key={c.class_id}
                      className={`px-5 py-4 ${idx > 0 ? "border-t border-line" : ""}`}
                    >
                      <div className="flex items-center justify-between gap-3">
                        <div className="min-w-0 flex-1">
                          <div className="font-bold text-ink">
                            {c.class_name}
                          </div>
                          <div className="text-xs text-ink-soft">
                            {c.grade_label || "Khối mầm non"}
                          </div>
                        </div>
                        <div
                          className="font-extrabold text-lg"
                          style={{
                            color:
                              tone === "ok"
                                ? "#3F8B5C"
                                : tone === "warn"
                                  ? "#B0791B"
                                  : "#BB4A34",
                          }}
                        >
                          {(c.completion_rate * 100).toFixed(0)}%
                        </div>
                      </div>
                      <div className="flex items-center justify-between text-xs text-ink-soft mt-2">
                        <div className="flex items-center gap-1.5">
                          <span>👤</span>
                          <span className="truncate">{c.teacher_name}</span>
                        </div>
                        <div>
                          <span className="font-semibold text-ink">
                            {c.reported_children}
                          </span>
                          /{c.total_children} bé
                        </div>
                      </div>
                      <div className="mt-2">
                        <ProgressBar
                          value={c.completion_rate}
                          tone={tone}
                          height={6}
                        />
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>

          {/* Row 4: Trend chart */}
          <div className="card mt-5 p-5">
            <div className="flex items-start justify-between gap-3 mb-3">
              <div>
                <div className="font-bold text-ink">
                  Xu hướng báo cáo 7 ngày gần nhất
                </div>
                <div className="text-xs text-ink-soft mt-0.5">
                  {trends
                      ? `${trends.reduce((s, t) => s + t.total_reports, 0)} báo cáo tổng cộng`
                      : "Đang tải..."}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-4 text-xs mb-2">
              <div className="flex items-center gap-1.5">
                <span
                  className="inline-block w-2.5 h-2.5 rounded-full"
                  style={{ background: "#16665a" }}
                ></span>
                <span className="font-semibold" style={{ color: "#16665a" }}>
                  Đã gửi (
                  {trends?.reduce((s, t) => s + t.sent_reports, 0) ?? 0})
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <span
                  className="inline-block w-2.5 h-2.5 rounded-full"
                  style={{ background: "#B0791B" }}
                ></span>
                <span className="font-semibold" style={{ color: "#B0791B" }}>
                  Bản nháp (
                  {trends?.reduce((s, t) => s + t.draft_reports, 0) ?? 0})
                </span>
              </div>
            </div>
            <TrendChart data={trends ?? []} />
          </div>
        </>
      )}
    </SchoolAdminLayout>
  );
}

/* ════════ Mini SVG trend chart ════════ */
function TrendChart({ data }: { data: ReportTrend[] }) {
  const { w, h, padding, points, max, total } = useMemo(() => {
    const w = 720;
    const h = 220;
    const padding = 32;
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
      return { x, sentY, draftY, label: d.report_date, sent: d.sent_reports, draft: d.draft_reports };
    });
    return { w, h, padding, points, max, total };
  }, [data]);

  if (data.length === 0) {
    return (
      <div className="text-center text-ink-soft text-sm py-12">
        Chưa có dữ liệu xu hướng.
      </div>
    );
  }

  const sentPath = points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.sentY}`)
    .join(" ");
  const draftPath = points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.draftY}`)
    .join(" ");

  // Build smooth curves using simple Catmull-Rom → cubic
  const sentCurve = toSmoothPath(points.map((p) => ({ x: p.x, y: p.sentY })));
  const draftCurve = toSmoothPath(points.map((p) => ({ x: p.x, y: p.draftY })));

  return (
    <svg
      viewBox={`0 0 ${w} ${h}`}
      preserveAspectRatio="none"
      style={{ width: "100%", height: 220 }}
    >
      {/* Grid lines */}
      {[0, 0.25, 0.5, 0.75, 1].map((p, idx) => {
        const y = padding + (h - padding * 2) * (1 - p);
        return (
          <line
            key={idx}
            x1={padding}
            x2={w - padding}
            y1={y}
            y2={y}
            stroke="#E7E3DA"
            strokeDasharray="3 3"
          />
        );
      })}

      {/* Sent line */}
      <path
        d={sentCurve}
        stroke="#16665a"
        strokeWidth={2.5}
        fill="none"
        strokeLinecap="round"
      />
      <path
        d={`${sentCurve} L ${points[points.length - 1].x} ${h - padding} L ${points[0].x} ${h - padding} Z`}
        fill="#16665a"
        opacity="0.10"
      />

      {/* Draft line */}
      <path
        d={draftCurve}
        stroke="#B0791B"
        strokeWidth={2.5}
        fill="none"
        strokeLinecap="round"
        strokeDasharray="0"
      />

      {/* Points */}
      {points.map((p, i) => (
        <g key={i}>
          <circle cx={p.x} cy={p.sentY} r={3.5} fill="#16665a" stroke="#fff" strokeWidth={1.5} />
          <circle cx={p.x} cy={p.draftY} r={3.5} fill="#B0791B" stroke="#fff" strokeWidth={1.5} />
        </g>
      ))}

      {/* X labels (date) */}
      {points.map((p, i) => (
        <text
          key={i}
          x={p.x}
          y={h - 6}
          fontSize="10"
          fill="#757169"
          textAnchor="middle"
        >
          {formatDateLabel(p.label)}
        </text>
      ))}
    </svg>
  );
}

function toSmoothPath(points: { x: number; y: number }[]) {
  if (points.length === 0) return "";
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`;
  let d = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i - 1] ?? points[i];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[i + 2] ?? p2;
    const cp1x = p1.x + (p2.x - p0.x) / 6;
    const cp1y = p1.y + (p2.y - p0.y) / 6;
    const cp2x = p2.x - (p3.x - p1.x) / 6;
    const cp2y = p2.y - (p3.y - p1.y) / 6;
    d += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`;
  }
  return d;
}

function formatDateLabel(iso: string) {
  // "2026-10-15" -> "15/10"
  if (!iso) return "";
  const parts = iso.split("-");
  if (parts.length !== 3) return iso;
  return `${parts[2]}/${parts[1]}`;
}