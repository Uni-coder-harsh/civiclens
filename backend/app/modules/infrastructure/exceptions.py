from app.core.exceptions import BaseAppException


class AssetNotFoundException(BaseAppException):
    def __init__(self, message: str = "Infrastructure asset not found."):
        super().__init__("ASSET_NOT_FOUND", message, 404)
