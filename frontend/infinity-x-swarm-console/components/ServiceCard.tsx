"use client";
import { Service } from "@/lib/types";
export default function ServiceCard({ s, onAction }: { s: Service; onAction: (action: string) => void }) {
  const badge = (cls: string) => `badge ${cls}`;
  return (
    <div className="card p-4">
      <div className="flex items-center justify-between">
        <div className="text-lg font-semibold">{s.name}</div>
        <div className={
          s.status === "Ready" ? badge("bg-emerald-400/20 text-emerald-300 border-emerald-400/30") :
          s.status === "Error" ? badge("bg-red-500/20 text-red-200 border-red-500/30") :
          badge("bg-yellow-500/20 text-yellow-200 border-yellow-500/30")
        }>{s.status}</div>
      </div>
      <div className="grid grid-cols-2 gap-2 mt-3 text-sm text-white/80">
        <div>Region: <span className="text-white">{s.region}</span></div>
        <div>Revision: <span className="text-white/90">{s.revision || "—"}</span></div>
        <div>CPU: <span className="text-white/90">{s.cpu || "—"}</span></div>
        <div>Memory: <span className="text-white/90">{s.memory || "—"}</span></div>
        <div>Concurrency: <span className="text-white/90">{s.concurrency ?? "—"}</span></div>
      </div>
      <div className="flex gap-2 pt-3">
        <button onClick={() => onAction("restart")} className="btn-ghost">Restart</button>
        <button onClick={() => onAction("scale")} className="btn-primary">Scale</button>
        {s.url && <a href={s.url} target="_blank" className="btn-ghost ml-auto" rel="noreferrer">Open</a>}
      </div>
    </div>
  );
}
