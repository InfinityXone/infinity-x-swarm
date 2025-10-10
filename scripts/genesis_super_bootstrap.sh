#!/bin/bash
set -e
echo "🚀 Bootstrapping Infinity-X-Swarm..."

# --- 0. Folder scaffold
mkdir -p ~/Infinity-X-Swarm/{HQ,Satellites,UI,memory,logs,scripts,config}
mkdir -p ~/Infinity-X-Swarm/{HQ/api,HQ/db,HQ/docker,HQ/core,HQ/ops}
mkdir -p ~/Infinity-X-Swarm/Satellites/{Sat-01,docker,scripts}
mkdir -p ~/Infinity-X-Swarm/GPT-Gateway/{app,openapi,docker}

# --- 1. Sync environment
ENV_FILE="/home/infinity-x-one/config/production.env"
if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" ~/Infinity-X-Swarm/config/.env
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "❌ Env file missing, create at /home/infinity-x-one/config/production.env"
  exit 1
fi

# --- 2. Build Docker images
cd ~/Infinity-X-Swarm/HQ/docker
cat > Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY ../.. /app
RUN pip install --no-cache-dir fastapi uvicorn supabase psycopg2-binary google-cloud-pubsub web3 solana
CMD ["uvicorn","api.main:app","--host","0.0.0.0","--port","8080"]
EOF

cd ~/Infinity-X-Swarm/GPT-Gateway/docker
cat > Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY ../.. /app
RUN pip install --no-cache-dir fastapi uvicorn requests
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8080"]
EOF

cd ~/Infinity-X-Swarm
docker build -t hq:latest ./HQ/docker
docker build -t gpt-gateway:latest ./GPT-Gateway/docker

# --- 3. GitHub auto-push
git init
git remote add origin git@github.com:InfinityXone/infinity-x-swarm.git || true
git add .
git commit -m "Initial Infinity-X-Swarm v5.0 bootstrap"
git push -u origin main

# --- 4. Deploy to Google Cloud Run
gcloud auth configure-docker us-west1-docker.pkg.dev -q
PROJECT_ID=$(gcloud config get-value project)
REGION="us-west1"

for SERVICE in gpt-gateway hq; do
  docker tag ${SERVICE}:latest us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/${SERVICE}:latest
  docker push us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/${SERVICE}:latest
  gcloud run deploy ${SERVICE} \
    --image us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/${SERVICE}:latest \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --set-env-vars "SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY},OPENAI_API_KEY=${OPENAI_API_KEY},GROQ_API_KEY=${GROQ_API_KEY},GPT_GATEWAY_API_KEY=${GPT_GATEWAY_API_KEY}"
done

# --- 5. Launch metrics feed and register with GPT
METRIC_URL="https://gpt-gateway-${PROJECT_ID}.${REGION}.run.app/metrics"
echo "📊 Metric feed active at: ${METRIC_URL}"

# --- 6. Post-deploy smoke test
curl -s "${METRIC_URL}" || echo "⚠️ Metrics endpoint not ready yet"

echo "✅ Infinity-X-Swarm HQ + GPT-Gateway deployed and running."
