from app.core.exceptions import BaseAppException

class InvalidCredentialsException(BaseAppException):
    def __init__(self, message: str = "Invalid email or password."):
        super().__init__(
            error_code="INVALID_CREDENTIALS",
            message=message,
            status_code=401
        )

class EmailAlreadyExistsException(BaseAppException):
    def __init__(self, message: str = "Email is already registered."):
        super().__init__(
            error_code="EMAIL_ALREADY_EXISTS",
            message=message,
            status_code=409
        )

class SessionExpiredException(BaseAppException):
    def __init__(self, message: str = "Active session has expired or is invalid."):
        super().__init__(
            error_code="SESSION_EXPIRED",
            message=message,
            status_code=401
        )

class InvalidOTPException(BaseAppException):
    def __init__(self, message: str = "Invalid verification code."):
        super().__init__(
            error_code="INVALID_OTP",
            message=message,
            status_code=400
        )

class OTPExpiredException(BaseAppException):
    def __init__(self, message: str = "Verification code has expired."):
        super().__init__(
            error_code="OTP_EXPIRED",
            message=message,
            status_code=400
        )

class RoleNotFoundException(BaseAppException):
    def __init__(self, message: str = "Security clearance role not found."):
        super().__init__(
            error_code="ROLE_NOT_FOUND",
            message=message,
            status_code=404
        )
