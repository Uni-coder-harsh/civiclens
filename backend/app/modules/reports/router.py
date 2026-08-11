import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database import get_db_session
from app.modules.reports.repository import ReportsRepository
from app.modules.reports.schema import ReportCreate, ReportResponse
from app.modules.reports.service import ReportsService

router = APIRouter(prefix="/reports", tags=["Reports"])


def get_reports_service(db: AsyncSession = Depends(get_db_session)) -> ReportsService:
    return ReportsService(ReportsRepository(db))


@router.post("", status_code=status.HTTP_201_CREATED, response_model=ReportResponse)
async def submit_report(
    payload: str = Form(..., description="JSON-encoded ReportPayload from Flutter"),
    image: UploadFile | None = File(default=None),
    service: ReportsService = Depends(get_reports_service),
):
    """
    Accepts a citizen infrastructure defect report from the Flutter app.
    `payload` is a JSON string; `image` is an optional file upload.
    Supports both guest and registered users — no auth required.
    """
    try:
        payload_dict = json.loads(payload)
    except json.JSONDecodeError as e:
        logger.error(f"[Reports] ❌ Bad JSON in payload field: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid JSON payload: {e}")

    client_id = payload_dict.get("id", "unknown")
    category = payload_dict.get("category", "unknown")
    has_image = image is not None and image.filename

    logger.info(
        f"[Reports] 📥 Incoming report | client_id={client_id} "
        f"category={category} image={'yes' if has_image else 'no'}"
    )

    try:
        data = ReportCreate(**payload_dict)
    except Exception as e:
        logger.error(f"[Reports] ❌ Schema validation failed for client_id={client_id}: {e}")
        raise HTTPException(status_code=422, detail=str(e))

    return await service.submit_report(data, image)


@router.get("/{report_id}", response_model=ReportResponse)
async def get_report(
    report_id: str,
    service: ReportsService = Depends(get_reports_service),
):
    """Fetch a report by its server-side or client-side UUID."""
    if report_id in ["witness-nearby", "sync", "nearby", "timeline"]:
        raise HTTPException(status_code=404, detail="Specialized route, handled by integration service.")
    report = await service.repo.get_by_client_id(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return ReportsService._to_response(report)
