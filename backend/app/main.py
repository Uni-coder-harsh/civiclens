import time
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.core.exceptions import BaseAppException
from app.core.limiter import limiter
from app.core.logging import logger, setup_logging
from app.infrastructure.database import async_engine
from app.modules.auth.router import router as auth_router
from app.modules.organizations.router import router as organizations_router
from app.modules.infrastructure.router import router as infrastructure_router
from app.modules.passport.router import router as passport_router
from app.modules.inspections.router import router as inspections_router
from app.modules.ai.router import router as ai_router
from app.modules.severity.router import router as severity_router
from app.modules.notifications.router import router as notifications_router
from app.modules.analytics.router import router as analytics_router
from app.modules.integration.router import router as integration_router
from app.modules.reports.router import router as reports_router

# Import ORM models so SQLAlchemy metadata and string relationships are registered.
from app.modules.auth import model as auth_models  # noqa: F401
from app.modules.organizations import model as organization_models  # noqa: F401
from app.modules.infrastructure import model as infrastructure_models  # noqa: F401
from app.modules.passport import model as passport_models  # noqa: F401
from app.modules.inspections import model as inspection_models  # noqa: F401
from app.modules.ai import model as ai_models  # noqa: F401
from app.modules.severity import model as severity_models  # noqa: F401
from app.modules.notifications import model as notification_models  # noqa: F401
from app.modules.analytics import model as analytics_models  # noqa: F401
from app.modules.system import model as system_models  # noqa: F401
from app.modules.reports import model as report_models  # noqa: F401

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handles application startup and shutdown lifecycles.
    Sets up logging, verifies database pools, and establishes cache engines.
    """
    # 1. Initialize logging interceptors
    setup_logging()
    logger.info("Starting up CivicLens Monolith Backend...")
    
    # 2. Verify PostgreSQL + PostGIS pool check-out
    try:
        from sqlalchemy import text
        async with async_engine.connect() as conn:
            # Query PostGIS version to verify extension functionality
            result = await conn.execute(text("SELECT PostGIS_Full_Version();"))
            version_info = result.scalar()
            logger.info(f"PostgreSQL + PostGIS Connection verified successfully: {version_info}")
    except Exception as e:
        logger.error(f"Failed to connect to PostgreSQL/PostGIS during boot: {e}")
        
    yield
    
    # 3. Clean up database pool on shutdown
    logger.info("Cleaning up database connections...")
    await async_engine.dispose()
    logger.info("Shutdown completed successfully.")

# Create FastAPI instance
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="CivicLens AI-powered Infrastructure Intelligence Platform REST API Engine.",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# Bind SlowAPI limiter state and rate limit exceeded handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Middleware Binding
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

api_prefix = "/api/v1"
app.include_router(auth_router, prefix=api_prefix)
app.include_router(organizations_router, prefix=api_prefix)
app.include_router(infrastructure_router, prefix=api_prefix)
app.include_router(passport_router, prefix=api_prefix)
app.include_router(inspections_router, prefix=api_prefix)
app.include_router(ai_router, prefix=api_prefix)
app.include_router(severity_router, prefix=api_prefix)
app.include_router(notifications_router, prefix=api_prefix)
app.include_router(analytics_router, prefix=api_prefix)
app.include_router(integration_router)
app.include_router(reports_router, prefix=api_prefix)

# Mount local static file storage for fallback image serving
import os
from fastapi.staticfiles import StaticFiles
storage_dir = os.environ.get("LOCAL_STORAGE_DIR", "/tmp/civiclens_uploads")
os.makedirs(storage_dir, exist_ok=True)
app.mount("/static/uploads", StaticFiles(directory=storage_dir), name="static_uploads")

@app.get("/", include_in_schema=False)
async def root_redirect():
    return RedirectResponse(url="/docs")

# Custom Middleware: Request Tracking & Security Headers
@app.middleware("http")
async def process_request_observability_pipeline(request: Request, call_next) -> Response:
    """
    Orchestrates the HTTP request/response middleware pipeline:
    1. Correlation ID generation & tracing.
    2. Execution response measurement.
    3. Security Headers injection.
    """
    # 1. Trace incoming request IDs
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    request.state.request_id = request_id
    
    # Bind request id context to Loguru context logs
    with logger.contextualize(request_id=request_id):
        start_time = time.perf_counter()
        
        try:
            response: Response = await call_next(request)
        except Exception as e:
            logger.exception("Unhandled application crash captured in middleware.")
            response = JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "error_code": "INTERNAL_SERVER_ERROR",
                    "message": "An unexpected error occurred. Please contact system administrators.",
                    "request_id": request_id,
                    "details": str(e) if settings.DEBUG else None
                }
            )
            
        duration_ms = (time.perf_counter() - start_time) * 1000.0
        
        # 2. Log structured access details
        logger.info(
            f"{request.client.host if request.client else 'unknown'} - "
            f"\"{request.method} {request.url.path}\" "
            f"{response.status_code} - {duration_ms:.2f}ms"
        )
        
        # 3. Inject secure configuration headers
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        # Relax Content-Security-Policy for docs assets to load from external CDNs
        if request.url.path in ("/docs", "/redoc", "/openapi.json"):
            response.headers["Content-Security-Policy"] = (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "img-src 'self' data: https://fastapi.tiangolo.com; "
                "frame-ancestors 'none'"
            )
        else:
            response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'"
        response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains; preload"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        
        return response

# ==========================================
# Exception Handlers Registration
# ==========================================

@app.exception_handler(BaseAppException)
async def custom_app_exception_handler(request: Request, exc: BaseAppException):
    """Intercepts custom application exceptions and formats standard JSON error payloads."""
    request_id = getattr(request.state, "request_id", "unknown")
    logger.warning(f"App exception [{exc.error_code}]: {exc.message} (Request ID: {request_id})")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error_code": exc.error_code,
            "message": exc.message,
            "request_id": request_id,
            "details": exc.details
        }
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Intercepts Pydantic validation errors, stripping raw trace logs for user-facing schemas."""
    request_id = getattr(request.state, "request_id", "unknown")
    errors_summary = [
        {"field": ".".join(map(str, err["loc"][1:])), "message": err["msg"], "type": err["type"]}
        for err in exc.errors()
    ]
    logger.bind(errors=errors_summary).warning(f"Schema validation failed (Request ID: {request_id})")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error_code": "VALIDATION_ERROR",
            "message": "Input validation failed on incoming request payload.",
            "request_id": request_id,
            "details": errors_summary
        }
    )

# ==========================================
# System Base Endpoints
# ==========================================

@app.get("/api/v1/system/health", status_code=status.HTTP_200_OK, tags=["System"])
async def system_health_check(request: Request):
    """Reads Postgres + PostGIS status and returns live diagnostics report."""
    request_id = getattr(request.state, "request_id", "unknown")
    db_status = "healthy"
    
    try:
        from sqlalchemy import text
        async with async_engine.connect() as conn:
            await conn.execute(text("SELECT 1;"))
    except Exception as e:
        db_status = f"unhealthy: {e}"
        
    status_code = status.HTTP_200_OK if "unhealthy" not in db_status else status.HTTP_503_SERVICE_UNAVAILABLE
    
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "up" if status_code == 200 else "down",
            "request_id": request_id,
            "components": {
                "database": db_status,
                "api": "healthy"
            }
        }
    )
