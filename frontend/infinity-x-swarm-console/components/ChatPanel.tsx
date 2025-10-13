"use client";
import { useRef, useState, useEffect } from "react";
import { fetchJSON } from "@/lib/api";
import { ChatMsg } from "@/lib/types";
export default function ChatPanel() {
  const [messages, setMessages] = useState<ChatMsg[]>([
    { role: "system", content: "You are Codex Prime in Infinity X Swarm. Keep answers tight and actionable." },
  ]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);
  const send = async () => {
    if (!input.trim()) return;
    const next = [...messages, { role: "user", content: input } as ChatMsg];
    setMessages(next); setInput(""); setBusy(true);
    try {
      const res = await fetchJSON<{ reply: string }>("/api/chat", { method: "POST", body: JSON.stringify({ messages: next }) });
      setMessages([...next, { role: "assistant", content: res.reply }]);
    } catch (e: any) {
      setMessages([...next, { role: "assistant", content: `Error: ${e.message}` }]);
    } finally { setBusy(false); }
  };
  return (
    <div className="card p-4">
      <div className="text-white text-lg font-semibold mb-3">LLM Chat Console <span className="neon">Groq</span></div>
      <div className="h-72 overflow-y-auto rounded-xl p-3 bg-black/40 border border-white/10">
        {messages.map((m, i) => (
          <div key={i} className={`mb-2 text-sm ${m.role === "user" ? "text-white" : m.role === "assistant" ? "text-[#c9ffbd]" : "text-white/60"}`}>
            <span className="uppercase text-xs tracking-wider mr-2 opacity-60">{m.role}</span>{m.content}
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
      <div className="flex gap-2 mt-3">
        <input className="input w-full" placeholder="Ask Codex, orchestrate deploys, query faucets…" value={input} onChange={(e) => setInput(e.target.value)} />
        <button className="btn-primary" onClick={send} disabled={busy}>{busy ? "…" : "Send"}</button>
      </div>
    </div>
  );
}
