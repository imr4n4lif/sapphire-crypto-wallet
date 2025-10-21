import httpx
import asyncio
from typing import List, Dict, Any, Optional
from app.core.config import settings

class CoinGeckoService:
    def __init__(self):
        self.base_url = settings.COINGECKO_API_URL
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def get_major_coins_prices(self) -> Dict[str, Any]:
        """Fetch prices for major coins: BTC, ETH, BNB, TRON, FIL"""
        coin_ids = ["bitcoin", "ethereum", "binancecoin", "tron", "filecoin"]
        
        try:
            url = f"{self.base_url}/coins/markets"
            params = {
                "vs_currency": "usd",
                "ids": ",".join(coin_ids),
                "order": "market_cap_desc",
                "per_page": 100,
                "page": 1,
                "sparkline": False,
                "price_change_percentage": "24h"
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            return {
                "success": True,
                "data": response.json()
            }
        except httpx.HTTPError as e:
            return {
                "success": False,
                "error": f"HTTP error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Unexpected error: {str(e)}"
            }
    
    async def get_token_price(self, token_id: str) -> Dict[str, Any]:
        """Fetch price for a specific token"""
        try:
            url = f"{self.base_url}/coins/{token_id}"
            params = {
                "localization": False,
                "tickers": False,
                "market_data": True,
                "community_data": False,
                "developer_data": False,
                "sparkline": False
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            market_data = data.get("market_data", {})
            
            return {
                "success": True,
                "data": {
                    "token_id": data["id"],  # Changed from "id" to "token_id"
                    "symbol": data["symbol"],
                    "name": data["name"],
                    "current_price": market_data.get("current_price", {}).get("usd", 0),
                    "price_change_24h": market_data.get("price_change_24h", 0),
                    "price_change_percentage_24h": market_data.get("price_change_percentage_24h", 0),
                    "image": data.get("image", {}).get("large", "")
                }
            }
        except httpx.HTTPError as e:
            return {
                "success": False,
                "error": f"Token not found or API error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Unexpected error: {str(e)}"
            }
    
    async def get_network_tokens(self, network: str) -> Dict[str, Any]:
        """Fetch all tokens for a specific network"""
        try:
            # Map network names to CoinGecko platform IDs
            platform_map = {
                "ethereum": "ethereum",
                "binance-smart-chain": "binance-smart-chain",
                "tron": "tron",
                "filecoin": "filecoin"
            }
            
            platform_id = platform_map.get(network.lower())
            if not platform_id:
                return {
                    "success": False,
                    "error": f"Unsupported network: {network}"
                }
            
            url = f"{self.base_url}/coins/list"
            params = {
                "include_platform": True
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            all_coins = response.json()
            
            # Filter coins that exist on the specified platform
            network_tokens = [
                {
                    "id": coin["id"],
                    "symbol": coin["symbol"],
                    "name": coin["name"],
                    "platforms": coin.get("platforms", {}),
                    "image": None  # The list endpoint doesn't provide images
                }
                for coin in all_coins 
                if coin.get("platforms", {}).get(platform_id)
            ]
            
            return {
                "success": True,
                "data": {
                    "network": network,
                    "tokens": network_tokens[:50]  # Limit to first 50 for performance
                }
            }
        except httpx.HTTPError as e:
            return {
                "success": False,
                "error": f"HTTP error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Unexpected error: {str(e)}"
            }

    async def get_network_tokens_with_images(self, network: str) -> Dict[str, Any]:
        """Fetch tokens for a specific network with images (uses market data)"""
        try:
            # Map network names to category IDs for market data
            category_map = {
                "ethereum": "ethereum-ecosystem",
                "binance-smart-chain": "binance-smart-chain",
                "tron": "tron-ecosystem",
                "filecoin": "filecoin-ecosystem"
            }
            
            category_id = category_map.get(network.lower())
            if not category_id:
                return {
                    "success": False,
                    "error": f"Unsupported network: {network}"
                }
            
            # Use market data endpoint which includes images
            url = f"{self.base_url}/coins/markets"
            params = {
                "vs_currency": "usd",
                "category": category_id,
                "order": "market_cap_desc",
                "per_page": 50,  # Limit for performance
                "page": 1,
                "sparkline": False
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            market_data = response.json()
            
            # Map platform IDs
            platform_map = {
                "ethereum": "ethereum",
                "binance-smart-chain": "binance-smart-chain",
                "tron": "tron",
                "filecoin": "filecoin"
            }
            platform_id = platform_map.get(network.lower(), network.lower())
            
            network_tokens = [
                {
                    "id": coin["id"],
                    "symbol": coin["symbol"],
                    "name": coin["name"],
                    "platforms": {platform_id: "native"},  # Simplified for market data
                    "image": coin.get("image", "")
                }
                for coin in market_data
            ]
            
            return {
                "success": True,
                "data": {
                    "network": network,
                    "tokens": network_tokens
                }
            }
        except httpx.HTTPError as e:
            return {
                "success": False,
                "error": f"HTTP error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Unexpected error: {str(e)}"
            }
    
    async def close(self):
        await self.client.aclose()

# Service instance
coingecko_service = CoinGeckoService()