from datetime import datetime, timedelta, timezone
from typing import Any
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from app.core.config import settings
from app.core.exceptions import UnauthorizedException

# Initialize modern Argon2id password hasher with specified parameters
ph = PasswordHasher(
    memory_cost=65536,  # 64 MB
    time_cost=3,        # 3 iterations
    parallelism=4       # 4 threads
)

def hash_password(password: str) -> str:
    """Argon2id password hashing."""
    return ph.hash(password)

def verify_password(hashed_password: str, plain_password: str) -> bool:
    """Verifies a plain password against an Argon2id hash."""
    try:
        return ph.verify(hashed_password, plain_password)
    except VerifyMismatchError:
        return False

def create_access_token(subject: str, org_id: str | None, role: str, jti: str, expires_delta: timedelta | None = None) -> str:
    """Generates a signed JWT Access Token (HS256)."""
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        
    claims = {
        "sub": subject,
        "org_id": org_id,
        "role": role,
        "jti": jti,
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp())
    }
    return jwt.encode(claims, settings.JWT_SECRET_KEY, algorithm="HS256")

def create_refresh_token(subject: str, jti: str, expires_delta: timedelta | None = None) -> str:
    """Generates a signed JWT Refresh Token (HS256)."""
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        
    claims = {
        "sub": subject,
        "jti": jti,
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp())
    }
    return jwt.encode(claims, settings.JWT_REFRESH_SECRET_KEY, algorithm="HS256")

def decode_token(token: str, secret_key: str) -> dict[str, Any]:
    """Decodes and validates a JWT token; raises UnauthorizedException on failure."""
    try:
        payload = jwt.decode(token, secret_key, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        raise UnauthorizedException(message="Token has expired.")
    except jwt.InvalidTokenError:
        raise UnauthorizedException(message="Token signature is invalid.")

def decode_access_token(token: str) -> dict[str, Any]:
    """Decodes access token claims using primary secret key."""
    return decode_token(token, settings.JWT_SECRET_KEY)

def decode_refresh_token(token: str) -> dict[str, Any]:
    """Decodes refresh token claims using secondary secret key."""
    return decode_token(token, settings.JWT_REFRESH_SECRET_KEY)
