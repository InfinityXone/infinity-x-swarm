#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-my-project-52092gpt-deployer}"
REGIONS="${REGIONS:-us-east1 us-west1}"
OUT_DIR="${OUT_DIR:-./08_Inventory}"

mkdir -p "$OUT_DIR"

# Make sure gcloud is looking at the right project
gcloud config set core/project "$PROJECT_ID" >/dev/null

echo "Collecting Cloud Run services..."
: > "$OUT_DIR/cloud_run_services.csv"
echo "service,region,url,revision,last_ready" >> "$OUT_DIR/cloud_run_services.csv"
for r in $REGIONS; do
  gcloud run services list --project "$PROJECT_ID" --region "$r" \
    --format="value(metadata.name,status.url,status.latestReadyRevisionName,status.conditions[?type='Ready'].lastTransitionTime)" \
  | awk -v region="$r" 'NF{printf "%s,%s,%s,%s,%s\n",$1,region,$2,$3,$4}' >> "$OUT_DIR/cloud_run_services.csv" || true
done

echo "Collecting GCS buckets..."
: > "$OUT_DIR/gcs_buckets.csv"
echo "bucket,region,purpose,retention_policy" >> "$OUT_DIR/gcs_buckets.csv"
gcloud storage buckets list --project "$PROJECT_ID" --format="value(name,location)" \
| awk '{printf "%s,%s,,\n",$1,$2}' >> "$OUT_DIR/gcs_buckets.csv" || true

echo "Collecting Cloud Scheduler jobs..."
: > "$OUT_DIR/scheduler_jobs.csv"
echo "job_name,region,frequency,target,notes" >> "$OUT_DIR/scheduler_jobs.csv"
for r in $REGIONS; do
  # jobs list requires --location
  if gcloud scheduler jobs list --project "$PROJECT_ID" --location="$r" \
      --format="value(name,region,schedule,attemptDeadline)" >/tmp/_sched_$r.txt 2>/dev/null; then
    awk -F'\t' 'NF{printf "%s,%s,%s,%s,\n",$1,$2,$3,$4}' /tmp/_sched_$r.txt >> "$OUT_DIR/scheduler_jobs.csv"
  fi
done

echo "✅ Inventory written to $OUT_DIR"
