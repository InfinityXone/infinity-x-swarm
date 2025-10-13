import os, json, base64, asyncio
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
import httpx

ROLE = os.getenv("ROLE","SAT")
PROJECT_ID = os.getenv("PROJECT_ID","")
REGION = os.getenv("REGION","")
PUBSUB_TOPIC = os.getenv("PUBSUB_TOPIC","")
WORKERS = int(os.getenv("WORKERS","32"))
HEADLESS = os.getenv("HEADLESS","1") == "1"
PAGE_TIMEOUT = int(float(os.getenv("PAGE_TIMEOUT","35"))*1000)

# Health + Ready
app = FastAPI(title=f"Infinity Multi-Agent ({ROLE})", version="1.0")

@app.get("/")
async def root():
    return {"ok": True, "role": ROLE}

@app.get("/healthz")
async def healthz():
    return {"status":"ok", "role": ROLE}

@app.get("/ready")
async def ready():
    # keep it simple for Cloud Run LB
    return {"ready": True, "role": ROLE}

# Pub/Sub push (GCP format)
class PubsubPush(BaseModel):
    message: Dict[str, Any] = {}

@app.post("/pubsub/push")
async def pubsub_push(payload: PubsubPush):
    msg = payload.message or {}
    data_b64 = msg.get("data")
    body = {}
    if data_b64:
        try:
            body = json.loads(base64.b64decode(data_b64).decode("utf-8"))
        except Exception as e:
            raise HTTPException(400, f"bad data: {e}")
    # route by simple keys
    name = (body.get("name") or "unknown").lower()
    spec = body.get("spec") or {}
    if name in AGENTS:
        out = await AGENTS[name](spec)
        return {"ok": True, "agent": name, "result": out}
    return {"ok": True, "noop": True, "received": body}

# Agents registry
async def a_noop(spec: Dict[str, Any]): return {"ok": True, "spec": spec}

# Minimal faucet that does both an HTTP fetch and (optionally) a Playwright hit.
async def a_faucet(spec: Dict[str, Any]):
    results = {"api": [], "headless": []}
    # Plain HTTP test
    url = (spec.get("url") or "https://httpbin.org/get")
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.get(url if url.startswith("http") else "https://httpbin.org/get")
        results["api"].append({"status": r.status_code, "data": r.json() if r.headers.get("content-type","").startswith("application/json") else r.text[:500]})
    # Optional headless (smoke defaults to off-friendly URL)
    head_url = spec.get("headless_url","https://example.org")
    if HEADLESS:
        try:
            from playwright.async_api import async_playwright
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()
                page.set_default_navigation_timeout(PAGE_TIMEOUT)
                await page.goto(head_url, wait_until="domcontentloaded")
                title = await page.title()
                html = await page.content()
                await browser.close()
            results["headless"].append({"title": title, "length": len(html)})
        except Exception as e:
            results["headless"].append({"error": str(e)})
    return {"ok": True, **results}

# You can add more named agents here
AGENTS = {
    "noop": a_noop,
    "faucet-a": a_faucet,
    "faucet-b": a_faucet,
    "faucet-c": a_faucet,
    "scout": a_faucet
}

# sync runner
class BatchPayload(BaseModel):
    payload: Dict[str, Any]

@app.post("/agents/{name}/run")
async def run_agent(name: str, payload: Dict[str, Any]):
    fn = AGENTS.get(name.lower())
    if not fn: raise HTTPException(404, f"unknown agent: {name}")
    out = await fn(payload)
    return {"ok": True, "agent": name, "result": out}

@app.post("/agents/batch")
async def batch(payload: Dict[str, Dict[str, Any]]):
    tasks = []
    for name, spec in payload.items():
        fn = AGENTS.get(name.lower(), a_noop)
        tasks.append(fn(spec))
    out = await asyncio.gather(*tasks, return_exceptions=True)
    return {"ok": True, "results": out}

# Groq "actions" style chat
class ChatBody(BaseModel):
    messages: List[Dict[str, str]]
    model: Optional[str] = None

@app.post("/actions/chat")
async def chat(body: ChatBody):
    api_key = os.getenv("GROQ_API_KEY","")
    if not api_key: raise HTTPException(500, "GROQ_API_KEY missing")
    from groq import Groq
    client = Groq(api_key=api_key)
    model = body.model or os.getenv("GROQ_MODEL","llama-3.1-70b-versatile")
    resp = client.chat.completions.create(
        model=model,
        messages=body.messages
    )
    m = resp.choices[0].message
    return {"id": resp.id, "model": model, "message": {"role": m.role, "content": m.content}}
