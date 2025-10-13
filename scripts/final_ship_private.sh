#!/usr/bin/env bash
set -euo pipefail

# ===== Inputs via env =====
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:-us-east1}"
REPO="${REPO:-swarm-registry}"

HQ_SERVICE="${HQ_SERVICE:-codex-hq}"
SAT_SERVICE="${SAT_SERVICE:-satellite-01}"
HQ_TOPIC="${HQ_TOPIC:-codex-events}"
SAT_TOPIC="${SAT_TOPIC:-satellite-events}"

HQ_AGENTS="${HQ_AGENTS:-router,planner,manager,vercel,deployer,supabase,guardian,alpha-planner,alpha-router,alpha-governor,alpha-throttle,alpha-identity,alpha-scorer,alpha-auditor,alpha-healer}"
SAT_AGENTS="${SAT_AGENTS:-faucet-a,faucet-b,faucet-c,claimer,wallet-rotator,scout,healer,alpha-planner,alpha-router,alpha-governor,alpha-throttle,alpha-identity,alpha-scorer,alpha-auditor,alpha-healer}"

CPU="${CPU:-2}" MEM="${MEM:-2Gi}" CONCURRENCY="${CONCURRENCY:-80}" TIMEOUT="${TIMEOUT:-1200}"
WORKERS="${WORKERS:-64}" BROWSER_POOL="${BROWSER_POOL:-4}" MAX_TABS="${MAX_TABS:-8}" HEADLESS="${HEADLESS:-1}"

CODEX_URL="${CODEX_URL:-}"       # optional
CODEX_TOKEN="${CODEX_TOKEN:-}"   # optional

BASE="${BASE:-$PWD}"             # scaffold here (your repo)
APP_DIR="$BASE/app"

SA_INVOKER="${SA_INVOKER:-gw-invoker}"
SA_EMAIL="${SA_INVOKER}@${PROJECT_ID}.iam.gserviceaccount.com"

REG_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}"
TAG="$(date -u +%Y%m%d-%H%M%S)"
IMG="${REG_URI}/infx-multiagent:${TAG}"

echo "▶ Project: $PROJECT_ID  Region: $REGION  Base: $BASE"
gcloud config set project "$PROJECT_ID" --quiet >/dev/null

echo "🔧 Enable APIs (idempotent)"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com pubsub.googleapis.com secretmanager.googleapis.com --quiet

echo "📦 Artifact Registry"
gcloud artifacts repositories describe "$REPO" --location "$REGION" >/dev/null 2>&1 || \
gcloud artifacts repositories create "$REPO" --location "$REGION" --repository-format docker --description "Infinity Swarm"

echo "👤 OIDC Service Account"
gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1 || \
gcloud iam service-accounts create "$SA_INVOKER" --display-name "Gateway Invoker"

echo "📡 Pub/Sub topics"
gcloud pubsub topics describe "$HQ_TOPIC"  >/dev/null 2>&1 || gcloud pubsub topics create "$HQ_TOPIC"
gcloud pubsub topics describe "$SAT_TOPIC" >/dev/null 2>&1 || gcloud pubsub topics create "$SAT_TOPIC"

echo "🗂  Scaffold app → $APP_DIR"
mkdir -p "$APP_DIR/agents"

# requirements
cat > "$BASE/requirements.txt" <<'REQ'
fastapi==0.115.0
uvicorn[standard]==0.30.6
httpx==0.27.2
python-dotenv==1.0.1
playwright==1.47.0
aiofiles==24.1.0
google-cloud-pubsub==2.21.5
REQ

# Dockerfile
cat > "$BASE/Dockerfile" <<'DOCKER'
FROM mcr.microsoft.com/playwright/python:v1.47.0-jammy
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt && playwright install --with-deps
COPY app /app
ENV PORT=8080
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT} --log-level info
DOCKER

# shared headless/API base
cat > "$APP_DIR/agents/base.py" <<'PY'
import os, json, random, asyncio
from typing import Any, Dict, List, Tuple
import httpx
from playwright.async_api import async_playwright, Browser, Page

HEADLESS = bool(int(os.getenv("HEADLESS","1")))
API_TIMEOUT = float(os.getenv("API_TIMEOUT","30"))
PAGE_TIMEOUT = float(os.getenv("PAGE_TIMEOUT","35"))
RETRY_MAX = int(os.getenv("RETRY_MAX","4"))
RETRY_BASE = float(os.getenv("RETRY_BASE","0.3"))
BROWSER_POOL = int(os.getenv("BROWSER_POOL","4"))
MAX_TABS = int(os.getenv("MAX_TABS","8"))
PROXY_POOL = json.loads(os.getenv("PROXY_POOL_JSON","[]") or "[]")
UA_ROTATE = os.getenv("UA_ROTATE","1") == "1"

def _backoff(i:int)->float: return RETRY_BASE*(2**i)*(0.5+random.random())

class Api:
    def __init__(self): self.client = httpx.AsyncClient(timeout=API_TIMEOUT)
    async def call(self, method:str, url:str, *, body=None, headers=None)->Tuple[int,Any]:
        for i in range(RETRY_MAX):
            try:
                r = await self.client.request(method.upper(), url, json=body, headers=headers)
                data = r.json() if "json" in r.headers.get("content-type","") else {"text": r.text[:4000]}
                return r.status_code, data
            except Exception:
                if i==RETRY_MAX-1: raise
                await asyncio.sleep(_backoff(i))
    async def close(self): await self.client.aclose()
api = Api()

_browser_lock = asyncio.Lock()
_pool: List[Browser] = []
_tabs: Dict[int, asyncio.Semaphore] = {}

_UA = [
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16 Safari/605.1.15",
]
def ua()->str: return random.choice(_UA) if UA_ROTATE else _UA[0]

async def ensure_pool():
    if _pool: return
    async with _browser_lock:
        if _pool: return
        pw = await async_playwright().start()
        args = ["--disable-blink-features=AutomationControlled","--no-sandbox","--disable-dev-shm-usage","--disable-gpu"]
        for i in range(max(1,BROWSER_POOL)):
            proxy = {"server": PROXY_POOL[i % len(PROXY_POOL)]} if PROXY_POOL else None
            b = await pw.chromium.launch(headless=HEADLESS, args=args, proxy=proxy)
            _pool.append(b); _tabs[i] = asyncio.Semaphore(MAX_TABS)

async def with_page(cb):
    await ensure_pool()
    idx = min(_tabs, key=lambda k: _tabs[k]._value)
    sem = _tabs[idx]; browser = _pool[idx]
    async with sem:
        ctx = await browser.new_context(user_agent=ua(), viewport={"width":1366,"height":900})
        page = await ctx.new_page()
        try:
            await page.add_init_script("""() => { Object.defineProperty(navigator, 'webdriver', {get: () => false}); }""")
            return await cb(page)
        finally:
            await ctx.close()

async def visit(url:str)->Dict[str,Any]:
    async def flow(page: Page):
        await page.goto(url, wait_until="domcontentloaded", timeout=int(float(os.getenv("PAGE_TIMEOUT","35"))*1000))
        t = await page.title()
        return {"url": url, "title": t}
    return await with_page(flow)

async def visit_many(urls:List[str])->List[Dict[str,Any]]:
    tasks = [asyncio.create_task(visit(u)) for u in urls]
    out=[]
    for t in asyncio.as_completed(tasks):
        try: out.append(await t)
        except Exception as e: out.append({"error": str(e)})
    return out
PY

# harvesters
cat > "$APP_DIR/agents/harvester_faucet.py" <<'PY'
from typing import Dict, Any, List
from pydantic import BaseModel
from .base import api, visit, visit_many

class HarvestSpec(BaseModel):
    url: str | None = None
    urls: List[str] | None = None
    api_calls: List[Dict[str, Any]] | None = None

async def run(spec: HarvestSpec) -> Dict[str, Any]:
    headless=[]
    if spec.urls: headless = await visit_many(spec.urls)
    elif spec.url: headless = [await visit(spec.url)]
    api_out=[]
    for c in (spec.api_calls or []):
        try:
            s,d = await api.call(c.get("method","GET"), c["url"], body=c.get("body"), headers=c.get("headers"))
            api_out.append({"status":s,"data":d})
        except Exception as e:
            api_out.append({"error": str(e)})
    return {"ok": True, "headless": headless, "api": api_out}
PY

cat > "$APP_DIR/agents/harvester_wallet.py" <<'PY'
from typing import Dict, Any, List
from pydantic import BaseModel
from .base import api

class WalletSpec(BaseModel):
    api_calls: List[Dict[str, Any]] | None = None

async def run(spec: WalletSpec) -> Dict[str, Any]:
    out=[]
    for c in (spec.api_calls or []):
        s,d = await api.call(c.get("method","POST"), c["url"], body=c.get("body"), headers=c.get("headers"))
        out.append({"status": s, "data": d})
    return {"ok": True, "api": out}
PY

cat > "$APP_DIR/agents/harvester_scout.py" <<'PY'
from typing import Dict, Any, List
from pydantic import BaseModel
from .base import visit_many

class ScoutSpec(BaseModel):
    urls: List[str]

async def run(spec: ScoutSpec) -> Dict[str, Any]:
    return {"ok": True, "sites": await visit_many(spec.urls)}
PY

# main app
cat > "$APP_DIR/main.py" <<'PY'
import os, json, base64, time, asyncio, traceback
from typing import Dict, Any, Callable, Awaitable
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel

ROLE = os.getenv("ROLE","SAT")
WORKERS = int(os.getenv("WORKERS","64"))
AGENTS = [a.strip() for a in os.getenv("AGENTS","").split(",") if a.strip()]

from agents import harvester_faucet, harvester_scout, harvester_wallet
from agents.base import api

async def a_faucet(spec): return await harvester_faucet.run(harvester_faucet.HarvestSpec(**spec))
async def a_wallet(spec):  return await harvester_wallet.run(harvester_wallet.WalletSpec(**spec))
async def a_scout(spec):   return await harvester_scout.run(harvester_scout.ScoutSpec(**spec))
async def a_noop(spec):    return {"ok": True}

DEFAULT = {
  "faucet-a": a_faucet, "faucet-b": a_faucet, "faucet-c": a_faucet,
  "claimer": a_faucet, "wallet-rotator": a_wallet, "scout": a_scout,
  "router": a_noop, "planner": a_noop, "manager": a_noop,
  "supabase": a_noop, "vercel": a_noop, "deployer": a_noop, "guardian": a_noop,
  "alpha-planner": a_noop, "alpha-router": a_noop, "alpha-governor": a_noop,
  "alpha-throttle": a_noop, "alpha-identity": a_noop, "alpha-scorer": a_noop,
  "alpha-auditor": a_noop, "alpha-healer": a_noop,
}
REGISTRY = {k:v for k,v in DEFAULT.items() if not AGENTS or k in AGENTS}

class Job(BaseModel):
    name: str
    spec: Dict[str, Any] = {}
    priority: int = 5
    id: str | None = None

class PQItem:
    __slots__=("prio","seq","job"); _ctr=0
    def __init__(self, prio:int, job:Job):
        PQItem._ctr+=1; self.prio=max(0,min(9,prio)); self.seq=PQItem._ctr; self.job=job
    def __lt__(self, o): return (self.prio,self.seq) < (o.prio,o.seq)

queue: asyncio.PriorityQueue[PQItem] = asyncio.PriorityQueue()

async def worker(idx:int):
    while True:
        item = await queue.get()
        job = item.job
        try:
            fn = REGISTRY.get(job.name)
            if not fn: raise RuntimeError(f"unknown agent {job.name}")
            _ = await fn(job.spec)
            # TODO: persist `_` if needed
        except Exception as e:
            print(f"[ERR {idx}] {e}\n{traceback.format_exc()}")
        finally:
            queue.task_done()

app = FastAPI(title=f"Infinity Multi-Agent ({ROLE})", version="1.0")

@app.on_event("startup")
async def startup():
    for i in range(WORKERS): asyncio.create_task(worker(i))
    print(f"🤖 {ROLE} up | agents={list(REGISTRY.keys())} | workers={WORKERS}")

@app.on_event("shutdown")
async def shutdown():
    try: await api.close()
    except: pass

@app.get("/healthz")
async def healthz():
    return {"ok": True, "role": ROLE, "agents": list(REGISTRY.keys()), "workers": WORKERS, "queue": queue.qsize(), "ts": time.time()}

@app.post("/agents/{name}/run")
async def run_agent(name: str, spec: Dict[str, Any]):
    if name not in REGISTRY: raise HTTPException(404, f"unknown agent {name}")
    try:
        res = await REGISTRY[name](spec)
        return {"ok": True, "agent": name, "result": res}
    except Exception as e:
        raise HTTPException(500, str(e))

@app.post("/agents/batch")
async def batch(payload: Dict[str, Any]):
    jobs = payload.get("jobs", [])
    for j in jobs:
        jb = Job(name=j["name"], spec=j.get("spec", {}), priority=j.get("priority",5), id=j.get("id"))
        await queue.put(PQItem(jb.priority, jb))
    return {"ok": True, "queued": len(jobs)}

@app.post("/pubsub/push")
async def pubsub_push(request: Request):
    env = await request.json()
    msg = env.get("message", {}); data_b64 = msg.get("data")
    if not data_b64: return {"ok": True, "note":"no-data"}
    data = json.loads(base64.b64decode(data_b64).decode("utf-8"))
    jobs = data if isinstance(data, list) else [data]
    for j in jobs:
        jb = Job(name=j["name"], spec=j.get("spec", {}), priority=j.get("priority",5), id=j.get("id"))
        await queue.put(PQItem(jb.priority, jb))
    return {"ok": True, "enqueued": len(jobs)}
PY

echo "🏗  Build → $IMG"
( cd "$BASE" && gcloud builds submit --tag "$IMG" --quiet )

BASE_FLAGS=( --region "$REGION" --project "$PROJECT_ID" --platform managed
             --no-allow-unauthenticated --cpu "$CPU" --memory "$MEM"
             --concurrency "$CONCURRENCY" --timeout "$TIMEOUT" )

deploy () {
  local NAME="$1" ROLE="$2" TOPIC="$3" AGENTS="$4"
  gcloud run deploy "$NAME" --image "$IMG" "${BASE_FLAGS[@]}" \
    --set-env-vars "ROLE=${ROLE},PROJECT_ID=${PROJECT_ID},GCP_PROJECT=${PROJECT_ID},REGION=${REGION},PUBSUB_TOPIC=${TOPIC},WORKERS=${WORKERS},BROWSER_POOL=${BROWSER_POOL},MAX_TABS=${MAX_TABS},HEADLESS=${HEADLESS},AGENTS=${AGENTS},CODEX_URL=${CODEX_URL},CODEX_TOKEN=${CODEX_TOKEN}" \
    --quiet

  gcloud run services add-iam-policy-binding "$NAME" --region "$REGION" \
    --member "serviceAccount:${SA_EMAIL}" --role roles/run.invoker --quiet

  local URL SUB
  URL="$(gcloud run services describe "$NAME" --region "$REGION" --format='value(status.url)')"
  SUB="${NAME}-sub"
  gcloud pubsub subscriptions delete "$SUB" >/dev/null 2>&1 || true
  gcloud pubsub subscriptions create "$SUB" --topic "$TOPIC" \
    --push-endpoint "${URL}/pubsub/push" \
    --push-auth-service-account "$SA_EMAIL" --quiet

  echo "🌐 $NAME → $URL"
}

deploy "$HQ_SERVICE"  "HQ"  "$HQ_TOPIC"  "$HQ_AGENTS"
deploy "$SAT_SERVICE" "SAT" "$SAT_TOPIC" "$SAT_AGENTS"

echo "✅ Done. Use an ID token to call private endpoints."
