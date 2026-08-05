from enum import Enum

class RoleEnum(str, Enum):
    SUPER_ADMIN = "SUPER_ADMIN"
    ORG_ADMIN = "ORG_ADMIN"
    INSPECTOR = "INSPECTOR"
    AUDITOR = "AUDITOR"

class OTPPurposeEnum(str, Enum):
    EMAIL_VERIFICATION = "EMAIL_VERIFICATION"
    PASSWORD_RESET = "PASSWORD_RESET"
    MFA = "MFA"

# Token expiry overrides if specified in settings
OTP_EXPIRY_MINUTES = 5
RESET_TOKEN_EXPIRY_MINUTES = 10
