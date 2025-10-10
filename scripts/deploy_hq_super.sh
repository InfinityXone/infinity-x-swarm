#!/bin/bash
set -e
echo "🚀 Infinity-X-Swarm HQ • Full Cloud Run Bootstrap"

# === Stage 1: Dockerfile creation ===
echo "📦 Writing Dockerfile..."
mkdir -p ~/Infinity-X-Swarm/HQ/docker
cat <<'EOF' > ~/Infinity-X-Swarm/HQ/docker/Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY . /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    supabase \
    psycopg2-binary \
    google-cloud-pubsub \
    web3 \
    solana

# Cloud Run injects \$PORT automatically; just use it in CMD
CMD ["sh", "-c", "uvicorn api.main:app --host 0.0.0.0 --port \${PORT}"]
EOF

# === Stage 2: Create a simple FastAPI app ===
echo "🧠 Writing HQ FastAPI entrypoint..."
mkdir -p ~/Infinity-X-Swarm/HQ/api
cat <<'EOF' > ~/Infinity-X-Swarm/HQ/api/main.py
from fastapi import FastAPI
import os

app = FastAPI(title="Infinity-X-Swarm HQ")

@app.get("/healthz")
def health():
    return {"status": "ok", "port": os.getenv("PORT", "8080")}

@app.get("/")
def root():
    return {"message": "🚀 Infinity-X-Swarm HQ online"}
EOF

# === Stage 3: Build & Push ===
echo "🛠️ Building Docker image..."
cd ~/Infinity-X-Swarm/HQ/docker
docker build -t hq:latest .

PROJECT_ID=$(gcloud config get-value project)
REGION="us-west1"
REGISTRY="us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy"

echo "📤 Tagging and pushing..."
docker tag hq:latest ${REGISTRY}/hq:latest
docker push ${REGISTRY}/hq:latest

# === Stage 4: Deploy ===
echo "🌩️ Deploying HQ to Cloud Run..."
gcloud run deploy hq \
  --image ${REGISTRY}/hq:latest \
  --region ${REGION} \
  --allow-unauthenticated \
  --set-secrets "SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest,GPT_GATEWAY_API_KEY=GPT_GATEWAY_API_KEY:latest,OPENAI_API_KEY=OPENAI_API_KEY:latest,GROQ_API_KEY=GROQ_API_KEY:latest,CODEX_API_KEY=CODEX_API_KEY:latest,WALLET_KMS_KEY=WALLET_KMS_KEY:latest"

# === Stage 5: Verify ===
echo "🧩 Checking HQ health..."
HQ_URL=$(gcloud run services describe hq --region ${REGION} --format='value(status.url)')
echo "🌐 HQ URL: ${HQ_URL}"
curl -s "${HQ_URL}/healthz" | jq || curl -s "${HQ_URL}/healthz"
echo "✅ HQ deployment complete."
