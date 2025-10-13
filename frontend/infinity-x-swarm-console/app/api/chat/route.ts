import { NextRequest, NextResponse } from "next/server";
export const runtime = "edge";
export async function POST(req: NextRequest) {
  const { messages } = await req.json();
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) return NextResponse.json({ error: "Missing GROQ_API_KEY" }, { status: 500 });
  const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({ model: process.env.GROQ_MODEL || "llama-3.1-70b-versatile", temperature: 0.2, messages }),
  });
  if (!r.ok) return NextResponse.json({ error: await r.text() }, { status: r.status });
  const data = await r.json();
  const reply = data?.choices?.[0]?.message?.content || "(no reply)";
  return NextResponse.json({ reply });
}
