/** @type {import('tailwindcss').Config} */
// =================================================================
// KinderLog Design System — 100% bám sát Figma Garden Voice
// (Figma File 9RurF0HiJlYLVDV7ljp2bH / Section 568:1945 & 568:1946)
// =================================================================
module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // ─── Brand (Garden Voice Teal #087F70 / #06695E) ─────────
        brand: {
          DEFAULT: "#087F70",
          50: "#E6F3EB",
          100: "#D1E9DE",
          200: "#A3D4BD",
          300: "#5CB89D",
          400: "#087F70", // Primary Button
          500: "#087F70",
          600: "#06695E", // Dark Brand text
          700: "#05564D",
          800: "#04423C",
          900: "#022925",
          light: "#E6F3EB",
          tint: "#E6F3EB",
        },

        // ─── Canvas / Surface ─────────────────────────────────────
        canvas: "#FFFFFF",
        surface: "#FFFFFF",
        sunken: "#F6F7F8",

        // ─── Ink (Figma Navy #102737 & Gray #65727D) ──────────────
        ink: {
          DEFAULT: "#102737",
          title: "#102737",
          muted: "#65727D",
          soft: "#65727D",
          faint: "#8C9BA5",
        },

        // ─── Lines / borders (Figma 1px #E5E8EB) ──────────────────
        line: "#E5E8EB",
        lineStrong: "#D3D8DC",

        // ─── Status palette ───────────────────────────────────────
        ok: {
          DEFAULT: "#087F70",
          tint: "#E5F5E7",
        },
        warn: {
          DEFAULT: "#B0791B",
          deep: "#8A5E12",
          tint: "#FFF0D9",
        },
        bad: {
          DEFAULT: "#A93832",
          tint: "#FDEAE5",
        },
        info: {
          DEFAULT: "#4B6F8C",
          tint: "#E7EEF3",
        },
      },
      fontFamily: {
        sans: [
          "var(--font-nunito)",
          "Nunito",
          "-apple-system",
          "BlinkMacSystemFont",
          '"Segoe UI"',
          "Roboto",
          "sans-serif",
        ],
      },
      borderRadius: {
        control: "10px",
        card: "24px",
        cardLg: "28px",
        button: "24px",
        pill: "9999px",
      },
      boxShadow: {
        soft: "0 1px 3px rgba(16, 39, 55, 0.05)",
        card: "0 1px 2px rgba(16, 39, 55, 0.04)",
        pop: "0 10px 30px rgba(16, 39, 55, 0.08)",
      },
    },
  },
  plugins: [],
};
