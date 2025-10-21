from pydantic import BaseModel
from typing import List, Optional, Dict, Any

class CoinPrice(BaseModel):
    coin_id: str
    symbol: str
    name: str
    current_price: float
    price_change_24h: float
    price_change_percentage_24h: float
    image: str
    last_updated: str

class TokenInfo(BaseModel):
    id: str
    symbol: str
    name: str
    platforms: Dict[str, Optional[str]]
    image: str

class TokenPrice(BaseModel):
    token_id: str
    symbol: str
    name: str
    current_price: float
    price_change_24h: Optional[float]
    price_change_percentage_24h: Optional[float]
    image: str

class NetworkTokens(BaseModel):
    network: str
    tokens: List[TokenInfo]

class PriceResponse(BaseModel):
    success: bool
    data: Dict[str, CoinPrice]
    timestamp: int

class TokenPriceResponse(BaseModel):
    success: bool
    data: TokenPrice
    timestamp: int

class NetworkTokensResponse(BaseModel):
    success: bool
    data: NetworkTokens
    timestamp: int