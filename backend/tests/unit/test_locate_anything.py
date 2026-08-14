import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch
from decimal import Decimal

from app.core.config import settings
from app.modules.ai.service import AIService
from app.modules.ai.locate_anything_client import LocateAnythingClient
from app.modules.ai.schema import DetectionResult

@pytest.mark.asyncio
async def test_locate_anything_client_detect():
    """Test that LocateAnythingClient correctly parses mock remote GPU server response."""
    mock_response = {
        "status": "completed",
        "model": {
            "name": "LocateAnything-3B",
            "version": "nvidia/LocateAnything-3B",
            "runtime": "transformers",
            "provider": "cuda"
        },
        "image": {
            "width": 800,
            "height": 457
        },
        "detections": [
            {
                "label": "crack",
                "bounding_box": {
                    "x1": 100,
                    "y1": 200,
                    "x2": 300,
                    "y2": 400,
                    "width": 200,
                    "height": 200
                },
                "grounding_score": 0.85
            }
        ],
        "detection_count": 1,
        "timing_ms": {
            "preprocess": 10.5,
            "inference": 120.0,
            "postprocess": 5.2,
            "total": 135.7
        }
    }

    # Mock the HTTP response from the Lightning serve backend
    with patch("httpx.AsyncClient.post") as mock_post:
        mock_post.return_value = MagicMock(
            status_code=200,
            json=lambda: mock_response,
            raise_for_status=lambda: None
        )

        client = LocateAnythingClient(
            base_url="https://mock-lightning.ai:8000",
            secret="test-secret",
            timeout=60
        )
        
        result = await client.detect_and_normalize(
            image_bytes=b"dummy_bytes",
            filename="test.jpg",
            inspection_mode="road"
        )

        assert isinstance(result, DetectionResult)
        assert result.status == "completed"
        assert result.detection_count == 1
        assert result.detections[0].class_name == "crack"
        assert result.detections[0].confidence == 0.85
        assert result.detections[0].bounding_box.x1 == 100
        assert result.detections[0].bounding_box.x2 == 300

@pytest.mark.asyncio
async def test_ai_service_routes_to_locate_anything():
    """Test that AIService properly routes to LocateAnything provider and persists to DB."""
    mock_db = MagicMock()
    mock_model_repo = MagicMock()
    mock_inference_repo = MagicMock()
    mock_prediction_repo = MagicMock()

    mock_model_repo.list = AsyncMock(return_value=[])
    mock_model_repo.create = AsyncMock(return_value=MagicMock(id=uuid.uuid4()))
    mock_inference_repo.create = AsyncMock()
    mock_prediction_repo.create = AsyncMock()

    service = AIService(
        model_repo=mock_model_repo,
        inference_repo=mock_inference_repo,
        prediction_repo=mock_prediction_repo
    )

    mock_client_result = DetectionResult(
        status="completed",
        model={
            "name": "LocateAnything-3B",
            "version": "nvidia/LocateAnything-3B",
            "runtime": "transformers",
            "provider": "cuda"
        },
        image={"width": 800, "height": 457},
        detections=[
            {
                "class_id": 0,
                "class_name": "crack",
                "confidence": 0.85,
                "bounding_box": {
                    "x1": 100,
                    "y1": 200,
                    "x2": 300,
                    "y2": 400,
                    "width": 200,
                    "height": 200
                }
            }
        ],
        detection_count=1,
        timing_ms={
            "preprocess": 10.5,
            "inference": 120.0,
            "postprocess": 5.2,
            "total": 135.7
        }
    )

    # Force provider settings to locateanything
    with patch.object(settings, "AI_PROVIDER", "locateanything"), \
         patch.object(settings, "LA_INFERENCE_URL", "https://mock-lightning.ai:8000"), \
         patch("app.modules.ai.locate_anything_client.LocateAnythingClient.detect_and_normalize", new_callable=AsyncMock) as mock_detect:
        
        mock_detect.return_value = mock_client_result

        result = await service.run_detection(
            engine=None,
            image_data=b"dummy_bytes",
            media_id=uuid.uuid4(),
            inspection_mode="road"
        )

        # Assert client was called
        mock_detect.assert_called_once()
        assert result.status == "completed"
        assert result.severity is not None
        assert result.severity.severity_label == "medium"  # derived by compute_severity

        # Verify database insertion attempts happened
        mock_model_repo.create.assert_called_once()
        mock_inference_repo.create.assert_called_once()
        mock_prediction_repo.create.assert_called_once()
