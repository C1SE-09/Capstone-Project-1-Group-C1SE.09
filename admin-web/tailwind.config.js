/** @type {import('tailwindcss').Config} */
// =================================================================
// KinderLog Design System — bám sát 100% KColors trong Flutter app
// (frontend/lib/features/kindergarten_dashboard/theme.dart)
// =================================================================
module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // ─── Brand (Kindergarten teal) ────────────────────────────
        brand: {
          DEFAULT: "#16665A",
          50: "#E6EFEC",
          100: "#D1E0D9",
          200: "#A3C2B3",
          300: "#75A48D",
          400: "#16665A", // brand (primary)
          500: "#16665A",
          600: "#114F46", // brandStrong
          700: "#0E3D37",
          800: "#0A2B27",
          900: "#06191D",
        },

        // ─── Canvas / Surface (warm beige) ────────────────────────
        canvas: "#F6F4EF",
        surface: "#FFFFFF",
        sunken: "#EFECE5",

        // ─── Ink (text) ───────────────────────────────────────────
        ink: {
          DEFAULT: "#2A2926",
          soft: "#605D57",
          faint: "#757169",
        },

        // ─── Lines / borders ──────────────────────────────────────
        line: "#E7E3DA",
        lineStrong: "#D9D4C9",

        // ─── Status palette ───────────────────────────────────────
        ok: {
          DEFAULT: "#3F8B5C",
          tint: "#E7F1EA",
        },
        warn: {
          DEFAULT: "#B0791B",
          deep: "#8A5E12",
          tint: "#F6EED9",
        },
        bad: {
          DEFAULT: "#BB4A34",
          tint: "#F6E6E1",
        },
        info: {
          DEFAULT: "#4B6F8C",
          tint: "#E7EEF3",
        },
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          '"Segoe UI"',
          "Roboto",
          '"Helvetica Neue"',
          "Arial",
          '"BeVietnamPro"',
          "sans-serif",
        ],
      },
      borderRadius: {
        control: "8px",
        card: "12px",
      },
      boxShadow: {
        soft: "0 1px 2px rgba(20, 24, 28, 0.04), 0 2px 8px rgba(20, 24, 28, 0.04)",
        card: "0 1px 2px rgba(20, 24, 28, 0.06)",
        pop: "0 6px 24px rgba(20, 24, 28, 0.10)",
      },
    },
  },
  plugins: [],
};