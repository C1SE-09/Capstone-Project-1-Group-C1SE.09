/**
 * admin-web/lib/language-context.tsx
 * ==================================
 * React Context quản lý đa ngôn ngữ (Tiếng Việt / English) cho Admin Web.
 * Tự động ghi nhớ lựa chọn vào localStorage ("admin_lang").
 */

import React, { createContext, useContext, useEffect, useState, ReactNode } from "react";
import viDict from "@/locales/vi.json";
import enDict from "@/locales/en.json";

export type Language = "vi" | "en";

interface LanguageContextType {
  lang: Language;
  setLang: (lang: Language) => void;
  toggleLang: () => void;
  t: (path: string, fallback?: string) => string;
}

const dictionaries: Record<Language, Record<string, unknown>> = {
  vi: viDict as Record<string, unknown>,
  en: enDict as Record<string, unknown>,
};

const LanguageContext = createContext<LanguageContextType>({
  lang: "vi",
  setLang: () => {},
  toggleLang: () => {},
  t: (path: string, fallback?: string) => fallback || path,
});

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Language>("vi");

  useEffect(() => {
    try {
      const saved = localStorage.getItem("admin_lang") as Language | null;
      if (saved === "vi" || saved === "en") {
        setLangState(saved);
      }
    } catch {
      // Ignore localStorage access errors
    }
  }, []);

  const setLang = (newLang: Language) => {
    setLangState(newLang);
    try {
      localStorage.setItem("admin_lang", newLang);
    } catch {
      // Ignore localStorage write errors
    }
  };

  const toggleLang = () => {
    setLang(lang === "vi" ? "en" : "vi");
  };

  const t = (path: string, fallback?: string): string => {
    const keys = path.split(".");
    let current: unknown = dictionaries[lang];
    for (const key of keys) {
      if (current && typeof current === "object" && key in current) {
        current = (current as Record<string, unknown>)[key];
      } else {
        // Fallback sang từ điển tiếng Việt nếu thiếu key tiếng Anh
        let viCurrent: unknown = dictionaries.vi;
        for (const vk of keys) {
          if (viCurrent && typeof viCurrent === "object" && vk in viCurrent) {
            viCurrent = (viCurrent as Record<string, unknown>)[vk];
          } else {
            return fallback || path;
          }
        }
        return typeof viCurrent === "string" ? viCurrent : fallback || path;
      }
    }
    return typeof current === "string" ? current : fallback || path;
  };

  return (
    <LanguageContext.Provider value={{ lang, setLang, toggleLang, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  return useContext(LanguageContext);
}

/**
 * Nút chuyển đổi ngôn ngữ gọn đẹp dùng cho Topbar / Header.
 */
export function LanguageSwitcher({ className = "" }: { className?: string }) {
  const { lang, toggleLang } = useLanguage();

  return (
    <button
      type="button"
      onClick={toggleLang}
      title={lang === "vi" ? "Chuyển sang English" : "Switch to Tiếng Việt"}
      className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-[10px] text-xs font-bold border border-[#E5E8EB] hover:bg-[#F6F7F8] hover:border-[#087F70]/30 transition text-[#102737] ${className}`}
    >
      <span>{lang === "vi" ? "🇻🇳" : "🇬🇧"}</span>
      <span>{lang === "vi" ? "VI" : "EN"}</span>
    </button>
  );
}
