from typing import Dict, Any, List
from pydantic import BaseModel
from .base import visit_many

class ScoutSpec(BaseModel):
    urls: List[str]

async def run(spec: ScoutSpec) -> Dict[str, Any]:
    return {"ok": True, "sites": await visit_many(spec.urls)}
