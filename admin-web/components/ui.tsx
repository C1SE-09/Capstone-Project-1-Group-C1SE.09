/**
 * components/ui.tsx
 * ==================
 * Các UI components nhỏ dùng chung.
 */

import { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  className?: string;
}
export function Card({ children, className = "" }: CardProps) {
  return (
    <div
      className={`bg-white rounded-xl border border-gray-200 shadow-sm ${className}`}
    >
      {children}
    </div>
  );
}

interface BadgeProps {
  bg: string;
  text: string;
  children: ReactNode;
}
export function Badge({ bg, text, children }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold ${bg} ${text}`}
    >
      {children}
    </span>
  );
}

interface StatCardProps {
  label: string;
  value: number | string;
  hint?: string;
  icon?: string;
  tone?: "default" | "danger" | "warning" | "success";
}
export function StatCard({
  label,
  value,
  hint,
  icon = "📊",
  tone = "default",
}: StatCardProps) {
  const toneClass = {
    default: "text-brand-600",
    danger: "text-red-600",
    warning: "text-yellow-600",
    success: "text-green-600",
  }[tone];

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-sm text-gray-500 font-medium">{label}</div>
          <div className={`text-3xl font-bold mt-1 ${toneClass}`}>{value}</div>
          {hint && <div className="text-xs text-gray-400 mt-1">{hint}</div>}
        </div>
        <div className="text-3xl opacity-30">{icon}</div>
      </div>
    </Card>
  );
}

export function Spinner() {
  return (
    <div className="flex items-center justify-center py-10">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-brand-600" />
    </div>
  );
}

interface EmptyStateProps {
  icon?: string;
  title: string;
  description?: string;
}
export function EmptyState({
  icon = "📭",
  title,
  description,
}: EmptyStateProps) {
  return (
    <div className="text-center py-16">
      <div className="text-5xl mb-3 opacity-50">{icon}</div>
      <div className="text-gray-700 font-semibold">{title}</div>
      {description && (
        <div className="text-sm text-gray-500 mt-1">{description}</div>
      )}
    </div>
  );
}
