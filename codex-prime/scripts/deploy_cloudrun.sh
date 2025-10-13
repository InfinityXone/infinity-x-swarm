#!/usr/bin/env bash
set -euo pipefail
PROJECT="my-project-52092gpt-deployer"
REGION="us-east1"
SERVICE="codex-prime"
REPO="codex-prime"

gcloud builds submit --tag ${REGION}-docker.pkg.dev/$PROJECT/$REPO/$SERVICE:latest .
gcloud run deploy $SERVICE \
  --image ${REGION}-docker.pkg.dev/$PROJECT/$REPO/$SERVICE:latest \
  --region $REGION \
  --no-allow-unauthenticated \
  --cpu 2 --memory 2Gi --port 8080 \
  --set-env-vars LOG_LEVEL=INFO,DISABLE_IP_WHITELIST=true \
  --set-secrets CODEX_API_KEY=CODEX_API_KEY:latest \
  ROOT_ACCESS_CODE=ROOT_ACCESS_CODE:latest
  SUPABASE_URL=SUPABASE_URL:latest
  SUPABASE_KEY=SUPABASE_KEY:latest
  GROQ_API_KEY=GROQ_API_KEY:latest
  OPENAI_API_KEY=OPENAI_API_KEY:latest
  VERCEL_TOKEN=VERCEL_TOKEN:latest
  GOOGLE_TOKEN=GOOGLE_TOKEN:latest
