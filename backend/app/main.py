from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.endpoints import prices, tokens

app = FastAPI(
    title="Sapphire Wallet API",
    description="Backend API for Sapphire Non-Custodial Crypto Wallet",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(prices.router, prefix="/api/v1/prices", tags=["prices"])
app.include_router(tokens.router, prefix="/api/v1/tokens", tags=["tokens"])

@app.get("/")
async def root():
    return {"message": "Sapphire Wallet API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)