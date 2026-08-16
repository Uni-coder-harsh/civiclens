# 🔍 CivicLens

> **AI-Powered Infrastructure Intelligence, Real-Time Defect Telemetry, & Civic Mobilization Platform**

CivicLens is an end-to-end, multi-role civic technology platform designed to detect, track, forecast, and resolve municipal infrastructure hazards (potholes, structural road cracks, rutting, and bridge decay). Combining state-of-the-art **Computer Vision (YOLOv8 ONNX @ 736×736 & LocateAnything-3B VLM)**, **Real-Time Spatial Telemetry & Proximity Alerts**, **OpenStreetMap Geocoding**, and a dedicated **Social Media Activist Portal with LLM Campaign Generation**, CivicLens bridges the gap between citizens, social media advocates, municipal officers, and contractors.

---

## 🌟 Key Features

### 🤖 Computer Vision & Dual AI Inference Pipeline
- **YOLOv8 ONNX Runtime (736×736 Input Resolution)**: High-precision real-time detection of structural road and bridge defects with bounding box coordinates, multi-class confidence scoring, and severity classifications.
- **LocateAnything-3B Vision-Language Grounding**: Remote GPU-accelerated model for deep natural language spatial reasoning over complex structural imagery.
- **Automated AI Retest & Backfill**: On-demand re-running of ML inference over historical or newly uploaded media through high-performance backend pipelines.

### 📍 Interactive Real-Time Map & Proximity Hazard Alerts
- **Live Location Camera Follow**: Dynamic map camera auto-centering that follows the user's real-time position with preserved zoom levels.
- **Proximity Hazard Alerts**: Real-time GPS stream listener calculating proximity (up to 200m) and heading alignment (within a $45^\circ$ cone) to nearby defects:
  - **Warning Cards** (50m - 200m range).
  - **Pulsating Critical Alerts** (< 50m range) warning drivers of imminent road hazards.
- **Dual Map Layer System**: Instant toggle between ArcGIS World Street Map (road geometry and place names) and High-Resolution Satellite Imagery.

### 🗺️ Reverse Geocoding & Landmark Resolution
- **OpenStreetMap (OSM) Provider Integration**: Automatically converts raw GPS coordinates (`latitude`, `longitude`) into formatted place names, street names, and municipal districts (e.g., *"FC Road, Deccan Gymkhana, Pune"*).

### 📣 Social Media Activist Portal & LLM Mobilization
- **Structural Degradation Forecasting**: Calculates **Time to Complete Structural Failure** based on environmental monsoon indices, daily heavy freight stress loads, and natural calamity risks.
- **Groq Llama-3 AI Caption Generator**: Automatically drafts urgent, high-impact Instagram and Facebook captions and hashtags tailored to municipal pressure.
- **NLP Prompt Refinement**: Allows activists to refine generated captions using natural language (e.g., *"Make it sarcastic and add Marathi handles"*).
- **Rajkot & Regional Influencer Targeting**: Includes a checkable target list of regional channels and authorities (e.g., `@rajkotlivenews`, `@rajkot_municipal_corporation`, `@active_rajkot`) to append directly into post tags.
- **Native OS Share Integration**: Copies campaign text to the clipboard and triggers native OS share sheets (`share_plus`) for 1-tap posting on Instagram Feed/Stories, Facebook, and YouTube.

### 👥 Multi-Role Role-Based Access Control (RBAC)
- **Verified Citizen**: Capture defects, verify witness reports, track civic scores, view local leaderboards, and inspect contractor passports.
- **Officer / Inspector**: Triage queue management, review AI verdicts, assign tickets, manage repair workflows.
- **Contractor**: Claim repair jobs, submit post-repair proof photos, track passport ratings and SLA completions.
- **Social Media Activist**: Access dedicated reach analytics (`Total Reach`, `Repairs Sparked`, `Regional Rank`), manage active campaigns, and mobilize public pressure.
- **Admin**: System management and organizational oversight.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    subgraph Client Layer
        Mobile["📱 Flutter Mobile App (iOS / Android)"]
    end

    subgraph Backend Layer (FastAPI & Python 3.10)
        Router["⚡ Integration & Auth Router"]
        AIService["🤖 AI Service Manager"]
        GEO["🗺️ OpenStreetMap Reverse Geocoder"]
        DB["🐘 Neon PostgreSQL Database (SQLAlchemy & Asyncpg)"]
        Store["📦 Supabase / MinIO Cloud Storage"]
    end

    subgraph ML Inference Engine
        ONNX["🎯 YOLOv8 ONNX Model (736x736 Input)"]
        Locate3B["👁️ LocateAnything-3B VLM Remote Service"]
        Groq["🧠 Groq Llama-3 LLM API"]
    end

    Mobile -->|REST API & Auth Tokens| Router
    Router --> GEO
    Router --> DB
    Router --> Store
    Router --> AIService

    AIService -->|Local ONNX Inference| ONNX
    AIService -->|Remote GPU API| Locate3B
    Router -->|Campaign Caption Generation| Groq
```

---

## 📁 Repository Structure

```text
civiclens/
├── backend/                  # FastAPI Application & Async Engine
│   ├── app/
│   │   ├── modules/
│   │   │   ├── ai/           # ONNX Engine, severity scoring, LocateAnything client
│   │   │   ├── auth/         # JWT Session auth, OTP verification, roles
│   │   │   ├── integration/  # Main API routes, geocoding, caption generation
│   │   │   ├── reports/      # Citizen report entities and services
│   │   │   └── infrastructure_identity/ # OSM Geocoding providers
│   │   └── core/             # Database session, config, security
│   ├── alembic/              # Database migration scripts
│   └── requirements.txt      # Backend Python dependencies
├── flutter-app/              # Flutter Cross-Platform Application
│   ├── lib/
│   │   ├── core/             # Auth sessions, GoRouter, Theme, Utilities
│   │   ├── features/
│   │   │   ├── activist/     # Activist Dashboard & Social Campaign Sheet
│   │   │   ├── auth/         # Login, Register, Role switcher
│   │   │   ├── contractor/   # Contractor claims & Passport views
│   │   │   ├── home/         # Citizen & Activist Home Dashboards
│   │   │   ├── map/          # FlutterMap, Proximity Stream, ArcGIS layers
│   │   │   ├── officer/      # Triage dashboard & queue management
│   │   │   └── report/       # Report creation, Detail view & AI Retest
│   │   └── shared/           # Data models (Defect, Ticket, UserRole)
│   └── pubspec.yaml          # Flutter dependencies
├── ml-engine/                # Machine Learning Training & Inference Scripts
│   ├── best.onnx             # Exported 736x736 YOLOv8 ONNX model
│   ├── test_road.jpg         # Sample verification imagery
│   └── lightning/            # Remote GPU LocateAnything-3B setup scripts
└── docker-compose.yml        # Multi-container orchestration
```

---

## ⚡ Quick Start & Setup Guide

### Prerequisites
- **Flutter SDK**: `>= 3.22.0`
- **Python**: `>= 3.10`
- **PostgreSQL**: PostgreSQL 14+ or Neon DB instance
- **Groq API Key**: (Optional, for LLM social caption generation)

---

### 1. Backend Setup

```bash
# 1. Navigate to backend directory
cd backend

# 2. Create and activate a Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Install Python dependencies
pip install -r requirements.txt

# 4. Set environment variables (create a .env file based on .env.example)
export DATABASE_URL="postgresql+asyncpg://user:password@localhost:5432/civiclens"
export GROQ_API_KEY="your_groq_api_key_here"

# 5. Run database migrations
alembic upgrade head

# 6. Start the FastAPI development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The backend server will be live at `http://localhost:8000`. Swagger API docs are available at `http://localhost:8000/docs`.

---

### 2. Flutter App Setup

```bash
# 1. Navigate to the Flutter application directory
cd flutter-app

# 2. Fetch Flutter packages
flutter pub get

# 3. Analyze code for any issues
flutter analyze

# 4. Run the app on a connected device or emulator
flutter run

# 5. Build Release APK
flutter build apk --verbose
```

---

## 🔑 Demo Credentials & Role Switcher

CivicLens includes a floating **Demo Role Switcher FAB** in demo builds, allowing instant role swapping between Citizen, Officer, Contractor, and Activist views without re-authenticating.

Alternatively, you can log in directly on the **Email Login Page**:

| Role | Demo Email | Password |
| :--- | :--- | :--- |
| **Social Media Activist** | `activist@civiclens.gov.in` | `activist123` |
| **Municipal Officer** | `officer@civiclens.gov.in` | `officer123` |
| **Contractor** | `contractor@civiclens.gov.in` | `contractor123` |
| **Citizen** | `citizen@civiclens.gov.in` | `citizen123` |

---

## 📡 API Reference Overview

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/reports` | `POST` | Upload new infrastructure defect report with capture coordinates |
| `/v1/defects/{report_id}` | `GET` | Fetch detailed report info with ML detections and geocoded address |
| `/v1/defects/nearby` | `GET` | Query defects by latitude, longitude, and radius meters |
| `/v1/ai/generate-caption` | `POST` | Generate Groq Llama-3 social media captions, tags, and failure forecasts |
| `/v1/reports/{report_id}/ai-analysis/retest` | `POST` | On-demand re-execution of ONNX model against stored report image |
| `/auth/switch-role` | `POST` | Switch active session role for demo environment |

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
