from typing import Any

class BaseAppException(Exception):
    """Base exception class for all custom application errors."""
    def __init__(self, error_code: str, message: str, status_code: int = 400, details: Any = None):
        super().__init__(message)
        self.error_code = error_code
        self.message = message
        self.status_code = status_code
        self.details = details

class ResourceNotFoundException(BaseAppException):
    """Raised when a requested database record or entity is not found."""
    def __init__(self, message: str = "Resource not found.", details: Any = None):
        super().__init__(
            error_code="RESOURCE_NOT_FOUND",
            message=message,
            status_code=404,
            details=details
        )

class ConflictException(BaseAppException):
    """Raised when a unique constraint, duplicate value, or logical collision occurs."""
    def __init__(self, message: str = "A resource conflict occurred.", details: Any = None):
        super().__init__(
            error_code="CONFLICT_ERROR",
            message=message,
            status_code=409,
            details=details
        )

class UnauthorizedException(BaseAppException):
    """Raised when authentication credentials are missing, expired, or invalid."""
    def __init__(self, message: str = "Unauthorized access.", details: Any = None):
        super().__init__(
            error_code="UNAUTHORIZED",
            message=message,
            status_code=411 if "expired" in message.lower() else 401, # Mapped specifically
            details=details
        )

class ForbiddenException(BaseAppException):
    """Raised when an authenticated user lacks role clearance permissions."""
    def __init__(self, message: str = "Forbidden access.", details: Any = None):
        super().__init__(
            error_code="FORBIDDEN_ACCESS",
            message=message,
            status_code=403,
            details=details
        )

class ValidationException(BaseAppException):
    """Raised when data validations fail (business rules or schemas)."""
    def __init__(self, message: str = "Validation failed.", details: Any = None):
        super().__init__(
            error_code="VALIDATION_ERROR",
            message=message,
            status_code=422,
            details=details
        )
