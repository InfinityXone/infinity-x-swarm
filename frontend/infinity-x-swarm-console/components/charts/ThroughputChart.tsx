"use client";
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip } from "recharts";
export default function ThroughputChart({ data }: { data: { t: string; v: number }[] }) {
  return (
    <div className="h-56">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data}>
          <XAxis dataKey="t" hide />
          <YAxis stroke="#aaa" tick={{ fill: "#aaa", fontSize: 12 }} />
          <Tooltip contentStyle={{ background: "#101013", border: "1px solid rgba(255,255,255,0.1)", color: "white" }} />
          <Line type="monotone" dataKey="v" stroke="#39ff14" strokeWidth={2} dot={false} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
