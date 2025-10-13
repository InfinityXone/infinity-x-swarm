export type ChatMsg = { role: "system" | "user" | "assistant"; content: string };
export type Service = {
  name: string; region: string; url?: string;
  status: "Ready" | "Deploying" | "Error" | "Unknown";
  cpu?: string; memory?: string; concurrency?: number; revision?: string;
};
export type Metrics = {
  rate: { t: string; v: number }[];
  totals: Record<string, number>;
  alerts: { level: "warn" | "error"; msg: string }[];
};
