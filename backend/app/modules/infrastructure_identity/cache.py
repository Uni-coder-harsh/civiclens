import time
import json
import logging
from typing import Any, Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

# Fallback in-memory cache if Redis is unavailable or unconfigured
_MEMORY_CACHE: dict[str, tuple[float, str]] = {}


class IdentityCache:
    """
    Caching layer for geocoding, OSM feature queries, and government procurement lookups.
    Uses Redis when connected, with automatic fallback to in-memory TTL caching.
    """

    @staticmethod
    def _make_geo_key(lat: float, lng: float, prefix: str = "identity_geo") -> str:
        # Quantize coordinates to ~10-20m precision (4 decimal places)
        return f"{prefix}:{lat:.4f}:{lng:.4f}"

    @classmethod
    async def get(cls, key: str) -> Optional[dict]:
        try:
            if settings.REDIS_URL:
                import redis.asyncio as aioredis
                client = aioredis.from_url(settings.redis_url, decode_responses=True)
                val = await client.get(key)
                await client.aclose()
                if val:
                    return json.loads(val)
        except Exception as e:
            logger.debug(f"[IdentityCache] Redis read skip ({e}), using memory fallback.")

        # In-memory fallback
        if key in _MEMORY_CACHE:
            expire_at, val_str = _MEMORY_CACHE[key]
            if time.time() < expire_at:
                return json.loads(val_str)
            else:
                del _MEMORY_CACHE[key]
        return None

    @classmethod
    async def set(cls, key: str, value: dict, ttl_seconds: int = 86400) -> None:
        val_str = json.dumps(value)
        try:
            if settings.REDIS_URL:
                import redis.asyncio as aioredis
                client = aioredis.from_url(settings.redis_url, decode_responses=True)
                await client.set(key, val_str, ex=ttl_seconds)
                await client.aclose()
                return
        except Exception as e:
            logger.debug(f"[IdentityCache] Redis write skip ({e}), using memory fallback.")

        # In-memory fallback
        _MEMORY_CACHE[key] = (time.time() + ttl_seconds, val_str)
