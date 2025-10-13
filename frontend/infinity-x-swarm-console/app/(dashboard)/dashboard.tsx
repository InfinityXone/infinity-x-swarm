import Sidebar from "@/components/Sidebar";
import StatCard from "@/components/StatCard";
import ServiceCard from "@/components/ServiceCard";
import dynamic from "next/dynamic";
import { fetchJSON } from "@/lib/api";
import { Metrics, Service } from "@/lib/types";
import ChatPanel from "@/components/ChatPanel";

const ThroughputChart = dynamic(() => import("@/components/charts/ThroughputChart"), { ssr: false });

async function loadServerData() {
  const [metrics, services] = await Promise.all([
    fetchJSON<Metrics>("/api/metrics"),
    fetchJSON<Service[]>("/api/cloudrun/services"),
  ]);
  return { metrics, services };
}

export default async function Dashboard() {
  const { metrics, services } = await loadServerData();
  const totals = metrics?.totals || { faucets: 0, wallets: 0, satellites: 0, errors: 0 };

  return (
    <div className="flex">
      <Sidebar />
      <main className="flex-1 p-6 space-y-6" id="overview">
        <header className="flex items-center justify-between">
          <h1 className="text-2xl font-semibold">Infinity X Swarm <span className="neon">Console</span></h1>
          <div className="text-sm text-white/60">HQ ▸ Satellites · Cloud Run</div>
        </header>

        <section className="grid md:grid-cols-4 gap-4">
          <StatCard label="Faucets" value={totals.faucets ?? 0} />
          <StatCard label="Wallets" value={totals.wallets ?? 0} />
          <StatCard label="Satellites" value={totals.satellites ?? 0} />
          <StatCard label="Errors" value={totals.errors ?? 0} />
        </section>

        <section className="grid xl:grid-cols-3 gap-4" id="agents">
          <div className="xl:col-span-2 card p-4">
            <div className="text-white text-lg font-semibold mb-3">Throughput (claims/min)</div>
            <ThroughputChart data={metrics?.rate || []} />
          </div>
          <div className="card p-4">
            <div className="text-white text-lg font-semibold mb-3">Alerts</div>
            <div className="space-y-2 text-white/80">
              {(metrics?.alerts || []).length === 0 && <div className="text-white/60">No active alerts.</div>}
              {(metrics?.alerts || []).map((a, i) => (
                <div key={i} className={`text-sm ${a.level === "error" ? "text-red-300" : "text-yellow-200"}`}>• {a.msg}</div>
              ))}
            </div>
          </div>
        </section>

        <section className="space-y-3" id="services">
          <div className="text-white text-lg font-semibold">Cloud Run Services</div>
          <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4">
            {services.map((s) => (
              <ServiceCard
                key={s.name}
                s={s}
                onAction={(action) => fetchJSON("/api/cloudrun/services", { method: "POST", body: JSON.stringify({ action, name: s.name }) })}
              />
            ))}
          </div>
        </section>

        <section id="chat"><ChatPanel /></section>
      </main>
    </div>
  );
}
