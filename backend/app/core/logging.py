import logging
import os
import sys
from loguru import logger
from app.core.config import settings

def setup_logging():
    """
    Configures Loguru, intercepts standard library logging handlers (including Uvicorn logs),
    and formats log messages.
    """
    # Intercept default uvicorn handlers
    loggers = (
        "uvicorn",
        "uvicorn.access",
        "uvicorn.error",
        "fastapi"
    )
    
    # Configure Loguru output formats
    log_format = (
        "<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | "
        "<level>{level: <8}</level> | "
        "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> | "
        "<level>{message}</level>"
    )

    # Clear standard logging handlers
    logger.remove()
    
    # Add stdout handler
    logger.add(
        sys.stdout,
        format=log_format,
        level="DEBUG" if settings.DEBUG else "INFO",
        enqueue=True,
    )

    # If in production, log to a rotating log file as well
    if settings.ENVIRONMENT == "production":
        log_dir = "logs"
        os.makedirs(log_dir, exist_ok=True)
        logger.add(
            os.path.join(log_dir, "app.log"),
            rotation="20 MB",
            retention="14 days",
            compression="zip",
            format=log_format,
            level="INFO",
            enqueue=True,
        )

    # Class to intercept standard logging to Loguru sink
    class InterceptHandler(logging.Handler):
        def emit(self, record):
            try:
                level = logger.level(record.levelname).name
            except ValueError:
                level = record.levelno

            # Get frame where the logging occurred
            frame = sys._getframe(6)
            depth = 6
            while frame and frame.f_code.co_filename == logging.__file__:
                frame = frame.f_back
                depth += 1

            logger.opt(depth=depth, exception=record.exc_info).log(level, record.getMessage())

    # Apply global configurations
    logging.basicConfig(handlers=[InterceptHandler()], level=0, force=True)
    
    for name in loggers:
        logging_logger = logging.getLogger(name)
        logging_logger.handlers = [InterceptHandler()]
        logging_logger.propagate = False

    logger.info("Logging intercept successfully configured via Loguru.")
