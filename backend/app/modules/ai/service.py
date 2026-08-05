import uuid
from app.modules.ai.model import AIInferenceLog, AIModel, AIPrediction
from app.modules.ai.repository import AIInferenceRepository, AIModelRepository, AIPredictionRepository
from app.modules.ai.schema import AIModelCreate, AnalysisSubmit


class AIService:
    def __init__(self, model_repo: AIModelRepository, inference_repo: AIInferenceRepository, prediction_repo: AIPredictionRepository):
        self.model_repo = model_repo
        self.inference_repo = inference_repo
        self.prediction_repo = prediction_repo

    async def list_models(self) -> list[AIModel]:
        return list(await self.model_repo.list())

    async def register_model(self, data: AIModelCreate) -> AIModel:
        return await self.model_repo.create(AIModel(**data.model_dump()))

    async def submit_analysis(self, data: AnalysisSubmit) -> AIInferenceLog:
        log = AIInferenceLog(
            model_id=data.model_id,
            media_id=data.media_id,
            inference_duration_ms=data.inference_duration_ms,
            status="SUCCESS",
        )
        await self.inference_repo.create(log)
        for item in data.predictions:
            bbox = item.bounding_box
            prediction = AIPrediction(
                inference_log_id=log.id,
                class_name=item.class_name,
                confidence=item.confidence,
                bbox_x_center=bbox.x_center,
                bbox_y_center=bbox.y_center,
                bbox_width=bbox.width,
                bbox_height=bbox.height,
            )
            await self.prediction_repo.create(prediction)
        return log

    async def history(self, media_id: uuid.UUID | None = None) -> list[AIInferenceLog]:
        if media_id:
            return await self.inference_repo.list_by_media(media_id)
        return list(await self.inference_repo.list())
