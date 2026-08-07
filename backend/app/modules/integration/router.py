import uuid
import math
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Query, status, HTTPException
from pydantic import BaseModel, Field
from app.modules.integration.store import store

router = APIRouter(prefix="/v1", tags=["Flutter Integration"])

# =====================================================================
# Pydantic Schemas
# =====================================================================

class GeoCaptureSchema(BaseModel):
    latitude: float
    longitude: float
    altitude_m: float
    accuracy_m: float
    bearing_deg: float
    speed_mps: float
    captured_at: str

class ReportPayloadSchema(BaseModel):
    id: str
    user_id: str
    category: str
    severity: str
    description: str
    capture: GeoCaptureSchema
    quality_gate: str
    is_guest: bool
    contractor_id: Optional[str] = None
    infrastructure_id: Optional[str] = None

class SlaClockSchema(BaseModel):
    stage: str
    deadline_utc: str
    days_remaining: int
    norm: str

class ReportResponseSchema(BaseModel):
    report_id: str
    status: str
    ai_confidence: Optional[str] = None
    ai_label: Optional[str] = None
    assigned_contractor_id: Optional[str] = None
    civic_score_delta: int
    created_at: str
    sla_clock: Optional[SlaClockSchema] = None

class NearbyDefectSchema(BaseModel):
    report_id: str
    status: str
    category: str
    latitude: float
    longitude: float
    contractor_id: Optional[str] = None
    thumbnail_url: str
    watermark_verified: bool

class DuplicateMatchSchema(BaseModel):
    existing_report_id: str
    distance_m: float
    status: str
    contractor_id: Optional[str] = None
    thumbnail_url: str

class TicketSummarySchema(BaseModel):
    report_id: str
    status: str
    category: str
    severity: str
    capture: GeoCaptureSchema
    zone: str
    thumbnail_url: str
    watermark_verified: bool
    ai_confidence: float
    days_in_status: int
    sla_clock: Optional[SlaClockSchema] = None
    assigned_contractor_id: Optional[str] = None

class ReportEventSchema(BaseModel):
    event_id: str
    report_id: str
    from_status: str
    to_status: str
    action: str
    actor_role: str
    actor_id: str
    actor_label: str
    verified_from_site: bool
    location: Optional[GeoCaptureSchema] = None
    note: Optional[str] = None
    at_utc: str

class WitnessConfirmationSchema(BaseModel):
    report_id: str
    witness_user_id: str
    capture: GeoCaptureSchema
    after_photo_path: Optional[str] = None
    at_utc: str

class ResolutionMediaSchema(BaseModel):
    report_id: str
    after_photo_urls: List[str]
    contractor_note: str
    resolved_at_utc: str
    repaired_by_contractor_id: Optional[str] = None

class ContractorReplySchema(BaseModel):
    reply_id: str
    contractor_id: str
    report_id: str
    body: str
    is_public: bool = True
    at_utc: str

class SensorChannelSchema(BaseModel):
    name: str
    sample_rate_hz: int
    samples: List[float]
    encoding: str

class FftSummarySchema(BaseModel):
    dominant_frequency_hz: float
    dominant_magnitude: float
    energy: float
    heavy_vehicle_count: int

class VibrationPayloadSchema(BaseModel):
    id: str
    user_id: str
    infrastructure_id: Optional[str] = None
    capture: GeoCaptureSchema
    duration_ms: int
    channels: List[SensorChannelSchema]
    fft_summary: Optional[FftSummarySchema] = None
    phone_flat_on_deck: bool
    traffic_triggered: bool

class AcousticDiagnosticResultSchema(BaseModel):
    id: str
    dominant_frequency_hz: float
    energy: float
    heavy_vehicle_count: int
    distress_index: float
    suggested_action: Optional[str] = None
    analyzed_at_utc: str

class ContractorSummarySchema(BaseModel):
    contractor_id: str
    company_name: str
    grade: float
    active_defects: int
    completed_projects: int
    streak_months: int
    kyc_verified: bool

class ContractorProjectSchema(BaseModel):
    project_id: str
    name: str
    scope: str
    zone: str
    started_at_utc: str
    completed_at_utc: Optional[str] = None
    rating: float
    defects_attributed: int

class ContractorDefectRefSchema(BaseModel):
    report_id: str
    category: str
    status: str
    reported_at_utc: str
    severity_weight: float

class ScoreBreakdownSchema(BaseModel):
    quality: float
    timeliness: float
    safety: float
    compliance: float

class WarrantyStateSchema(BaseModel):
    defect_id: str
    warranty_expires_at_utc: str
    recurrences: int
    score_penalty_applied: float

class ContractorPassportSchema(BaseModel):
    summary: ContractorSummarySchema
    projects: List[ContractorProjectSchema]
    defects: List[ContractorDefectRefSchema]
    score_breakdown: ScoreBreakdownSchema
    warranties: List[WarrantyStateSchema]

class ScoreBreakdownDimensionSchema(BaseModel):
    name: str
    points: int
    max_points: int

class CivicScoreSchema(BaseModel):
    total: int
    reports_submitted: int
    reports_verified: int
    resolutions_completed: int
    streak_days: int
    breakdown: List[ScoreBreakdownDimensionSchema]

class CoverageCellSchema(BaseModel):
    x: int
    y: int
    zoom: int
    report_count: int
    verified_count: int
    last_report_days_ago: int

class AttachRequestSchema(BaseModel):
    source_report_id: str

class VerifyRequestSchema(BaseModel):
    from_site: bool
    site_gps: Optional[GeoCaptureSchema] = None
    note: Optional[str] = None

class AssignRequestSchema(BaseModel):
    contractor_id: str
    sla_days: int = 30

class RejectRequestSchema(BaseModel):
    reason: str

# =====================================================================
# Distance Helpers
# =====================================================================

def haversine_distance(lat1, lon1, lat2, lon2):
    # Radius of the Earth in meters
    R = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

# =====================================================================
# API Route Implementations
# =====================================================================

@router.post("/reports", response_model=ReportResponseSchema, status_code=status.HTTP_201_CREATED)
async def upload_infrastructure_report(payload: ReportPayloadSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    # Store NearbyDefect
    store.defects[payload.id] = {
        "report_id": payload.id,
        "status": "aiVerified",
        "category": payload.category,
        "latitude": payload.capture.latitude,
        "longitude": payload.capture.longitude,
        "contractor_id": payload.contractor_id,
        "thumbnail_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "watermark_verified": True
    }

    # Store TicketSummary
    store.tickets[payload.id] = {
        "report_id": payload.id,
        "status": "aiVerified",
        "category": payload.category,
        "severity": payload.severity,
        "capture": payload.capture.dict(),
        "zone": "Pune Central",
        "thumbnail_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "watermark_verified": True,
        "ai_confidence": 0.92,
        "days_in_status": 0,
        "sla_clock": None,
        "assigned_contractor_id": payload.contractor_id
    }

    # Store Timeline Event
    store.timelines[payload.id] = [
        {
            "event_id": f"evt_{payload.id}_01",
            "report_id": payload.id,
            "from_status": "submitted",
            "to_status": "aiVerified",
            "action": "created",
            "actor_role": "citizen",
            "actor_id": payload.user_id,
            "actor_label": "Citizen Reporter",
            "verified_from_site": False,
            "location": payload.capture.dict(),
            "note": payload.description,
            "at_utc": now_str
        }
    ]

    store.save()

    return {
        "report_id": payload.id,
        "status": "aiVerified",
        "ai_confidence": "0.92",
        "ai_label": payload.category,
        "assigned_contractor_id": payload.contractor_id,
        "civic_score_delta": 15,
        "created_at": now_str,
        "sla_clock": None
    }

@router.get("/reports/{report_id}", response_model=NearbyDefectSchema)
async def fetch_defect(report_id: str):
    defect = store.defects.get(report_id)
    if not defect:
        raise HTTPException(status_code=404, detail="Defect not found")
    return defect

@router.get("/defects/duplicates", response_model=List[DuplicateMatchSchema])
async def check_duplicates(lat: float, lng: float, radius_m: float):
    matches = []
    for defect_id, d in store.defects.items():
        dist = haversine_distance(lat, lng, d["latitude"], d["longitude"])
        if dist <= radius_m:
            matches.append({
                "existing_report_id": d["report_id"],
                "distance_m": dist,
                "status": d["status"],
                "contractor_id": d["contractor_id"],
                "thumbnail_url": d["thumbnail_url"]
            })
    return matches

@router.post("/reports/{target_report_id}/attach", response_model=ReportResponseSchema)
async def attach_to_ticket(target_report_id: str, body: AttachRequestSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    # Update source status to duplicate
    if body.source_report_id in store.defects:
        store.defects[body.source_report_id]["status"] = "closed"
        store.tickets[body.source_report_id]["status"] = "closed"
        store.timelines[body.source_report_id].append({
            "event_id": f"evt_{body.source_report_id}_attach",
            "report_id": body.source_report_id,
            "from_status": "submitted",
            "to_status": "closed",
            "action": "attach",
            "actor_role": "citizen",
            "actor_id": "usr_system",
            "actor_label": "System Merge",
            "verified_from_site": False,
            "note": f"Attached as duplicate to {target_report_id}",
            "at_utc": now_str
        })
    
    store.save()

    return {
        "report_id": target_report_id,
        "status": "aiVerified",
        "civic_score_delta": 5,
        "created_at": now_str
    }

@router.get("/tickets/queue", response_model=List[TicketSummarySchema])
async def fetch_ticket_queue(for_role: Optional[str] = None, status: Optional[str] = None, zone: Optional[str] = None):
    results = []
    for ticket in store.tickets.values():
        if status and ticket["status"] != status:
            continue
        if zone and ticket["zone"] != zone:
            continue
        results.append(ticket)
    return results

@router.get("/reports/{report_id}/timeline", response_model=List[ReportEventSchema])
async def fetch_report_timeline(report_id: str):
    timeline = store.timelines.get(report_id, [])
    return timeline

@router.get("/reports/witness-nearby", response_model=List[NearbyDefectSchema])
async def fetch_witnessable_nearby(lat: float, lng: float, radius_m: float = 50.0):
    results = []
    for d in store.defects.values():
        if d["status"] in ("submitted", "aiVerified"):
            dist = haversine_distance(lat, lng, d["latitude"], d["longitude"])
            if dist <= radius_m:
                results.append(d)
    return results

@router.post("/reports/{report_id}/witness", response_model=ReportResponseSchema)
async def submit_witness_confirmation(report_id: str, confirmation: WitnessConfirmationSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_witness_{uuid.uuid4().hex[:6]}",
        "report_id": report_id,
        "from_status": store.defects[report_id]["status"],
        "to_status": store.defects[report_id]["status"],
        "action": "reply",
        "actor_role": "citizen",
        "actor_id": confirmation.witness_user_id,
        "actor_label": "Witness Confirmation",
        "verified_from_site": True,
        "location": confirmation.capture.dict(),
        "note": "Citizen peer witness confirmation submitted.",
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": store.defects[report_id]["status"],
        "civic_score_delta": 10,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/verify", response_model=ReportResponseSchema)
async def verify_report(report_id: str, body: VerifyRequestSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.defects[report_id]["status"] = "assigned"
    store.tickets[report_id]["status"] = "assigned"
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_verify",
        "report_id": report_id,
        "from_status": "aiVerified",
        "to_status": "assigned",
        "action": "verify",
        "actor_role": "officer",
        "actor_id": "usr_officer_01",
        "actor_label": "Officer Sharma",
        "verified_from_site": body.from_site,
        "location": body.site_gps.dict() if body.site_gps else None,
        "note": body.note,
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": "assigned",
        "civic_score_delta": 0,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/assign", response_model=ReportResponseSchema)
async def assign_contractor(report_id: str, body: AssignRequestSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.defects[report_id]["contractor_id"] = body.contractor_id
    store.defects[report_id]["status"] = "assigned"
    store.tickets[report_id]["status"] = "assigned"
    store.tickets[report_id]["assigned_contractor_id"] = body.contractor_id
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_assign",
        "report_id": report_id,
        "from_status": "aiVerified",
        "to_status": "assigned",
        "action": "assign",
        "actor_role": "officer",
        "actor_id": "usr_officer_01",
        "actor_label": "Officer Sharma",
        "verified_from_site": False,
        "note": f"Assigned contractor {body.contractor_id} with {body.sla_days} days SLA.",
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": "assigned",
        "civic_score_delta": 0,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/reject", response_model=ReportResponseSchema)
async def reject_report(report_id: str, body: RejectRequestSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.defects[report_id]["status"] = "rejected"
    store.tickets[report_id]["status"] = "rejected"
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_reject",
        "report_id": report_id,
        "from_status": "submitted",
        "to_status": "rejected",
        "action": "reject",
        "actor_role": "officer",
        "actor_id": "usr_officer_01",
        "actor_label": "Officer Sharma",
        "verified_from_site": False,
        "note": body.reason,
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": "rejected",
        "civic_score_delta": 0,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/approve", response_model=ReportResponseSchema)
async def approve_resolution(report_id: str):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.defects[report_id]["status"] = "resolved"
    store.tickets[report_id]["status"] = "resolved"
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_approve",
        "report_id": report_id,
        "from_status": "awaitAcceptance",
        "to_status": "resolved",
        "action": "approve",
        "actor_role": "officer",
        "actor_id": "usr_officer_01",
        "actor_label": "Officer Sharma",
        "verified_from_site": False,
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": "resolved",
        "civic_score_delta": 0,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/claim", response_model=ReportResponseSchema)
async def claim_ticket(report_id: str):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.defects[report_id]["status"] = "inProgress"
    store.tickets[report_id]["status"] = "inProgress"
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_claim",
        "report_id": report_id,
        "from_status": "assigned",
        "to_status": "inProgress",
        "action": "claim",
        "actor_role": "contractor",
        "actor_id": "ctr_pune_infra",
        "actor_label": "Pune Infra Buildtech Ltd",
        "verified_from_site": True,
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": "inProgress",
        "civic_score_delta": 0,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/resolution", response_model=ReportResponseSchema)
async def submit_resolution_media(report_id: str, media: ResolutionMediaSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    store.defects[report_id]["status"] = "awaitAcceptance"
    store.tickets[report_id]["status"] = "awaitAcceptance"
    
    store.resolutions[report_id] = media.dict()
    
    store.timelines[report_id].append({
        "event_id": f"evt_{report_id}_resolve",
        "report_id": report_id,
        "from_status": "inProgress",
        "to_status": "awaitAcceptance",
        "action": "submitAfterPhoto",
        "actor_role": "contractor",
        "actor_id": "ctr_pune_infra",
        "actor_label": "Pune Infra Buildtech Ltd",
        "verified_from_site": True,
        "note": media.contractor_note,
        "at_utc": now_str
    })
    
    store.save()

    return {
        "report_id": report_id,
        "status": "awaitAcceptance",
        "civic_score_delta": 0,
        "created_at": now_str
    }

@router.post("/reports/{report_id}/reply")
async def submit_contractor_reply(report_id: str, reply: ContractorReplySchema):
    now_str = datetime.now(timezone.utc).isoformat()
    if report_id not in store.replies:
        store.replies[report_id] = []
    
    store.replies[report_id].append(reply.dict())
    
    store.timelines[report_id].append({
        "event_id": reply.reply_id,
        "report_id": report_id,
        "from_status": store.defects[report_id]["status"],
        "to_status": store.defects[report_id]["status"],
        "action": "reply",
        "actor_role": "contractor",
        "actor_id": reply.contractor_id,
        "actor_label": "Contractor Reply",
        "verified_from_site": False,
        "note": reply.body,
        "at_utc": now_str
    })
    
    store.save()
    return {"message": "Reply added successfully."}

@router.post("/bridge-check", response_model=AcousticDiagnosticResultSchema)
async def submit_acoustic_diagnostic(payload: VibrationPayloadSchema):
    now_str = datetime.now(timezone.utc).isoformat()
    
    # Calculate a mock distress index based on duration and heavy vehicles
    energy = payload.fft_summary.energy if payload.fft_summary else 12.5
    heavy_count = payload.fft_summary.heavy_vehicle_count if payload.fft_summary else 2
    
    distress_index = min(10.0, 2.0 + (energy * 0.1) + (heavy_count * 0.5))
    suggested_action = "Routine inspection scheduled" if distress_index < 5.0 else "Immediate structural review recommended"
    
    return {
        "id": payload.id,
        "dominant_frequency_hz": payload.fft_summary.dominant_frequency_hz if payload.fft_summary else 14.2,
        "energy": energy,
        "heavy_vehicle_count": heavy_count,
        "distress_index": distress_index,
        "suggested_action": suggested_action,
        "analyzed_at_utc": now_str
    }

@router.get("/contractors/leaderboard", response_model=List[ContractorSummarySchema])
async def fetch_leaderboard(limit: int = 50):
    return store.leaderboard[:limit]

@router.get("/contractors/{contractor_id}/passport", response_model=ContractorPassportSchema)
async def fetch_contractor_passport(contractor_id: str):
    passport = store.passports.get(contractor_id)
    if not passport:
        raise HTTPException(status_code=404, detail="Contractor passport not found")
    return passport

@router.get("/defects/nearby", response_model=List[NearbyDefectSchema])
async def fetch_nearby_defects(lat: float, lng: float, radius_m: float, status: Optional[str] = None):
    results = []
    statuses = status.split(",") if status else []
    for d in store.defects.values():
        if statuses and d["status"] not in statuses:
            continue
        dist = haversine_distance(lat, lng, d["latitude"], d["longitude"])
        if dist <= radius_m:
            results.append(d)
    return results

@router.get("/defects/coverage", response_model=List[CoverageCellSchema])
async def fetch_coverage(sw_lat: float, sw_lng: float, ne_lat: float, ne_lng: float, zoom: int):
    # Generates a few mock coverage cells matching the bounding box
    results = [
        {
            "x": 36980,
            "y": 24150,
            "zoom": zoom,
            "report_count": 12,
            "verified_count": 8,
            "last_report_days_ago": 1
        },
        {
            "x": 36981,
            "y": 24151,
            "zoom": zoom,
            "report_count": 5,
            "verified_count": 3,
            "last_report_days_ago": 3
        }
    ]
    return results

@router.get("/reports/{report_id}/resolution", response_model=ResolutionMediaSchema)
async def fetch_resolution(report_id: str):
    res = store.resolutions.get(report_id)
    if not res:
        raise HTTPException(status_code=404, detail="Resolution details not found")
    return res

@router.get("/users/{user_id}/score", response_model=CivicScoreSchema)
async def fetch_civic_score(user_id: str):
    return {
        "total": 145,
        "reports_submitted": 8,
        "reports_verified": 6,
        "resolutions_completed": 3,
        "streak_days": 5,
        "breakdown": [
            {
                "name": "Quality of Reports",
                "points": 45,
                "max_points": 50
            },
            {
                "name": "Verification Accuracy",
                "points": 50,
                "max_points": 50
            },
            {
                "name": "Community Impact",
                "points": 50,
                "max_points": 50
            }
        ]
    }

@router.get("/users/{user_id}/reports", response_model=List[ReportResponseSchema])
async def fetch_my_reports(user_id: str):
    results = []
    now_str = datetime.now(timezone.utc).isoformat()
    for d in store.defects.values():
        results.append({
            "report_id": d["report_id"],
            "status": d["status"],
            "civic_score_delta": 15,
            "created_at": now_str
        })
    return results

@router.post("/reports/sync", response_model=List[ReportResponseSchema])
async def sync_pending_drafts(drafts: List[ReportPayloadSchema]):
    results = []
    now_str = datetime.now(timezone.utc).isoformat()
    for d in drafts:
        # Save to store
        store.defects[d.id] = {
            "report_id": d.id,
            "status": "submitted",
            "category": d.category,
            "latitude": d.capture.latitude,
            "longitude": d.capture.longitude,
            "contractor_id": d.contractor_id,
            "thumbnail_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
            "watermark_verified": True
        }
        results.append({
            "report_id": d.id,
            "status": "submitted",
            "civic_score_delta": 15,
            "created_at": now_str
        })
    store.save()
    return results

# =====================================================================
# Auth Integration Schemas & Endpoints
# =====================================================================

class OTPSendRequest(BaseModel):
    phone: str

class OTPVerifyRequest(BaseModel):
    phone: str
    otp: str

class SwitchRoleRequest(BaseModel):
    role: str

class AuthSessionResponseSchema(BaseModel):
    userId: str
    accessToken: Optional[str] = None
    refreshToken: Optional[str] = None
    isGuest: bool
    role: str
    isIdentityVerified: bool
    phoneNumber: Optional[str] = None
    displayName: Optional[str] = None

@router.post("/auth/guest", response_model=AuthSessionResponseSchema)
async def auth_guest():
    return {
        "userId": "guest_user",
        "accessToken": None,
        "refreshToken": None,
        "isGuest": True,
        "role": "citizen",
        "isIdentityVerified": False,
        "phoneNumber": None,
        "displayName": None
    }

@router.post("/auth/otp/send")
async def auth_otp_send(body: OTPSendRequest):
    return {"message": "Verification code dispatched if account exists."}

@router.post("/auth/otp/verify", response_model=AuthSessionResponseSchema)
async def auth_otp_verify(body: OTPVerifyRequest):
    if body.otp != "123456":
        raise HTTPException(status_code=400, detail="Invalid OTP code. Use 123456 for testing.")
    
    phone = body.phone
    if phone.endswith("9999") or phone == "+919876543210":
        role = "officer"
        display_name = "Officer Sharma - Ward 4 Engineer"
    elif phone.endswith("8888") or phone == "+919876543211":
        role = "contractor"
        display_name = "Apex Infra Projects Ltd"
    else:
        role = "citizen"
        display_name = "Verified Citizen"
        
    return {
        "userId": f"user_{phone.replace('+', '').replace(' ', '')}",
        "accessToken": f"mock_access_token_{int(datetime.now(timezone.utc).timestamp())}",
        "refreshToken": "mock_refresh_token",
        "isGuest": False,
        "role": role,
        "isIdentityVerified": True,
        "phoneNumber": phone,
        "displayName": display_name
    }

@router.post("/auth/switch-role", response_model=AuthSessionResponseSchema)
async def auth_switch_role(body: SwitchRoleRequest):
    role = body.role
    if role == "officer":
        display_name = "Officer Sharma - Ward 4 Engineer"
    elif role == "contractor":
        display_name = "Apex Infra Projects Ltd"
    elif role == "admin":
        display_name = "System Administrator"
    else:
        role = "citizen"
        display_name = "Verified Citizen"
        
    return {
        "userId": "user_demo",
        "accessToken": "demo_token",
        "refreshToken": "mock_refresh_token",
        "isGuest": False,
        "role": role,
        "isIdentityVerified": True,
        "phoneNumber": "+919876543210",
        "displayName": display_name
    }

@router.post("/auth/logout", status_code=204)
async def auth_logout():
    return None

