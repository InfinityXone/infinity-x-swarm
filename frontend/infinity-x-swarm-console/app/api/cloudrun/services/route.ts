import { NextRequest, NextResponse } from "next/server";
export const runtime = "edge";
const mock = [
  { name: "gpt-gateway",   region: "us-west1", status: "Ready",     url: "https://gpt.example", cpu: "1", memory: "512Mi", concurrency: 80, revision: "00012" },
  { name: "codex-prime",   region: "us-east1", status: "Deploying", cpu: "2", memory: "1Gi",    concurrency: 50, revision: "00031" },
  { name: "satellite-01",  region: "us-east1", status: "Ready",     url: "https://sat-01.example", cpu: "2", memory: "1Gi", concurrency: 100, revision: "00008" },
] as const;
export async function GET()  { return NextResponse.json(mock); }
export async function POST(req: NextRequest) {
  const { action, name } = await req.json();
  return NextResponse.json({ ok: true, action, name });
}
