import os, json
from fastapi import FastAPI, Request
from playwright.async_api import async_playwright
import uvicorn

app = FastAPI(title="Codex Prime", version="2.2")

app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "codex-prime"}

@app.post("/headless/fetch")
async def headless_fetch(req: Request):
    data = await req.json()
    url = data.get("url")
    if not url:
        return {"error": "missing url"}
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto(url, wait_until="load")
        title = await page.title()
        await browser.close()
        return {"url": url, "title": title}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
