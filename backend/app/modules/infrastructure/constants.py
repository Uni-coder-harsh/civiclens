from enum import Enum


class AssetType(str, Enum):
    ROAD = "ROAD"
    BRIDGE = "BRIDGE"


class AssetStatus(str, Enum):
    EXCELLENT = "EXCELLENT"
    GOOD = "GOOD"
    FAIR = "FAIR"
    POOR = "POOR"
    CRITICAL = "CRITICAL"
