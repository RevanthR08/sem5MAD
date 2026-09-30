from fastapi import APIRouter, HTTPException, Query, Body
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta, timezone
import random

from backend.app.core.database import get_db
from backend.app.services.geo_engine import resolve_administrative_boundary, reverse_geocode_osm
from backend.app.services.routing_engine import route_civic_issue
from backend.app.services.duplicate_engine import find_nearby_duplicates
from backend.app.services.sla_engine import calculate_sla_status
from backend.app.services.workflow_engine import transition_report_status

router = APIRouter(prefix="/reports", tags=["Reports"])

class CreateReportDTO(BaseModel):
    title: str
    description: str
    category_id: str
    subcategory_id: Optional[str] = None
    latitude: float
    longitude: float
    address: Optional[str] = None
    landmark: Optional[str] = None
    severity: str = "MEDIUM"
    is_anonymous: bool = False
    reporter_name: Optional[str] = "Revanth Citizen"
    reporter_contact: Optional[str] = "+919876543210"
    photo_urls: List[str] = []
    custom_fields: Dict[str, Any] = {}

class StatusUpdateDTO(BaseModel):
    status: str
    actor_id: Optional[str] = None
    actor_name: str = "Officer Rajesh V"
    actor_role: str = "DEPARTMENT_OFFICER"
    notes: Optional[str] = None
    assigned_to: Optional[str] = None
    assigned_team: Optional[str] = None
    department_id: Optional[str] = None

class ResolveReportDTO(BaseModel):
    actor_name: str = "Field Worker Murugan S"
    resolution_notes: str
    before_photo: Optional[str] = None
    after_photo: Optional[str] = None

class VerifyReportDTO(BaseModel):
    is_fixed: bool
    feedback: Optional[str] = None

class UploadImageDTO(BaseModel):
    base64_data: str
    filename: Optional[str] = "civic_photo.jpg"
    content_type: Optional[str] = "image/jpeg"

@router.post("/upload-image")
def upload_image(dto: UploadImageDTO):
    """Upload photo directly to Supabase Storage bucket 'images' and return public URL."""
    import base64
    import uuid
    import urllib.request
    from backend.app.core.config import settings

    try:
        # Strip header if present (e.g. data:image/jpeg;base64,...)
        raw_b64 = dto.base64_data
        if "," in raw_b64:
            raw_b64 = raw_b64.split(",", 1)[1]
        img_bytes = base64.b64decode(raw_b64)

        # Generate unique file key
        unique_name = f"{uuid.uuid4().hex[:12]}_{dto.filename or 'photo.jpg'}"
        upload_url = f"{settings.SUPABASE_URL}/storage/v1/object/images/{unique_name}"

        req = urllib.request.Request(
            upload_url,
            data=img_bytes,
            headers={
                "apikey": settings.SUPABASE_SECRET_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SECRET_KEY}",
                "Content-Type": dto.content_type or "image/jpeg"
            },
            method="POST"
        )
        with urllib.request.urlopen(req) as resp:
            pass

        public_url = f"{settings.SUPABASE_URL}/storage/v1/object/public/images/{unique_name}"
        return {"success": True, "url": public_url, "filename": unique_name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image upload to Supabase failed: {str(e)}")

@router.get("/duplicates")
def check_duplicates(lat: float = Query(...), lng: float = Query(...), category_id: str = Query(...)):
    """Check for active nearby duplicates before report submission."""
    dups = find_nearby_duplicates(lat, lng, category_id)
    return {
        "found_duplicates": len(dups) > 0,
        "count": len(dups),
        "duplicates": dups
    }

@router.post("")
async def create_report(dto: CreateReportDTO):
    """
    Core guided report submission:
    1. Resolve boundary (Ward, Zone, Authority)
    2. Route to responsible Department & determine SLA
    3. Save to Supabase PostgreSQL with PostGIS location geometry
    4. Record immutable timeline entry
    """
    # Boundary resolution
    boundary = resolve_administrative_boundary(dto.latitude, dto.longitude)
    address = dto.address
    if not address:
        geo = await reverse_geocode_osm(dto.latitude, dto.longitude)
        address = geo.get("address", f"{dto.latitude:.4f}, {dto.longitude:.4f}")

    # Department routing
    routing = route_civic_issue(dto.category_id, dto.subcategory_id, boundary.get("ward_id"))
    
    # Public ID generation (CC-2026-XXXXX)
    with get_db() as cur:
        cur.execute("SELECT COUNT(*) FROM reports;")
        count = cur.fetchone()["count"]
        public_id = f"CC-2026-{1846 + count:05d}"
        
        now = datetime.now(timezone.utc)
        sla_hours = routing["sla_hours"]
        sla_deadline = now + timedelta(hours=sla_hours)
        
        # Insert report
        cur.execute("""
            INSERT INTO reports (
                public_id, is_anonymous, reporter_name, reporter_contact,
                category_id, subcategory_id, title, description, status, priority, severity,
                latitude, longitude, location, address, landmark,
                authority_id, department_id, zone_id, ward_id,
                custom_fields, sla_hours, sla_deadline, is_overdue
            ) VALUES (
                %s, %s, %s, %s,
                %s, %s, %s, %s, 'SUBMITTED', %s, %s,
                %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s,
                %s, %s, %s, %s,
                %s::jsonb, %s, %s, FALSE
            ) RETURNING id, public_id, status, created_at;
        """, (
            public_id, dto.is_anonymous, dto.reporter_name, dto.reporter_contact,
            dto.category_id, dto.subcategory_id, dto.title, dto.description, routing["priority"], dto.severity,
            dto.latitude, dto.longitude, dto.longitude, dto.latitude, address, dto.landmark,
            boundary.get("authority_id"), routing.get("department_id"), boundary.get("zone_id"), boundary.get("ward_id"),
            import_json(dto.custom_fields), sla_hours, sla_deadline
        ))
        created = cur.fetchone()
        report_id = created["id"]
        
        # Save photo media
        for p_url in dto.photo_urls:
            cur.execute("""
                INSERT INTO report_media (report_id, media_type, url, caption, stage)
                VALUES (%s, 'PHOTO', %s, 'Citizen submitted photo evidence', 'SUBMISSION');
            """, (report_id, p_url))
            
        # Initial timeline event
        cur.execute("""
            INSERT INTO report_timeline (
                report_id, actor_name, actor_role, event_type, new_status, notes
            ) VALUES (%s, %s, 'CITIZEN', 'REPORT_CREATED', 'SUBMITTED', 'Citizen filed new civic report');
        """, (report_id, dto.reporter_name or "Anonymous"))
        
        # Automatic routing timeline event
        cur.execute("""
            INSERT INTO report_timeline (
                report_id, actor_name, actor_role, event_type, old_status, new_status, notes
            ) VALUES (%s, 'GIS Civic Engine', 'SYSTEM', 'ROUTED', 'SUBMITTED', 'ROUTED', %s);
        """, (report_id, f"Automatically routed to {routing['department_name']} ({boundary.get('ward_name', 'Ward')})"))
        
        # Update status to ROUTED
        cur.execute("UPDATE reports SET status = 'ROUTED' WHERE id = %s;", (report_id,))

    return {
        "success": True,
        "id": str(report_id),
        "public_id": public_id,
        "status": "ROUTED",
        "routed_department": routing["department_name"],
        "ward": boundary.get("ward_name"),
        "sla_hours": sla_hours,
        "message": f"Report {public_id} submitted and forwarded to {routing['department_name']}."
    }

def import_json(val):
    import json
    return json.dumps(val)

@router.get("")
def list_reports(
    status: Optional[str] = None,
    category_id: Optional[str] = None,
    ward_id: Optional[str] = None,
    department_id: Optional[str] = None,
    priority: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
):
    """List reports with rich filtering for Citizen map and Authority triage queue."""
    with get_db() as cur:
        query = """
            SELECT 
                r.id,
                r.public_id,
                r.title,
                r.description,
                r.status,
                r.priority,
                r.severity,
                r.latitude,
                r.longitude,
                r.address,
                r.landmark,
                r.created_at,
                r.updated_at,
                r.resolved_at,
                r.sla_hours,
                r.sla_deadline,
                r.assigned_team,
                r.upvotes,
                r.citizen_verified,
                c.id as category_id,
                c.name as category_name,
                c.icon as category_icon,
                sc.name as subcategory_name,
                d.name as department_name,
                d.code as department_code,
                w.ward_number,
                w.name as ward_name,
                (SELECT url FROM report_media rm WHERE rm.report_id = r.id AND rm.is_resolution_proof = FALSE LIMIT 1) as thumbnail_url,
                (SELECT url FROM report_media rm WHERE rm.report_id = r.id AND rm.stage = 'AFTER_WORK' LIMIT 1) as after_photo_url
            FROM reports r
            JOIN categories c ON r.category_id = c.id
            LEFT JOIN subcategories sc ON r.subcategory_id = sc.id
            LEFT JOIN departments d ON r.department_id = d.id
            LEFT JOIN wards w ON r.ward_id = w.id
            WHERE 1=1
        """
        params = []
        if status and status != "ALL":
            query += " AND r.status = %s"
            params.append(status)
        if category_id and category_id != "ALL":
            query += " AND r.category_id = %s"
            params.append(category_id)
        if ward_id and ward_id != "ALL":
            query += " AND r.ward_id = %s"
            params.append(ward_id)
        if department_id and department_id != "ALL":
            query += " AND r.department_id = %s"
            params.append(department_id)
        if priority and priority != "ALL":
            query += " AND r.priority = %s"
            params.append(priority)
        if search:
            query += " AND (r.title ILIKE %s OR r.description ILIKE %s OR r.public_id ILIKE %s OR r.address ILIKE %s)"
            s_param = f"%{search}%"
            params.extend([s_param, s_param, s_param, s_param])
            
        query += " ORDER BY r.created_at DESC LIMIT %s OFFSET %s;"
        params.extend([limit, offset])
        
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        
        results = []
        for row in rows:
            item = dict(row)
            item["sla_info"] = calculate_sla_status(
                item["created_at"], item["sla_hours"], item["sla_deadline"], item["resolved_at"]
            )
            results.append(item)
            
        return results

@router.get("/nearby")
def get_nearby_reports(lat: float = Query(...), lng: float = Query(...), radius_meters: int = Query(5000)):
    """Get active civic issues within radius meters using PostGIS distance."""
    with get_db() as cur:
        query = """
            SELECT 
                r.id,
                r.public_id,
                r.title,
                r.description,
                r.status,
                r.priority,
                r.latitude,
                r.longitude,
                r.address,
                r.created_at,
                c.name as category_name,
                c.icon as category_icon,
                ROUND(ST_Distance(
                    r.location, 
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
                )::numeric, 1) as distance_meters,
                (SELECT url FROM report_media rm WHERE rm.report_id = r.id LIMIT 1) as thumbnail_url
            FROM reports r
            JOIN categories c ON r.category_id = c.id
            WHERE ST_DWithin(
                r.location, 
                ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography, 
                %s
            )
            ORDER BY distance_meters ASC
            LIMIT 50;
        """
        cur.execute(query, (lng, lat, lng, lat, radius_meters))
        return [dict(r) for r in cur.fetchall()]

@router.get("/{report_id_or_public_id}")
def get_report_detail(report_id_or_public_id: str):
    """Retrieve complete report with timeline, photos, SLA, and verification data."""
    with get_db() as cur:
        query = """
            SELECT 
                r.*,
                c.name as category_name,
                c.icon as category_icon,
                sc.name as subcategory_name,
                d.name as department_name,
                d.email as department_email,
                w.ward_number,
                w.name as ward_name,
                z.name as zone_name,
                a.name as authority_name,
                u.full_name as assigned_officer_name
            FROM reports r
            JOIN categories c ON r.category_id = c.id
            LEFT JOIN subcategories sc ON r.subcategory_id = sc.id
            LEFT JOIN departments d ON r.department_id = d.id
            LEFT JOIN wards w ON r.ward_id = w.id
            LEFT JOIN zones z ON r.zone_id = z.id
            LEFT JOIN authorities a ON r.authority_id = a.id
            LEFT JOIN users u ON r.assigned_to = u.id
            WHERE r.id::text = %s OR r.public_id = %s;
        """
        cur.execute(query, (report_id_or_public_id, report_id_or_public_id))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Civic report not found.")
            
        report = dict(row)
        report_id = report["id"]
        
        # Fetch media
        cur.execute("""
            SELECT id, media_type, url, caption, is_resolution_proof, stage, created_at
            FROM report_media
            WHERE report_id = %s
            ORDER BY created_at ASC;
        """, (report_id,))
        report["media"] = [dict(m) for m in cur.fetchall()]
        
        # Fetch timeline
        cur.execute("""
            SELECT id, actor_name, actor_role, event_type, old_status, new_status, notes, media_url, created_at
            FROM report_timeline
            WHERE report_id = %s
            ORDER BY created_at ASC;
        """, (report_id,))
        report["timeline"] = [dict(t) for t in cur.fetchall()]
        
        # SLA calculation
        report["sla_info"] = calculate_sla_status(
            report["created_at"], report["sla_hours"], report["sla_deadline"], report["resolved_at"]
        )
        
        return report

@router.post("/{report_id}/status")
def update_report_status(report_id: str, dto: StatusUpdateDTO):
    """Authority or Admin updates report status, assigns staff, or adds note."""
    res = transition_report_status(
        report_id=report_id,
        new_status=dto.status,
        actor_id=dto.actor_id,
        actor_name=dto.actor_name,
        actor_role=dto.actor_role,
        notes=dto.notes,
        assigned_to=dto.assigned_to,
        assigned_team=dto.assigned_team,
        department_id=dto.department_id
    )
    return {"success": True, "data": res}

@router.post("/{report_id}/assign")
def assign_report(report_id: str, body: Dict[str, Any] = Body(...)):
    """Assign report to field team or officer."""
    team = body.get("assigned_team", "Rapid Response Team")
    worker_id = body.get("assigned_to", "10000000-0000-0000-0000-000000000003")
    notes = body.get("notes", f"Assigned to {team}")
    
    res = transition_report_status(
        report_id=report_id,
        new_status="ASSIGNED",
        actor_name="Dispatcher Rajesh V",
        actor_role="DEPARTMENT_OFFICER",
        notes=notes,
        assigned_to=worker_id,
        assigned_team=team
    )
    return {"success": True, "message": f"Assigned to {team}", "data": res}

@router.post("/{report_id}/resolve")
def resolve_report(report_id: str, dto: ResolveReportDTO):
    """Field Worker completes repair and submits resolution proof."""
    res = transition_report_status(
        report_id=report_id,
        new_status="RESOLUTION_SUBMITTED",
        actor_name=dto.actor_name,
        actor_role="FIELD_WORKER",
        notes="Field Worker completed repair work on site and uploaded proof.",
        resolution_notes=dto.resolution_notes,
        before_photo=dto.before_photo,
        after_photo=dto.after_photo
    )
    
    # Also save after photo into media
    if dto.after_photo:
        with get_db() as cur:
            cur.execute("""
                INSERT INTO report_media (report_id, media_type, url, caption, is_resolution_proof, stage)
                VALUES (%s, 'PHOTO', %s, 'Resolution proof photo taken after repair', TRUE, 'AFTER_WORK');
            """, (report_id, dto.after_photo))
            
    return {"success": True, "message": "Resolution submitted. Ready for Citizen Verification.", "data": res}

@router.post("/{report_id}/verify")
def citizen_verify_resolution(report_id: str, dto: VerifyReportDTO):
    """
    Citizen Verification Loop (Section 23 in Blueprint):
    Citizen checks repaired work:
    - 'Yes, fixed' -> Mark RESOLVED and archive.
    - 'No, still exists' -> REOPEN ticket with explanation and escalate!
    """
    new_status = "RESOLVED" if dto.is_fixed else "REOPENED"
    notes = (
        f"Citizen confirmed resolution: '{dto.feedback or 'Issue is fully resolved'}'" 
        if dto.is_fixed 
        else f"Citizen reported issue still exists! Feedback: '{dto.feedback or 'Problem not fixed correctly'}'"
    )
    
    with get_db() as cur:
        cur.execute("""
            UPDATE reports
            SET citizen_verified = %s,
                citizen_feedback = %s
            WHERE id = %s;
        """, (dto.is_fixed, dto.feedback, report_id))
        
    res = transition_report_status(
        report_id=report_id,
        new_status=new_status,
        actor_name="Revanth (Citizen)",
        actor_role="CITIZEN",
        notes=notes
    )
    return {
        "success": True, 
        "status": new_status,
        "message": "Thank you for verifying the civic resolution!" if dto.is_fixed else "Ticket reopened and escalated for re-inspection."
    }

@router.post("/{report_id}/upvote")
def upvote_report(report_id: str):
    """Citizen upvotes / subscribes to existing issue instead of creating duplicate."""
    with get_db() as cur:
        cur.execute("UPDATE reports SET upvotes = upvotes + 1 WHERE id = %s RETURNING upvotes, public_id;", (report_id,))
        row = cur.fetchone()
        return {"success": True, "upvotes": row["upvotes"], "public_id": row["public_id"]}
