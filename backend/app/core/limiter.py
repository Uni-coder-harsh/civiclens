from slowapi import Limiter
from slowapi.util import get_remote_address
from app.core.config import settings

# Global SlowAPI Rate Limiter pointing to our Redis container instances
limiter = Limiter(
    key_func=get_remote_address,
    enabled=settings.RATE_LIMIT_ENABLED,
    storage_uri=settings.redis_url if settings.RATE_LIMIT_ENABLED else "memory://"
)
