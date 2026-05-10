from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import router

app = FastAPI(title="FitBuddy AI - Measurement Engine")

# CORS for any future HTTP endpoints
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include our WebSocket routes
app.include_router(router)

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 10000))
    # Run with uvicorn for high performance async processing
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
