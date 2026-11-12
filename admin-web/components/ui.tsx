/**
 * components/ui.tsx
 * ==================
 * Các UI components nhỏ dùng chung — chuẩn token Figma Garden Voice.
 */

import { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  className?: string;
}
export function Card({ children, className = "" }: CardProps) {
  return (
    <div
      className={`bg-white rounded-[24px] border border-[#E5E8EB] p-6 shadow-soft ${className}`}
    >
      {children}
    </div>
  );
}

interface BadgeProps {
  bg?: string;
  text?: string;
  tone?: "success" | "warning" | "error" | "info" | "neutral";
  children: ReactNode;
}
export function Badge({ bg, text, tone, children }: BadgeProps) {
  let toneClass = "bg-[#F6F7F8] text-[#65727D]";
  if (tone === "success") toneClass = "bg-[#E5F5E7] text-[#087F70]";
  else if (tone === "warning") toneClass = "bg-[#FFF0D9] text-[#B0791B]";
  else if (tone === "error") toneClass = "bg-[#FDEAE5] text-[#A93832]";
  else if (tone === "info") toneClass = "bg-[#E7EEF3] text-[#4B6F8C]";

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold ${
        bg || text ? `${bg} ${text}` : toneClass
      }`}
    >
      {children}
    </span>
  );
}

interface StatCardProps {
  label: string;
  value: number | string;
  hint?: string;
  icon?: ReactNode;
  tone?: "default" | "danger" | "warning" | "success";
}
export function StatCard({
  label,
  value,
  hint,
  icon,
  tone = "default",
}: StatCardProps) {
  const toneClass = {
    default: "text-[#087F70]",
    danger: "text-[#A93832]",
    warning: "text-[#B0791B]",
    success: "text-[#087F70]",
  }[tone];

  return (
    <div className="bg-white rounded-[24px] border border-[#E5E8EB] p-5 shadow-soft flex items-center justify-between">
      <div>
        <div className="text-xs font-bold uppercase tracking-wider text-[#65727D]">
          {label}
        </div>
        <div className={`text-3xl font-extrabold mt-1 tracking-tight ${toneClass}`}>
          {value}
        </div>
        {hint && <div className="text-xs text-[#8C9BA5] mt-1">{hint}</div>}
      </div>
      {icon && <div className="p-3 bg-[#F6F7F8] rounded-[16px] text-2xl">{icon}</div>}
    </div>
  );
}

export function Spinner() {
  return (
    <div className="flex items-center justify-center py-12">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#087F70]" />
    </div>
  );
}

interface EmptyStateProps {
  icon?: ReactNode;
  title: string;
  description?: string;
  action?: ReactNode;
}
export function EmptyState({
  icon = "📭",
  title,
  description,
  action,
}: EmptyStateProps) {
  return (
    <div className="text-center py-16 px-4 bg-white rounded-[24px] border border-[#E5E8EB]">
      <div className="text-4xl mb-3">{icon}</div>
      <div className="text-[#102737] font-bold text-base">{title}</div>
      {description && (
        <div className="text-sm text-[#65727D] mt-1 max-w-sm mx-auto">{description}</div>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
