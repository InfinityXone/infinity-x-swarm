"use client";
import dynamic from "next/dynamic";
const ThroughputChart = dynamic(() => import("@/components/charts/ThroughputChart"), { ssr: false });
export default function ThroughputPanel({ data }: { data: { t: string; v: number }[] }) {
  return (
    <div className="xl:col-span-2 card p-4">
      <div className="text-white text-lg font-semibold mb-3">Throughput (claims/min)</div>
      <ThroughputChart data={data} />
    </div>
  );
}
