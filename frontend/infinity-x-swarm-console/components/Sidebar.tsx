"use client";
import { Cpu, Cloud, GitBranch, Code2, Bot, Settings, Gauge } from "lucide-react";
import Link from "next/link";
const Item = ({ icon, label, href }: any) => (
  <Link href={href} className="flex items-center gap-3 px-3 py-2 rounded-xl hover:bg-white/10 border border-transparent hover:border-white/10">
    {icon}<span className="text-sm tracking-wide">{label}</span>
  </Link>
);
export default function Sidebar() {
  return (
    <aside className="w-[260px] shrink-0 h-screen sticky top-0 p-4 border-r border-white/10 bg-black/30 backdrop-blur">
      <div className="flex items-center gap-3 mb-6">
        <img src="/logo.svg" alt="IX" className="h-8 w-8"/>
        <div><div className="text-sm text-white/70">Infinity X</div><div className="font-semibold -mt-0.5">Swarm Console</div></div>
      </div>
      <nav className="space-y-1">
        <Item href="#overview" label="Overview" icon={<Gauge className="h-4 w-4 text-[var(--ix-neon)]"/>} />
        <Item href="#services" label="Cloud Run Services" icon={<Cloud className="h-4 w-4 text-[var(--ix-neon)]"/>} />
        <Item href="#agents" label="Agents (HQ ▸ Satellites)" icon={<Cpu className="h-4 w-4 text-[var(--ix-neon)]"/>} />
        <Item href="#code" label="Code Ops" icon={<Code2 className="h-4 w-4 text-[var(--ix-neon)]"/>} />
        <Item href="#orchestration" label="Orchestration" icon={<GitBranch className="h-4 w-4 text-[var(--ix-neon)]"/>} />
        <Item href="#chat" label="LLM Chat" icon={<Bot className="h-4 w-4 text-[var(--ix-neon)]"/>} />
        <Item href="#settings" label="Settings" icon={<Settings className="h-4 w-4 text-[var(--ix-neon)]"/>} />
      </nav>
      <div className="mt-6 text-xs text-white/50">Omega Directive · maintain ≥110% efficiency</div>
    </aside>
  );
}
