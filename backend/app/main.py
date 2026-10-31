from fastapi import FastAPI

from app.api.v1.router import api_router


app = FastAPI(
    title="Audiary API",
    version="1.0.0",
    description="Phase 1 authentication and user API for Audiary.",
)
app.include_router(api_router)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}

