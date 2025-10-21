from fastapi import APIRouter, HTTPException, Query
from typing import List
import time

from app.services.coingecko import coingecko_service
from app.models.schemas import PriceResponse, TokenPriceResponse

router = APIRouter()

@router.get("/major-coins", response_model=PriceResponse)
async def get_major_coins_prices():
    """
    Get current prices for major coins: BTC, ETH, BNB, TRON, FIL
    """
    result = await coingecko_service.get_major_coins_prices()
    
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result.get("error", "Unknown error"))
    
    # Transform the data
    transformed_data = {}
    for coin_data in result["data"]:
        coin_id = coin_data["id"]
        transformed_data[coin_id] = {
            "coin_id": coin_id,
            "symbol": coin_data["symbol"],
            "name": coin_data["name"],
            "current_price": coin_data["current_price"],
            "price_change_24h": coin_data["price_change_24h"],
            "price_change_percentage_24h": coin_data["price_change_percentage_24h"],
            "image": coin_data["image"],
            "last_updated": coin_data["last_updated"]
        }
    
    return PriceResponse(
        success=True,
        data=transformed_data,
        timestamp=int(time.time())
    )

@router.get("/token/{token_id}", response_model=TokenPriceResponse)
async def get_token_price(token_id: str):
    """
    Get current price for a specific token by its CoinGecko ID
    """
    result = await coingecko_service.get_token_price(token_id)
    
    if not result["success"]:
        raise HTTPException(status_code=404, detail=result.get("error", "Token not found"))
    
    return TokenPriceResponse(
        success=True,
        data=result["data"],
        timestamp=int(time.time())
    )