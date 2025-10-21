from pydantic import BaseModel
from typing import List

class Settings(BaseModel):
    APP_NAME: str = "Sapphire Wallet API"
    DEBUG: bool = False
    
    # API URLs
    COINGECKO_API_URL: str = "https://api.coingecko.com/api/v3"
    
    # Supported networks
    SUPPORTED_NETWORKS: List[str] = ["ethereum", "binance-smart-chain", "tron", "filecoin"]
    
    # Cache settings
    CACHE_TTL: int = 300  # 5 minutes

settings = Settings()