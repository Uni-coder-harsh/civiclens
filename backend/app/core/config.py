import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "CivicLens"
    DEBUG: bool = True

    # Security Configs
    JWT_SECRET_KEY: str = "9ca1029b8a3d4c3eb2d918b2c9a103019ca1029b8a3d4c3eb2d918b2c9a10301"
    JWT_REFRESH_SECRET_KEY: str = "8fa1119b6e3e436fb1e878b1d9a243018fa1119b6e3e436fb1e878b1d9a24301"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Database Configuration
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "postgres"
    DB_NAME: str = "civiclens"
    DB_HOST: str = "db"
    DB_PORT: int = 5432

    # Redis Cache Configuration
    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0

    # Object Storage Configuration
    MINIO_ENDPOINT: str = "minio:9000"
    MINIO_ROOT_USER: str = "admin"
    MINIO_ROOT_PASSWORD: str = "supersecretpassword"
    MINIO_SECURE: bool = False
    MINIO_BUCKET_NAME: str = "civiclens-assets"

    # Direct Connection Strings (Neon / Upstash fallback)
    DATABASE_URL: str | None = None
    REDIS_URL: str | None = None

    # Email Service (Resend)
    RESEND_API_KEY: str | None = None
    RESEND_FROM_EMAIL: str = "noreply@civiclens.com"

    # CORS Configs
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000"

    # Rate Limiter
    RATE_LIMIT_ENABLED: bool = True

    @property
    def database_url(self) -> str:
        """Constructs or returns the asynchronous PostgreSQL connection URL."""
        if self.DATABASE_URL:
            url = self.DATABASE_URL
            if url.startswith("postgres://"):
                url = url.replace("postgres://", "postgresql+asyncpg://", 1)
            elif url.startswith("postgresql://"):
                url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
            
            # Clean up query string params for asyncpg compatibility
            from urllib.parse import urlparse, parse_qsl, urlencode, urlunparse
            parsed = urlparse(url)
            query_params = parse_qsl(parsed.query)
            
            filtered_params = []
            for k, v in query_params:
                if k == "sslmode":
                    # Convert sslmode to ssl
                    if v in ("require", "verify-ca", "verify-full"):
                        filtered_params.append(("ssl", "require"))
                elif k in ("ssl", "timeout", "command_timeout"):
                    filtered_params.append((k, v))
                # Explicitly drop unsupported parameters like channel_binding
            
            new_query = urlencode(filtered_params)
            parsed = parsed._replace(query=new_query)
            return urlunparse(parsed)
        return f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    @property
    def redis_url(self) -> str:
        """Constructs or returns the Redis connection URL."""
        if self.REDIS_URL:
            return self.REDIS_URL
        return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"

    @property
    def cors_origins_list(self) -> list[str]:
        """Parses the comma-separated origins string into a Python list."""
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

settings = Settings()
