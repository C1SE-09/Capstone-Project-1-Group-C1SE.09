/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#eef6ff",
          100: "#d9eaff",
          200: "#bcd9ff",
          300: "#8fc1ff",
          400: "#599fff",
          500: "#3079f5",
          600: "#1d5ce0",
          700: "#1849b6",
          800: "#193f93",
          900: "#193875",
        },
      },
    },
  },
  plugins: [],
};
