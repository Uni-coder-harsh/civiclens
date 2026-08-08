from enum import Enum


class OrganizationRole(str, Enum):
    ADMIN = "ADMIN"
    MEMBER = "MEMBER"


class BillingPlan(str, Enum):
    FREE = "FREE"
    PRO = "PRO"
    ENTERPRISE = "ENTERPRISE"
