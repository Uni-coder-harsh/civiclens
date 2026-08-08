from app.core.exceptions import BaseAppException


class OrganizationNotFoundException(BaseAppException):
    def __init__(self, message: str = "Organization not found."):
        super().__init__("ORGANIZATION_NOT_FOUND", message, 404)


class MembershipNotFoundException(BaseAppException):
    def __init__(self, message: str = "Organization membership not found."):
        super().__init__("MEMBERSHIP_NOT_FOUND", message, 404)
