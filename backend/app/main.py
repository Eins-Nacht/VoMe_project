from fastapi import FastAPI

from app.api.v1.router import api_router
from app.api.v1.audio import storage
from app.core.config import get_settings


app = FastAPI(
    title="Audiary API",
    version="1.0.0",
    description="Phase 1 authentication and user API for Audiary.",
)
app.include_router(api_router)
storage.cleanup_stale(get_settings().temporary_audio_max_age_seconds)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
