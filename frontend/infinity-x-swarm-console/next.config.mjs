import { fileURLToPath } from "url";
import path from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: { appDir: true },
  // Point tracing to your repo root (two levels up from the app dir)
  outputFileTracingRoot: path.join(__dirname, "..", ".."),
};

export default nextConfig;
