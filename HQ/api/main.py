from fastapi import FastAPI
import os

app = FastAPI(title="Infinity-X-Swarm HQ")

@app.get("/healthz")
def health():
    return {"status": "ok", "port": os.getenv("PORT", "8080")}

@app.get("/")
def root():
    return {"message": "🚀 Infinity-X-Swarm HQ online"}
