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
