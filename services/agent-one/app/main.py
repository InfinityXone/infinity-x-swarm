from fastapi import FastAPI
from fastapi.responses import JSONResponse
import asyncio, logging, os

app = FastAPI(title="Headless Agent", version="1.0.0")

@app.on_event("startup")
async def on_startup():
    logging.basicConfig(level=logging.INFO)
    logging.info("🚀 Agent startup complete. Listening on PORT=%s", os.getenv("PORT", "8080"))

@app.get("/")
async def root():
    return {"ok": True, "service": "headless-agent", "version": "1.0.0"}

@app.get("/healthz")
async def healthz():
    # ultra-light liveness check
    return JSONResponse({"status": "ok"}, status_code=200)

@app.get("/ready")
async def ready():
    # place any dependency checks here (DB, Supabase, etc.)
    # keep it simple so Cloud Run doesn't flap
    return JSONResponse({"ready": True}, status_code=200)
