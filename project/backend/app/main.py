from fastapi import FastAPI

app = FastAPI(title="KinderLog API", version="0.1.0")

@app.get("/api/health")
async def health_check() -> dict:
    return {"status": "healthy"}
