export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "";
export const CHAT_PATH = "/api/chat";
export const METRICS_PATH = "/api/metrics";
export const SERVICES_PATH = "/api/cloudrun/services";
export async function fetchJSON<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { cache: "no-store", ...init, headers: { "Content-Type": "application/json", ...(init?.headers || {}) } });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}
