import json
from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field


class GeoCapture(BaseModel):
    latitude: float
    longitude: float
    altitude_m: float = 0.0
    accuracy_m: float = 0.0
    bearing_deg: float = 0.0
    speed_mps: float = 0.0
    captured_at: datetime | None = None


class ReportCreate(BaseModel):
    """Matches the JSON structure sent inside the Flutter multipart `payload` field."""
    id: str = Field(..., description="UUID from the Flutter client")
    user_id: str
    category: str
    severity: str
    description: str | None = None
    capture: GeoCapture
    quality_gate: str = "ok"
    is_guest: bool = False
    contractor_id: str | None = None
    infrastructure_id: str | None = None
    sensor_data: str | dict | None = None  # Flutter sends it as JSON string

    def parsed_sensor_data(self) -> dict | None:
        if self.sensor_data is None:
            return None
        if isinstance(self.sensor_data, dict):
            return self.sensor_data
        try:
            return json.loads(self.sensor_data)
        except (ValueError, TypeError):
            return None


class ReportResponse(BaseModel):
    report_id: str
    status: str
    ai_confidence: float | None = None
    ai_label: str | None = None
    assigned_contractor_id: str | None = None
    civic_score_delta: int = 10
    created_at_utc: datetime
    sla_clock: Any | None = None

    class Config:
        from_attributes = True
