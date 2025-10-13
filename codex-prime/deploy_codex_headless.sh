#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="my-project-52092gpt-deployer"
SERVICE="codex-prime"
REGION="us-east1"
SA="codex-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
IMG="us-east1-docker.pkg.dev/${PROJECT_ID}/${SERVICE}/${SERVICE}:latest"
ROOT_DIR="$HOME/infinity-x-swarm/${SERVICE}"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

echo "🚧 Building full headless Codex Prime at $ROOT_DIR"

# ----------------------------- Python gateway -----------------------------
cat > main.py <<'PY'
import os, asyncio, logging
from fastapi import FastAPI, Request, BackgroundTasks
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1
from supabase import create_client
import httpx, uvicorn

AGENT_NAME="Codex Prime"
PORT=int(os.getenv("PORT",8080))
logging.basicConfig(level=logging.INFO,format="%(asctime)s [%(levelname)s] %(message)s")
log=logging.getLogger(AGENT_NAME)

# ---- Secrets ----
SECRETS={k:os.getenv(k) for k in [
 "CODEX_API_KEY","CODEX_ROOT_ACCESS_CODE","SUPABASE_URL","SUPABASE_KEY",
 "GROQ_API_KEY","VERCEL_TOKEN","CODEX_GOOGLE_TOKEN","LANGCHAIN_API_KEY"
]}
for k,v in SECRETS.items():
    if v: log.info(f"🔐 {k[:12]}... loaded")
    else: log.warning(f"⚠️  {k} missing")

# ---- Clients ----
supabase=None
if SECRETS["SUPABASE_URL"] and SECRETS["SUPABASE_KEY"]:
    try:
        supabase=create_client(SECRETS["SUPABASE_URL"],SECRETS["SUPABASE_KEY"])
        log.info("✅ Supabase client initialized")
    except Exception as e: log.error(f"Supabase init failed: {e}")

app=FastAPI(title=AGENT_NAME,version="2.0")

@app.on_event("startup")
async def boot():
    log.info(f"🤖 {AGENT_NAME} booting headless on port {PORT}")
    asyncio.create_task(heartbeat())

@app.get("/healthz")
async def health(): return {"status":"ok","agent":AGENT_NAME}

@app.post("/pubsub/push")
async def pubsub_push(request:Request,bt:BackgroundTasks):
    payload=await request.json()
    msg=payload.get("message",{}).get("data","")
    bt.add_task(process_pubsub,msg)
    return JSONResponse({"received":True})

@app.post("/command")
async def command(request:Request):
    data=await request.json()
    cmd=data.get("cmd","")
    log.info(f"🧭 command: {cmd}")
    # here Codex can trigger headless actions (scrape, form fill, etc.)
    return {"ack":cmd}

async def heartbeat():
    while True:
        log.info("💓 heartbeat alive")
        await asyncio.sleep(60)

def process_pubsub(msg):
    log.info(f"📨 PubSub message: {msg}")

if __name__=="__main__":
    uvicorn.run(app,host="0.0.0.0",port=PORT)
PY

# ----------------------------- Dockerfile -----------------------------
cat > Dockerfile <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
COPY main.py requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
ENV PORT=8080
EXPOSE 8080
CMD ["python","main.py"]
DOCKER

# ----------------------------- requirements -----------------------------
cat > requirements.txt <<'REQ'
fastapi==0.115.0
uvicorn[standard]==0.30.0
supabase==2.5.0
google-cloud-pubsub==2.21.0
httpx==0.27.0
REQ

# ----------------------------- Build + Deploy -----------------------------
echo "🚀 Submitting build..."
gcloud builds submit --tag "$IMG"

echo "🌐 Deploying to Cloud Run..."
gcloud run deploy "$SERVICE" \
  --image="$IMG" \
  --region="$REGION" \
  --platform=managed \
  --service-account="$SA" \
  --set-secrets CODEX_API_KEY=CODEX_API_KEY:latest,CODEX_ROOT_ACCESS_CODE=CODEX_ROOT_ACCESS_CODE:latest,SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_KEY=SUPABASE_KEY:latest,GROQ_API_KEY=GROQ_API_KEY:latest,VERCEL_TOKEN=VERCEL_TOKEN:latest,CODEX_GOOGLE_TOKEN=CODEX_GOOGLE_TOKEN:latest,LANGCHAIN_API_KEY=LANGCHAIN_API_KEY:latest \
  --cpu=2 --memory=2Gi --max-instances=3 \
  --ingress=all --allow-unauthenticated

echo "✅ Deployment complete. Check service URL with:"
echo "gcloud run services describe $SERVICE --region=$REGION --format='value(status.url)'"
