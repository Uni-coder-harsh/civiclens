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

## 📱 Mobile Application Workflows & User Interfaces

```mermaid
graph TD
    A[Launch CivicLens App] --> B{User Role Selection / Auth}
    B -->|Citizen Role| C[Citizen Home Dashboard]
    B -->|Activist Role| D[Activist Home Workspace]
    B -->|Officer Role| E[Officer Triage Portal]
    B -->|Contractor Role| F[Contractor Job Hub]

    C --> C1[Capture Photo / Video Sweep / Drone]
    C --> C2[Explore Live Hazard Map]
    C --> C3[View Report & Retest Crack AI]

    D --> D1[Reach Analytics & Campaign Tracking]
    D --> D2[AI Social Mobilization Desk]
    D2 --> D3[Groq Llama-3 Caption & NLP Refine]
    D3 --> D4[Auto-Copy Clipboard & Share Sheet Launch]

    E --> E1[Inspect AI Verdicts & Assign SLAs]
    F --> F1[Claim Jobs & Upload Proof Photos]
```

### 1. 👤 Verified Citizen Workflow
- **Home Dashboard Landing**:
  - **Civic Score Header**: Displays contributor points, level progression (e.g., *Level 3 - Elite Contributor*), and contribution badges.
  - **Quick Action Hub**: 1-tap buttons to `Capture Crack`, `Explore Map`, and `View Contractors`.
  - **Activity Feed**: Displays recent local report updates with status pills (`SUBMITTED`, `IN_REVIEW`, `IN_PROGRESS`, `VERIFIED`).
- **Defect Image Capture Modes**:
  - **Single Photo Capture**: Camera preview interface with target alignment grid for snapping high-resolution photos of potholes, road cracks, or bridge decay.
  - **Sweep / Video Frame Sampling Mode**: Continuous frame extraction while driving or walking over a stretch of road; automatically buffers frames and runs backend YOLOv8 detection across the sequence.
  - **Drone Upload Mode**: Supports uploading aerial JPG/PNG drone footage for inspecting large highway sections or bridge pillars.
  - **Bridge Check Mode**: Guided structural vibration & crack inspection workflow featuring instruction screens, sensor recording, and automated structural health verdict screens.
- **Detailed Defect Reports & Live AI Retest**:
  - Interactive photo card rendering detected bounding boxes, defect labels, confidence percentage, and color-coded severity badges (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`).
  - **Reverse Geocoded Location**: Displays real OpenStreetMap street names (e.g., *"FC Road, Deccan Gymkhana, Pune"*).
  - **Retest Crack Detection Button**: Executes an on-demand backend re-test (`POST /v1/reports/{id}/ai-analysis/retest`) to refresh bounding boxes and confidence scores directly from the details screen.
- **Profile & Public Contractor Passports**:
  - Profile screen displaying identity verification status, contribution stats, and email/phone details.
  - Public Contractor Passports search allowing citizens to inspect contractor performance ratings, total jobs completed, and SLA compliance metrics.

---

### 2. 🛡️ Municipal Officer / Inspector Workflow
- **Triage Dashboard**:
  - Real-time queue listing citizen-submitted defect reports sorted by priority and severity.
- **Ticket Review & Work Assignment**:
  - Inspect AI detections and bounding boxes.
  - Approve or reject citizen reports, adjust severity levels, and assign work tickets to registered municipal contractors with explicit SLA deadlines.

---

### 3. 🏗️ Municipal Contractor Workflow
- **Contractor Hub Dashboard**:
  - Job portal listing claimed, assigned, and available repair tickets.
- **Job Execution & Proof Verification**:
  - Navigate to defect coordinates using map integration.
  - Capture and upload **After-Repair Proof Photos**.
  - Submit work for final officer verification and public passport rating credit.

---

### 4. 📣 Social Media Activist Workflow
- **Activist Home Workspace**:
  - **Reach & Influence Metrics**: Custom dashboard displaying `Total Post Reach` (e.g., 384.2K), `Repairs Sparked` (18 Defects), `Regional Rank` (#3 in Rajkot), and `Active Shares`.
  - **Active Campaigns Records**: Tracks active social postings with live progress bars, view counts (e.g., 15.4K views), and repair status indicators.
  - **Open Regional Alerts**: Lists local defects that require social pressure to accelerate municipal repair timelines.
- **AI Social Campaign Mobilization Desk**:
  - **Structural Degradation Forecast**: Calculates estimated **Time to Complete Failure** based on environmental monsoon indices, heavy freight traffic loads, and natural calamity risks.
  - **Groq Llama-3 AI Caption Generator**: Creates high-urgency, engaging captions formatted with emojis, location tags, and emergency calls-to-action.
  - **NLP Custom Prompt Refinement**: Allows typing natural language instructions (e.g., *"Make the tone sarcastic and request citizens to tag local politicians"*) to regenerate campaign text.
  - **Target Local Influencers Checklist**: Checkable list of regional Rajkot and Pune channels/authorities (e.g., `@rajkotlivenews`, `@rajkot_municipal_corporation`, `@active_rajkot`, `@rajkotupdates`) to automatically inject handle tags into the post text.
  - **1-Tap Copy & Native Share Sheet Launch**: Automatically copies the caption and hashtags to the device clipboard, prompts the user, and launches the native OS share dialog (`share_plus`) to post directly to Instagram (Feed/Stories), Facebook, or YouTube.

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
