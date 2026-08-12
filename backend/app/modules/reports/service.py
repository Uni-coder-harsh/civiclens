import os
import uuid
import logging

from fastapi import HTTPException, UploadFile
from loguru import logger

from app.modules.reports.model import CivicReport
from app.modules.reports.repository import ReportsRepository
from app.modules.reports.schema import ReportCreate, ReportResponse
from app.modules.ai.severity import compute_severity, severity_to_readable

inference_logger = logging.getLogger("civiclens.reports.inference")


class ReportsService:
    def __init__(self, repo: ReportsRepository, inference_engine=None):
        self.repo = repo
        self.inference_engine = inference_engine

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

        # Read once for inference, then rewind so the existing storage uploader
        # receives the exact original file bytes.
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Image file is empty.")
        await image.seek(0)

        ai_result = self._analyse_image(image_bytes)
        address = await self._resolve_address(data.capture.latitude, data.capture.longitude)

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
        report = await self.repo.create(data, image_url, ai_result=ai_result)
        logger.info(
            f"[Reports] ✅ Report saved to Neon DB | "
            f"report_id={report.id} category={report.category} "
            f"severity={report.severity} lat={data.capture.latitude:.5f} "
            f"lng={data.capture.longitude:.5f} "
            f"image={image_url} "
            f"user_id={data.user_id} is_guest={data.is_guest}"
        )
        return self._to_response(report, address=address)

    def _analyse_image(self, image_bytes: bytes) -> dict | None:
        """Run the configured ONNX detector without rejecting a valid report on ML failure."""
        if self.inference_engine is None:
            inference_logger.warning("[Reports] ONNX engine unavailable; report saved without AI result")
            return None

        try:
            inference_logger.info("[Reports] ONNX inference started for uploaded report image")
            detection = self.inference_engine.detect(image_bytes)
            severity = compute_severity(
                detection["detections"],
                detection["image"]["width"],
                detection["image"]["height"],
            )
            detection["severity"] = severity
            inference_logger.info(
                "[Reports] ONNX inference completed detections=%s severity=%s confidence=%s total_ms=%s",
                detection["detection_count"],
                severity["severity_label"],
                severity["primary_confidence"],
                detection["timing_ms"]["total"],
            )
            return {
                "ai_confidence": severity["primary_confidence"],
                "ai_label": severity_to_readable(
                    severity["primary_class"], severity["primary_confidence"]
                ),
                "ai_severity": severity["severity_label"],
                "ai_detections": detection,
            }
        except Exception as exc:
            # Storage and civic reporting remain available if model hosting/runtime
            # is temporarily unavailable. The absence of AI fields is explicit.
            inference_logger.exception("[Reports] ONNX inference failed: %s", exc)
            return None

    async def _resolve_address(self, latitude: float, longitude: float) -> str | None:
        """Resolve captured coordinates to a real place name via the existing OSM provider."""
        try:
            from app.modules.infrastructure_identity.providers import registry

            location = await registry.reverse_geocode(latitude, longitude)
            return location.get("address") if location else None
        except Exception as exc:
            inference_logger.warning("[Reports] Reverse geocoding failed: %s", exc)
            return None

    async def _upload_image(self, image: UploadFile, report_id: str) -> str | None:
        """
        Uploads image directly to Supabase Storage.
        Automatically creates the storage bucket if it does not exist.
        Returns the authentic public URL if upload succeeds, or None if it fails.
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

            # ── Automatic Bucket Creation / Ensure Bucket Exists ─────────────
            self._ensure_bucket_exists(client, bucket)

            # ── Upload File to Bucket ─────────────────────────────────────────
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
            # If upload failed due to bucket missing on first try, attempt explicit bucket creation and retry
            if "Bucket not found" in str(e) or "404" in str(e):
                try:
                    logger.info(f"[Reports] 📦 Attempting bucket creation retry for '{bucket}'...")
                    client.storage.create_bucket(bucket, options={"public": True})
                    client.storage.from_(bucket).upload(
                        path=path,
                        file=content,
                        file_options={"content-type": image.content_type or "image/jpeg"},
                    )
                    public_url = client.storage.from_(bucket).get_public_url(path)
                    logger.info(
                        f"[Reports] ☁️ Image uploaded to Supabase Storage after auto bucket creation | "
                        f"report_id={report_id} url={public_url}"
                    )
                    return public_url
                except Exception as retry_err:
                    logger.error(
                        f"[Reports] ❌ Retry bucket creation and upload failed | "
                        f"report_id={report_id} error={retry_err}"
                    )
                    return None

            logger.error(
                f"[Reports] ❌ Supabase cloud storage upload failed | "
                f"report_id={report_id} url={supabase_url} error={e}"
            )
            return None

    @staticmethod
    def _ensure_bucket_exists(client, bucket_name: str) -> None:
        """Attempts to create the public Supabase storage bucket if it does not already exist."""
        try:
            client.storage.create_bucket(bucket_name, options={"public": True})
            logger.info(f"[Reports] 📦 Automatically created public Supabase bucket '{bucket_name}'")
        except Exception:
            # Bucket already exists or user doesn't have create_bucket perms (will handle in upload)
            pass

    @staticmethod
    def _to_response(report: CivicReport, address: str | None = None) -> ReportResponse:
        return ReportResponse(
            report_id=str(report.id),
            status=report.status,
            ai_confidence=report.ai_confidence,
            ai_label=report.ai_label,
            ai_severity=report.ai_severity,
            ai_detections=report.ai_detections,
            address=address,
            assigned_contractor_id=report.contractor_id,
            civic_score_delta=report.civic_score_delta,
            created_at_utc=report.created_at,
            sla_clock=None,
        )
