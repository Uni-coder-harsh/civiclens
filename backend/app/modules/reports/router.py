import json
import logging

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database import get_db_session
from app.modules.reports.repository import ReportsRepository
from app.modules.reports.schema import ReportCreate, ReportResponse
from app.modules.reports.service import ReportsService

logger = logging.getLogger(__name__)

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
    The `payload` field is a JSON string and `image` is an optional file upload.
    No auth required — supports both guest and registered users.
    """
    try:
        payload_dict = json.loads(payload)
    except json.JSONDecodeError as e:
        logger.error(f"[Reports] Invalid JSON payload: {e}")
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=f"Invalid JSON payload: {e}")

    logger.info(f"[Reports] Received report submission: id={payload_dict.get('id')} category={payload_dict.get('category')}")

    data = ReportCreate(**payload_dict)
    return await service.submit_report(data, image)


@router.get("/{report_id}", response_model=ReportResponse)
async def get_report(
    report_id: str,
    service: ReportsService = Depends(get_reports_service),
):
    """Fetch a report by its server-side UUID."""
    from fastapi import HTTPException
    repo = service.repo
    report = await repo.get_by_client_id(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return ReportsService._to_response(report)
