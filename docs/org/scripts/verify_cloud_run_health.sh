#!/usr/bin/env bash
set -euo pipefail
CSV="${1:-./08_Inventory/cloud_run_services.csv}"
out="./08_Inventory/cloud_run_health_report.csv"
echo "service,region,url,status,code" > "$out"
tail -n +2 "$CSV" | while IFS=, read -r service region url revision last_ready; do
  [ -z "$url" ] && continue
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url/healthz" || echo "000")
  status="down"; [ "$code" = "200" ] && status="ok"
  echo "$service,$region,$url,$status,$code" >> "$out"
done
echo "✅ Health report: $out"
