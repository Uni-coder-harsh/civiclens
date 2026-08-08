import uuid
from decimal import Decimal
from app.core.exceptions import ResourceNotFoundException
from app.modules.inspections.repository import InspectionItemRepository
from app.modules.severity.model import AutomatedAssessment, SeverityRule
from app.modules.severity.repository import AssessmentRepository, SeverityRuleRepository
from app.modules.severity.schema import SeverityAssessmentRequest, SeverityOverride, SeverityRuleCreate


class SeverityService:
    def __init__(self, rule_repo: SeverityRuleRepository, assessment_repo: AssessmentRepository, item_repo: InspectionItemRepository):
        self.rule_repo = rule_repo
        self.assessment_repo = assessment_repo
        self.item_repo = item_repo

    async def list_rules(self) -> list[SeverityRule]:
        return list(await self.rule_repo.list())

    async def create_rule(self, data: SeverityRuleCreate) -> SeverityRule:
        return await self.rule_repo.create(
            SeverityRule(
                class_name=data.class_name,
                parameter_name=data.parameter_name,
                operator=data.operator,
                threshold_value=data.threshold_value,
                assigned_severity=data.assigned_severity.value,
            )
        )

    async def assess(self, item_id: uuid.UUID, data: SeverityAssessmentRequest) -> AutomatedAssessment:
        item = await self.item_repo.get_by_id(item_id)
        if not item:
            raise ResourceNotFoundException(message="Inspection item not found.")
        score = Decimal(data.confidence * 100).quantize(Decimal("0.01"))
        severity = "SEVERE" if score >= 85 else "MODERATE" if score >= 60 else "MINOR"
        assessment = await self.assessment_repo.get_by_item(item_id)
        if not assessment:
            assessment = AutomatedAssessment(inspection_item_id=item_id, calculated_severity=severity, priority_score=score)
        assessment.calculated_severity = severity
        assessment.priority_score = score
        assessment.reasoning_details = f"{data.class_name} confidence {data.confidence} mapped to {severity}"
        item.detected_severity = severity
        await self.item_repo.update(item)
        return await self.assessment_repo.update(assessment)

    async def override(self, item_id: uuid.UUID, data: SeverityOverride) -> AutomatedAssessment:
        item = await self.item_repo.get_by_id(item_id)
        if not item:
            raise ResourceNotFoundException(message="Inspection item not found.")
        item.assigned_severity = data.assigned_severity.value
        await self.item_repo.update(item)
        assessment = await self.assessment_repo.get_by_item(item_id)
        if not assessment:
            assessment = AutomatedAssessment(
                inspection_item_id=item_id,
                calculated_severity=data.assigned_severity.value,
                priority_score=Decimal("100.00"),
                reasoning_details="Manual override",
            )
        assessment.calculated_severity = data.assigned_severity.value
        assessment.reasoning_details = "Manual override"
        return await self.assessment_repo.update(assessment)
