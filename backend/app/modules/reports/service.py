import logging
import os
import uuid

from fastapi import UploadFile

from app.modules.reports.model import CivicReport
from app.modules.reports.repository import ReportsRepository
from app.modules.reports.schema import ReportCreate, ReportResponse

logger = logging.getLogger(__name__)


class ReportsService:
    def __init__(self, repo: ReportsRepository):
        self.repo = repo

    async def submit_report(
        self,
        data: ReportCreate,
        image: UploadFile | None,
    ) -> ReportResponse:
        # Check for duplicate (idempotent: same client UUID submitted twice)
        existing = await self.repo.get_by_client_id(data.id)
        if existing:
            logger.info(f"[Reports] Duplicate submission for client_id={data.id}. Returning existing.")
            return self._to_response(existing)

        # Upload image to Supabase Storage if provided
        image_url: str | None = None
        if image and image.filename:
            image_url = await self._upload_image(image, data.id)

        report = await self.repo.create(data, image_url)
        return self._to_response(report)

    async def _upload_image(self, image: UploadFile, report_id: str) -> str | None:
        """Upload image bytes to Supabase S3-compatible storage. Returns public URL."""
        try:
            from supabase import create_client  # type: ignore

            supabase_url = os.environ.get("SUPABASE_URL", "")
            supabase_key = os.environ.get("SUPABASE_SERVICE_KEY", "")

            if not supabase_url or not supabase_key:
                logger.warning("[Reports] Supabase env vars not set — skipping image upload.")
                return None

            client = create_client(supabase_url, supabase_key)
            bucket = os.environ.get("SUPABASE_BUCKET", "civiclens_storage")
            ext = (image.filename or "img").rsplit(".", 1)[-1]
            path = f"reports/{report_id}/{uuid.uuid4()}.{ext}"

            content = await image.read()
            client.storage.from_(bucket).upload(
                path=path,
                file=content,
                file_options={"content-type": image.content_type or "image/jpeg"},
            )
            public_url = client.storage.from_(bucket).get_public_url(path)
            logger.info(f"[Reports] Image uploaded to Supabase: {public_url}")
            return public_url
        except Exception as e:
            logger.warning(f"[Reports] Image upload failed (non-fatal): {e}")
            return None  # Non-fatal; report still saved without image

    @staticmethod
    def _to_response(report: CivicReport) -> ReportResponse:
        return ReportResponse(
            report_id=str(report.id),
            status=report.status,
            ai_confidence=report.ai_confidence,
            ai_label=report.ai_label,
            assigned_contractor_id=report.contractor_id,
            civic_score_delta=report.civic_score_delta,
            created_at_utc=report.created_at,
            sla_clock=None,
        )
