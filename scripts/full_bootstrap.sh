#!/bin/bash
set -e
echo "🧠 Infinity-X-Swarm • Full Developer Bootstrap v5.1"

BASE="$HOME/Infinity-X-Swarm"
ENV_SRC="/home/infinity-x-one/config/production.env"

echo "📁 Creating directories..."
mkdir -p $BASE/{HQ/{api,core,db,docker,ops},GPT-Gateway/{app,openapi,docker},Satellites/Sat-01/{app,scripts,docker},memory/{sql,seeds},UI,scripts,logs,config,.github/workflows}

echo "🔐 Loading environment..."
if [ -f "$ENV_SRC" ]; then
  cp "$ENV_SRC" $BASE/config/.env
  export $(grep -v '^#' $ENV_SRC | xargs)
else
  echo "❌ Missing production.env at $ENV_SRC"; exit 1
fi

# ---------- HQ Docker ----------
cat > $BASE/HQ/docker/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY ../.. /app
RUN pip install --no-cache-dir fastapi uvicorn supabase psycopg2-binary google-cloud-pubsub web3 solana
CMD ["uvicorn","api.main:app","--host","0.0.0.0","--port","8080"]
EOF

# ---------- GPT Gateway Docker ----------
cat > $BASE/GPT-Gateway/docker/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY ../.. /app
RUN pip install --no-cache-dir fastapi uvicorn requests
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8080"]
EOF

# ---------- Sat-01 Docker ----------
cat > $BASE/Satellites/Sat-01/docker/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY ../.. /app
RUN pip install --no-cache-dir fastapi uvicorn httpx
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8080"]
EOF

# ---------- Supabase Schema ----------
cat > $BASE/HQ/db/schema.sql <<'EOF'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS faucets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),label text,api_url text,chain text,enabled boolean DEFAULT true,rate_limit_per_min int DEFAULT 1000,auth_token text,last_checked timestamptz);
CREATE TABLE IF NOT EXISTS wallets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),address text,encrypted_key text,chain text,status text DEFAULT 'active',rotation_interval int DEFAULT 86400,last_rotated timestamptz);
CREATE TABLE IF NOT EXISTS satellites(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text UNIQUE,region text,url text,status text,agent_version text,last_ping timestamptz);
CREATE TABLE IF NOT EXISTS jobs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),type text,payload jsonb,status text DEFAULT 'queued',satellite_id uuid REFERENCES satellites(id),created_at timestamptz DEFAULT now(),dispatched_at timestamptz,completed_at timestamptz);
CREATE TABLE IF NOT EXISTS logs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),source text,level text,message text,ctx jsonb,ts timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS memory_vectors(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),agent_id text,context text,embedding vector(1536),created_at timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS profit_ledger(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),satellite_id uuid,revenue numeric,cost numeric,net numeric,ts timestamptz DEFAULT now());
EOF

echo "✅ Structure ready. Next steps:"
echo "1️⃣  chmod +x ~/Infinity-X-Swarm/scripts/full_bootstrap.sh"
echo "2️⃣  bash ~/Infinity-X-Swarm/scripts/full_bootstrap.sh"
