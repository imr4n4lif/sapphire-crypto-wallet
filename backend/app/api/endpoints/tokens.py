from fastapi import APIRouter, HTTPException, Query
from typing import List
import time

from app.services.coingecko import coingecko_service
from app.models.schemas import NetworkTokensResponse

router = APIRouter()

@router.get("/network/{network}", response_model=NetworkTokensResponse)
async def get_network_tokens(network: str):
    """
    Get all available tokens for a specific network
    Supported networks: ethereum, binance-smart-chain, tron, filecoin
    """
    result = await coingecko_service.get_network_tokens(network)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Network not supported"))
    
    return NetworkTokensResponse(
        success=True,
        data=result["data"],
        timestamp=int(time.time())
    )