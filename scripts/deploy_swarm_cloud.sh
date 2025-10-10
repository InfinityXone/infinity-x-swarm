#!/bin/bash
set -e
echo "🚀 Infinity-X-Swarm • Unified Cloud Deploy"

BASE="$HOME/Infinity-X-Swarm"
source "$BASE/config/.env"

REGION="us-west1"
PROJECT_ID=$(gcloud config get-value project)

echo "🔧 Building local Docker images..."
docker build -t hq:latest $BASE/HQ/docker
docker build -t gpt-gateway:latest $BASE/GPT-Gateway/docker
docker build -t sat-01:latest $BASE/Satellites/Sat-01/docker

echo "📤 Tagging + pushing to Artifact Registry..."
for SERVICE in hq gpt-gateway sat-01; do
  docker tag ${SERVICE}:latest us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/${SERVICE}:latest
  docker push us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/${SERVICE}:latest
done

echo "🌤️ Deploying to Cloud Run..."
for SERVICE in hq gpt-gateway sat-01; do
  gcloud run deploy ${SERVICE} \
    --image us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/${SERVICE}:latest \
    --region ${REGION} \
    --allow-unauthenticated \
    --set-env-vars "SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY},OPENAI_API_KEY=${OPENAI_API_KEY},GROQ_API_KEY=${GROQ_API_KEY},GPT_GATEWAY_API_KEY=${GPT_GATEWAY_API_KEY},ETHER_RPC=${ETHER_RPC},SOLANA_RPC=${SOLANA_RPC},WALLET_KMS_KEY=${WALLET_KMS_KEY}"
done

echo "🧭 Running Supabase migrations..."
if [ -f "$BASE/HQ/db/schema.sql" ]; then
  curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/execute_sql" \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"$(cat $BASE/HQ/db/schema.sql | sed 's/\"/\\\\\"/g')\"}"
else
  echo "⚠️  No schema.sql found, skipping migration"
fi

echo "🧠 Health checks..."
for SERVICE in hq gpt-gateway sat-01; do
  URL=$(gcloud run services describe ${SERVICE} --region ${REGION} --format='value(status.url)')
  echo "  → ${SERVICE}: ${URL}"
  curl -s -o /dev/null -w "%{http_code}" "${URL}/healthz" || echo "⚠️  health check failed for ${SERVICE}"
done

echo "✅ Deployment complete."
