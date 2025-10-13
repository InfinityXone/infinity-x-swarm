
# --- AUTO-APPEND: Supabase fields ---
try:
    from pydantic import BaseModel
    class _S(BaseModel):
        SUPABASE_URL: str = os.getenv("SUPABASE_URL","")
        SUPABASE_KEY: str = os.getenv("SUPABASE_KEY","")
    _s=_S()
    if 'settings' in globals():
        settings.SUPABASE_URL = _s.SUPABASE_URL
        settings.SUPABASE_KEY = _s.SUPABASE_KEY
except Exception:
    pass
