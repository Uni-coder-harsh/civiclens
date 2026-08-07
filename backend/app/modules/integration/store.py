import os
import json
from datetime import datetime, timezone

# Ensure the data directory exists
STORE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "data")
STORE_PATH = os.path.join(STORE_DIR, "integration_store.json")

class IntegrationStore:
    def __init__(self):
        self.defects = {}
        self.tickets = {}
        self.timelines = {}
        self.resolutions = {}
        self.replies = {}
        self.passports = {}
        self.leaderboard = []
        self.load()

    def load(self):
        if os.path.exists(STORE_PATH):
            try:
                with open(STORE_PATH, "r") as f:
                    data = json.load(f)
                    self.defects = data.get("defects", {})
                    self.tickets = data.get("tickets", {})
                    self.timelines = data.get("timelines", {})
                    self.resolutions = data.get("resolutions", {})
                    self.replies = data.get("replies", {})
                    self.passports = data.get("passports", {})
                    self.leaderboard = data.get("leaderboard", [])
                    return
            except Exception as e:
                print(f"Error loading integration store: {e}")

        # Seed default mock data
        self._seed_data()
        self.save()

    def _seed_data(self):
        now_str = datetime.now(timezone.utc).isoformat()
        
        # Seeded Contractor Summary
        contractor = {
            "contractor_id": "ctr_pune_infra",
            "company_name": "Pune Infra Buildtech Ltd",
            "grade": 4.6,
            "active_defects": 3,
            "completed_projects": 42,
            "streak_months": 8,
            "kyc_verified": True
        }
        self.leaderboard = [contractor]

        # Seeded Passport
        self.passports["ctr_pune_infra"] = {
            "summary": contractor,
            "projects": [
                {
                    "project_id": "prj_01",
                    "name": "Z-Bridge Structural Maintenance",
                    "scope": "bridge",
                    "zone": "Pune Central",
                    "started_at_utc": now_str,
                    "completed_at_utc": now_str,
                    "rating": 4.8,
                    "defects_attributed": 12
                }
            ],
            "defects": [
                {
                    "report_id": "report_04",
                    "category": "roadCrack",
                    "status": "assigned",
                    "reported_at_utc": now_str,
                    "severity_weight": 1.5
                }
            ],
            "score_breakdown": {
                "quality": 4.7,
                "timeliness": 4.5,
                "safety": 4.8,
                "compliance": 4.4
            },
            "warranties": [
                {
                    "defect_id": "report_07",
                    "warranty_expires_at_utc": now_str,
                    "recurrences": 0,
                    "score_penalty_applied": 0.0
                }
            ]
        }

        # Seeded defects list
        seeded = [
            {
                "id": "report_01",
                "category": "bridgeCrack",
                "severity": "critical",
                "status": "aiVerified",
                "lat": 18.5166,
                "lng": 73.8427,
                "watermarkVerified": True,
                "aiConfidence": 0.96,
                "zone": "Deccan Gymkhana",
                "thumb": "https://images.unsplash.com/photo-1541888946425-d0fbb186a5b7",
                "contractorId": None
            },
            {
                "id": "report_02",
                "category": "pothole",
                "severity": "high",
                "status": "submitted",
                "lat": 18.5204,
                "lng": 73.8567,
                "watermarkVerified": True,
                "aiConfidence": 0.88,
                "zone": "Shivajinagar",
                "thumb": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
                "contractorId": None
            },
            {
                "id": "report_03",
                "category": "pothole",
                "severity": "high",
                "status": "submitted",
                "lat": 18.52043,
                "lng": 73.85672,
                "watermarkVerified": True,
                "aiConfidence": 0.89,
                "zone": "Shivajinagar",
                "thumb": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
                "contractorId": None
            },
            {
                "id": "report_04",
                "category": "roadCrack",
                "severity": "medium",
                "status": "assigned",
                "lat": 18.5250,
                "lng": 73.8500,
                "watermarkVerified": True,
                "aiConfidence": 0.91,
                "zone": "Model Colony",
                "thumb": "https://images.unsplash.com/photo-1578991624414-276ef23a534f",
                "contractorId": "ctr_pune_infra"
            },
            {
                "id": "report_05",
                "category": "manhole",
                "severity": "high",
                "status": "inProgress",
                "lat": 18.5180,
                "lng": 73.8600,
                "watermarkVerified": True,
                "aiConfidence": 0.94,
                "zone": "FC Road",
                "thumb": "https://images.unsplash.com/photo-1509114397022-ed747cca3f65",
                "contractorId": "ctr_pune_infra"
            },
            {
                "id": "report_06",
                "category": "guardrail",
                "severity": "medium",
                "status": "awaitAcceptance",
                "lat": 18.5300,
                "lng": 73.8400,
                "watermarkVerified": True,
                "aiConfidence": 0.85,
                "zone": "Aundh",
                "thumb": "https://images.unsplash.com/photo-1590486803833-1c5dc8ddd4c8",
                "contractorId": "ctr_pune_infra"
            },
            {
                "id": "report_07",
                "category": "pothole",
                "severity": "low",
                "status": "resolved",
                "lat": 18.5100,
                "lng": 73.8550,
                "watermarkVerified": True,
                "aiConfidence": 0.95,
                "zone": "Swargate",
                "thumb": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
                "contractorId": "ctr_pune_infra"
            },
            {
                "id": "report_08",
                "category": "other",
                "severity": "low",
                "status": "rejected",
                "lat": 18.5050,
                "lng": 73.8620,
                "watermarkVerified": False,
                "aiConfidence": 0.40,
                "zone": "Bibwewadi",
                "thumb": "https://images.unsplash.com/photo-1584467735871-8e85353a8413",
                "contractorId": None
            }
        ]

        for s in seeded:
            self.defects[s["id"]] = {
                "report_id": s["id"],
                "status": s["status"],
                "category": s["category"],
                "latitude": s["lat"],
                "longitude": s["lng"],
                "contractor_id": s["contractorId"],
                "thumbnail_url": s["thumb"],
                "watermark_verified": s["watermarkVerified"]
            }

            self.tickets[s["id"]] = {
                "report_id": s["id"],
                "status": s["status"],
                "category": s["category"],
                "severity": s["severity"],
                "capture": {
                    "latitude": s["lat"],
                    "longitude": s["lng"],
                    "altitude_m": 560.0,
                    "accuracy_m": 4.5,
                    "bearing_deg": 180.0,
                    "speed_mps": 0.0,
                    "captured_at": now_str
                },
                "zone": s["zone"],
                "thumbnail_url": s["thumb"],
                "watermark_verified": s["watermarkVerified"],
                "ai_confidence": s["aiConfidence"],
                "days_in_status": 2,
                "sla_clock": {
                    "stage": s["status"],
                    "deadline_utc": now_str,
                    "days_remaining": 20,
                    "norm": "PWD"
                } if s["status"] in ("assigned", "inProgress", "awaitAcceptance") else None,
                "assigned_contractor_id": s["contractorId"]
            }

            self.timelines[s["id"]] = [
                {
                    "event_id": f"evt_{s['id']}_01",
                    "report_id": s["id"],
                    "from_status": "submitted",
                    "to_status": "submitted",
                    "action": "created",
                    "actor_role": "citizen",
                    "actor_id": "usr_citizen_01",
                    "actor_label": "Citizen Reporter",
                    "verified_from_site": False,
                    "location": None,
                    "note": None,
                    "at_utc": now_str
                }
            ]

    def save(self):
        os.makedirs(STORE_DIR, exist_ok=True)
        try:
            with open(STORE_PATH, "w") as f:
                json.dump({
                    "defects": self.defects,
                    "tickets": self.tickets,
                    "timelines": self.timelines,
                    "resolutions": self.resolutions,
                    "replies": self.replies,
                    "passports": self.passports,
                    "leaderboard": self.leaderboard
                }, f, indent=2)
        except Exception as e:
            print(f"Error saving integration store: {e}")

# Global store instance
store = IntegrationStore()
