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
