# 🏙️ Civic Connect — Digital Civic Issue Resolution Platform

> **Mobile Application Development (MAD) Project**  
> Direct, intelligent bridge between citizens and municipal authorities for real-time reporting, automated routing, and transparent civic resolution.

---

## 📌 Overview

**Civic Connect** is a full-stack, location-aware civic problem-solving platform designed to streamline municipal governance:
- **Citizens**: Report civic issues (potholes, garbage, broken streetlights, water leaks) with live GPS capture, photos, and auto-duplicate detection.
- **Municipal Authorities**: Automatically geofence, classify, and route complaints to the responsible department, zone, ward, and field crew.
- **Tracking & Transparency**: Real-time status updates, SLA timelines, citizen verification, and public transparency feeds.

---

## 🏗️ Architecture

```
                  ┌────────────────────────────────┐
                  │    Flutter Mobile Frontend     │
                  │ (Android / iOS / Web / Desktop)│
                  └───────────────┬────────────────┘
                                  │ REST APIs
                                  ▼
                  ┌────────────────────────────────┐
                  │     FastAPI Python Backend     │
                  │   Routing / SLA / Geo-Engine   │
                  └───────────────┬────────────────┘
                                  │
                   ┌──────────────┴──────────────┐
                   ▼                             ▼
   ┌───────────────────────────────┐ ┌──────────────────────┐
   │     Supabase / PostgreSQL     │ │ Supabase S3 Storage  │
   │  PostGIS Spatial Data & Auth  │ │   Evidence & Photos  │
   └───────────────────────────────┘ └──────────────────────┘
```

---

## 📁 Repository Structure

```
├── backend/                  # FastAPI Backend Engine
│   ├── app/
│   │   ├── api/              # API Endpoints (reports, staff, analytics, locations)
│   │   ├── core/             # Configuration & Database Connection pool
│   │   └── services/         # Geo, SLA, duplicate, and routing engines
│   ├── db/                   # Schema migrations & seed data scripts
│   ├── .env.example          # Environment variables template
│   └── requirements.txt      # Python dependencies
│
├── frontend/                 # Flutter Cross-Platform Application
│   ├── lib/                  # Dart source code (core, features, widgets)
│   ├── android/              # Android native configuration
│   ├── ios/                  # iOS native configuration
│   └── pubspec.yaml          # Flutter dependencies & assets
│
├── everythingabtproject.md   # Detailed project blueprint & concept documentation
├── lookme.md                 # System architecture & technical specification
├── Civic_Connect_Report.docx # Academic project report
└── Civic_Connect_MAD_Report.docx
```

---

## 🚀 Getting Started

### 1. Backend Setup
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Supabase / Postgres credentials

# Run database schema migration & seed data
python db/init_db.py
python db/seed_data.py

# Start FastAPI dev server
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Frontend Setup (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

---

## 👥 Contributors & Academic Reference
- **Course**: Mobile Application Development (MAD)
- **Repository**: [RevanthR08/sem5MAD](https://github.com/RevanthR08/sem5MAD)
