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
