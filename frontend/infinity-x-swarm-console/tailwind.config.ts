import type { Config } from 'tailwindcss'
export default {
  content: [
    "./app/**/*.{ts,tsx,js,jsx}",
    "./components/**/*.{ts,tsx,js,jsx}",
    "./lib/**/*.{ts,tsx,js,jsx}"
  ],
  theme: {
    extend: {
      colors: { neon: { DEFAULT: "#39FF14", 600: "#1ddf00" } },
      boxShadow: { inset1: "inset 0 1px 0 rgba(255,255,255,0.05)" }
    }
  },
  plugins: []
} satisfies Config
