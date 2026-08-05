import uuid
from fastapi import APIRouter, Depends, status
from app.modules.ai.dependencies import get_ai_service
from app.modules.ai.schema import AIModelCreate, AIModelResponse, AnalysisSubmit, InferenceResponse
from app.modules.ai.service import AIService
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User


router = APIRouter(prefix="/prediction", tags=["AI Intelligence"])
inspector_only = RoleChecker([RoleEnum.INSPECTOR.value, RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])


@router.get("/models", response_model=list[AIModelResponse])
async def list_models(_: User = Depends(get_current_user), service: AIService = Depends(get_ai_service)):
    return await service.list_models()


@router.post("/models", status_code=status.HTTP_201_CREATED, response_model=AIModelResponse)
async def register_model(data: AIModelCreate, _: User = Depends(inspector_only), service: AIService = Depends(get_ai_service)):
    return await service.register_model(data)


@router.post("/predict", response_model=InferenceResponse)
async def submit_prediction(data: AnalysisSubmit, _: User = Depends(inspector_only), service: AIService = Depends(get_ai_service)):
    return await service.submit_analysis(data)


@router.get("/history", response_model=list[InferenceResponse])
async def prediction_history(media_id: uuid.UUID | None = None, _: User = Depends(get_current_user), service: AIService = Depends(get_ai_service)):
    return await service.history(media_id)
