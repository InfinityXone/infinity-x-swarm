import { NextResponse } from "next/server";
export const runtime = "edge";
function demo() {
  const base = Array.from({ length: 40 }, (_, i) => ({ t: `${i}`, v: Math.max(0, Math.round(5 + 4*Math.sin(i/5) + (Math.random()*2-1))) }));
  return { rate: base, totals: { faucets: 50, wallets: 820, satellites: 7, errors: 1 }, alerts: [{ level: "warn", msg: "2 faucets throttled; backoff applied" }] };
}
export async function GET() { return NextResponse.json(demo()); }
