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


@app.get("/livez")
async def livez():
    return {"ok": True}

@app.get("/readyz")
async def readyz():
    return {"ok": True, "workers": WORKERS, "agents": list(REGISTRY.keys())}

# alias if you want a second path
@app.get("/health")
async def health_alias():
    return await healthz()

