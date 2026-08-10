import os
import uuid

from fastapi import HTTPException, UploadFile
from loguru import logger

from app.modules.reports.model import CivicReport
from app.modules.reports.repository import ReportsRepository
from app.modules.reports.schema import ReportCreate, ReportResponse


class ReportsService:
    def __init__(self, repo: ReportsRepository):
        self.repo = repo

    async def submit_report(
        self,
        data: ReportCreate,
        image: UploadFile | None,
    ) -> ReportResponse:
        # ── Idempotency: same client UUID already submitted ───────────────────
        existing = await self.repo.get_by_client_id(data.id)
        if existing:
            logger.info(
                "[Reports] ⏭  Duplicate submission — returning existing report | "
                f"report_id={existing.id} client_id={data.id} category={data.category}"
            )
            return self._to_response(existing)

        # ── MANDATORY Image Validation & Upload ────────────────────────────────
        if not image or not image.filename:
            logger.error(
                f"[Reports] ❌ Image missing for client_id={data.id}. Image is mandatory for report submission."
            )
            raise HTTPException(
                status_code=400,
                detail="Image file is mandatory for report submission."
            )

        logger.info(
            f"[Reports] 📷 Uploading mandatory image for client_id={data.id} "
            f"filename={image.filename} content_type={image.content_type}"
        )

        image_url = await self._upload_image(image, data.id)
        if not image_url:
            logger.error(
                f"[Reports] ❌ Supabase cloud image upload failed for client_id={data.id}. "
                "Rejecting report creation so DB receives only valid cloud image URLs."
            )
            raise HTTPException(
                status_code=500,
                detail="Cloud image storage upload failed. Report submission rejected."
            )

        # ── Persist report to DB ─────────────────────────────────────────────
        report = await self.repo.create(data, image_url)
        logger.info(
            f"[Reports] ✅ Report saved to Neon DB | "
            f"report_id={report.id} category={report.category} "
            f"severity={report.severity} lat={data.capture.latitude:.5f} "
            f"lng={data.capture.longitude:.5f} "
            f"image={image_url} "
            f"user_id={data.user_id} is_guest={data.is_guest}"
        )
        return self._to_response(report)

    async def _upload_image(self, image: UploadFile, report_id: str) -> str | None:
        """
        Uploads image directly to Supabase Storage.
        Returns the authentic public URL if upload succeeds, or None if it fails.
        No dummy or temporary URLs are generated.
        """
        content = await image.read()
        if not content:
            logger.error(f"[Reports] ❌ Empty image file provided for report_id={report_id}")
            return None

        raw_url = os.environ.get("SUPABASE_URL", "").strip()
        supabase_key = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()

        if not raw_url or not supabase_key:
            logger.error(
                "[Reports] ❌ SUPABASE_URL or SUPABASE_SERVICE_KEY environment variables are missing."
            )
            return None

        # Sanitize SUPABASE_URL if set to S3 endpoint or storage URL
        supabase_url = raw_url
        if "/storage/v1" in supabase_url:
            supabase_url = supabase_url.split("/storage/v1")[0]
        supabase_url = supabase_url.replace("storage.supabase.co", "supabase.co").rstrip("/")

        try:
            from supabase import create_client  # type: ignore

            client = create_client(supabase_url, supabase_key)
            bucket = os.environ.get("SUPABASE_BUCKET", "civiclens_storage")
            ext = (image.filename or "img.jpg").rsplit(".", 1)[-1].lower() or "jpg"
            path = f"reports/{report_id}/{uuid.uuid4()}.{ext}"

            client.storage.from_(bucket).upload(
                path=path,
                file=content,
                file_options={"content-type": image.content_type or "image/jpeg"},
            )
            public_url = client.storage.from_(bucket).get_public_url(path)
            logger.info(
                f"[Reports] ☁️ Image uploaded to Supabase Storage | "
                f"report_id={report_id} bucket={bucket} path={path} "
                f"size={len(content)} bytes url={public_url}"
            )
            return public_url
        except Exception as e:
            logger.error(
                f"[Reports] ❌ Supabase cloud storage upload failed | "
                f"report_id={report_id} url={supabase_url} error={e}"
            )
            return None

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
