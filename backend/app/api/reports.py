from fastapi import APIRouter, HTTPException, Query, Depends
from starlette.concurrency import run_in_threadpool
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta, timezone
import json

from backend.app.core.actor import Actor, get_actor, require_role, STAFF_ROLES
from backend.app.core.database import get_db
from backend.app.services.geo_engine import resolve_administrative_boundary, reverse_geocode_osm
from backend.app.services.routing_engine import route_civic_issue
from backend.app.services.duplicate_engine import find_nearby_duplicates
from backend.app.services.sla_engine import calculate_sla_status
from backend.app.services.workflow_engine import (
    transition_report_status, ReportNotFound, InvalidTransition
)

router = APIRouter(prefix="/reports", tags=["Reports"])

# Status changes each role may request through the generic status endpoint.
# Assignment, resolution and verification have their own endpoints.
STATUS_CHANGES_BY_ROLE = {
    "DEPARTMENT_OFFICER": {"ACKNOWLEDGED", "ROUTED", "REJECTED", "DUPLICATE"},
    "SUPER_ADMIN": {"ACKNOWLEDGED", "ROUTED", "REJECTED", "DUPLICATE"},
    "FIELD_WORKER": {"IN_PROGRESS", "BLOCKED"},
}

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
    reporter_name: Optional[str] = None
    reporter_contact: Optional[str] = None
    photo_urls: List[str] = []
    custom_fields: Dict[str, Any] = {}

class StatusUpdateDTO(BaseModel):
    status: str
    notes: Optional[str] = None

class AssignReportDTO(BaseModel):
    assigned_to: str
    notes: Optional[str] = None

class ResolveReportDTO(BaseModel):
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


def _run_transition(**kwargs) -> Dict[str, Any]:
    """Run a workflow transition, mapping engine errors to HTTP errors."""
    try:
        return transition_report_status(**kwargs)
    except ReportNotFound as e:
        raise HTTPException(status_code=404, detail=str(e))
    except InvalidTransition as e:
        raise HTTPException(status_code=409, detail=str(e))


def _known_user_id(cur, user_id: Optional[str]) -> Optional[str]:
    """Return user_id only if it exists, so foreign keys never fail on unknown callers."""
    if not user_id:
        return None
    cur.execute("SELECT id FROM users WHERE id::text = %s;", (user_id,))
    row = cur.fetchone()
    return str(row["id"]) if row else None


def _fetch_report_row(report_id: str) -> Dict[str, Any]:
    with get_db() as cur:
        cur.execute(
            "SELECT id, status, user_id, assigned_to FROM reports WHERE id::text = %s;",
            (report_id,),
        )
        row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Civic report not found.")
    return dict(row)


def _require_assigned_worker(report: Dict[str, Any], actor: Actor) -> None:
    assigned = report.get("assigned_to")
    if assigned and actor.user_id and str(assigned) != actor.user_id:
        raise HTTPException(status_code=403, detail="This work order is assigned to another field worker.")


@router.post("/upload-image")
def upload_image(dto: UploadImageDTO, actor: Actor = Depends(get_actor)):
    """Upload photo directly to Supabase Storage bucket 'images' and return public URL."""
    import base64
    import uuid
    import urllib.request
    from backend.app.core.config import settings

    require_role(actor, "CITIZEN", "FIELD_WORKER")
    try:
        # Strip header if present (e.g. data:image/jpeg;base64,...)
        raw_b64 = dto.base64_data
        if "," in raw_b64:
            raw_b64 = raw_b64.split(",", 1)[1]
        img_bytes = base64.b64decode(raw_b64)

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
        with urllib.request.urlopen(req):
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

def _save_report(dto: CreateReportDTO, boundary: Dict[str, Any], routing: Dict[str, Any],
                 address: str, reporter_name: str, user_id: Optional[str]) -> Dict[str, Any]:
    """Insert a routed report with its photos, timeline and reporter subscription."""
    with get_db() as cur:
        user_id = _known_user_id(cur, user_id)

        # Serialise ID generation so concurrent submissions never share a tracking ID
        now = datetime.now(timezone.utc)
        prefix = f"CC-{now.year}-"
        cur.execute("SELECT pg_advisory_xact_lock(hashtext('civic_connect_public_id'));")
        cur.execute("""
            SELECT COALESCE(MAX(CAST(split_part(public_id, '-', 3) AS INTEGER)), 1845) AS last_seq
            FROM reports
            WHERE public_id LIKE %s AND split_part(public_id, '-', 3) ~ '^[0-9]+$';
        """, (prefix + "%",))
        public_id = f"{prefix}{cur.fetchone()['last_seq'] + 1:05d}"

        sla_hours = routing["sla_hours"]
        sla_deadline = now + timedelta(hours=sla_hours)

        cur.execute("""
            INSERT INTO reports (
                public_id, user_id, is_anonymous, reporter_name, reporter_contact,
                category_id, subcategory_id, title, description, status, priority, severity,
                latitude, longitude, location, address, landmark,
                authority_id, department_id, zone_id, ward_id,
                custom_fields, sla_hours, sla_deadline, is_overdue
            ) VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, 'ROUTED', %s, %s,
                %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s,
                %s, %s, %s, %s,
                %s::jsonb, %s, %s, FALSE
            ) RETURNING id;
        """, (
            public_id, user_id, dto.is_anonymous, reporter_name, dto.reporter_contact,
            dto.category_id, dto.subcategory_id, dto.title, dto.description, routing["priority"], dto.severity,
            dto.latitude, dto.longitude, dto.longitude, dto.latitude, address, dto.landmark,
            boundary.get("authority_id"), routing.get("department_id"), boundary.get("zone_id"), boundary.get("ward_id"),
            json.dumps(dto.custom_fields), sla_hours, sla_deadline
        ))
        report_id = cur.fetchone()["id"]

        for p_url in dto.photo_urls:
            cur.execute("""
                INSERT INTO report_media (report_id, media_type, url, caption, stage)
                VALUES (%s, 'PHOTO', %s, 'Citizen submitted photo evidence', 'SUBMISSION');
            """, (report_id, p_url))

        cur.execute("""
            INSERT INTO report_timeline (
                report_id, actor_id, actor_name, actor_role, event_type, new_status, notes
            ) VALUES (%s, %s, %s, 'CITIZEN', 'REPORT_CREATED', 'SUBMITTED', 'Citizen filed new civic report');
        """, (report_id, user_id, "Anonymous" if dto.is_anonymous else reporter_name))

        cur.execute("""
            INSERT INTO report_timeline (
                report_id, actor_name, actor_role, event_type, old_status, new_status, notes
            ) VALUES (%s, 'GIS Civic Engine', 'SYSTEM', 'ROUTED', 'SUBMITTED', 'ROUTED', %s);
        """, (report_id, f"Automatically routed to {routing['department_name']} ({boundary.get('ward_name', 'Ward')})"))

        # The reporter automatically follows their own report
        if user_id:
            cur.execute("""
                INSERT INTO report_subscriptions (report_id, user_id) VALUES (%s, %s)
                ON CONFLICT (report_id, user_id) DO NOTHING;
            """, (report_id, user_id))

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


@router.post("")
async def create_report(dto: CreateReportDTO, actor: Actor = Depends(get_actor)):
    """
    Core guided report submission:
    1. Resolve boundary (Ward, Zone, Authority)
    2. Route to responsible Department & determine SLA
    3. Save to Supabase PostgreSQL with PostGIS location geometry
    4. Record immutable timeline entry
    """
    require_role(actor, "CITIZEN")

    # Blocking DB work runs in the threadpool so the event loop stays free
    boundary = await run_in_threadpool(resolve_administrative_boundary, dto.latitude, dto.longitude)
    address = dto.address
    if not address:
        geo = await reverse_geocode_osm(dto.latitude, dto.longitude)
        address = geo.get("address", f"{dto.latitude:.4f}, {dto.longitude:.4f}")

    routing = await run_in_threadpool(route_civic_issue, dto.category_id, dto.subcategory_id, boundary.get("ward_id"))
    return await run_in_threadpool(
        _save_report, dto, boundary, routing, address, dto.reporter_name or actor.name, actor.user_id
    )

@router.get("")
def list_reports(
    status: Optional[str] = Query(None, description="One status or a comma-separated list"),
    category_id: Optional[str] = None,
    ward_id: Optional[str] = None,
    department_id: Optional[str] = None,
    priority: Optional[str] = None,
    assigned_to: Optional[str] = None,
    user_id: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
):
    """List reports with rich filtering for Citizen map, Authority triage queue and Field Worker tasks."""
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
                r.assigned_to,
                r.user_id,
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
        statuses = [s.strip() for s in (status or "").split(",") if s.strip() and s.strip() != "ALL"]
        if statuses:
            query += " AND r.status = ANY(%s)"
            params.append(statuses)
        if category_id and category_id != "ALL":
            query += " AND r.category_id::text = %s"
            params.append(category_id)
        if ward_id and ward_id != "ALL":
            query += " AND r.ward_id::text = %s"
            params.append(ward_id)
        if department_id and department_id != "ALL":
            query += " AND r.department_id::text = %s"
            params.append(department_id)
        if priority and priority != "ALL":
            query += " AND r.priority = %s"
            params.append(priority)
        if assigned_to:
            query += " AND r.assigned_to::text = %s"
            params.append(assigned_to)
        if user_id:
            query += " AND r.user_id::text = %s"
            params.append(user_id)
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
        report.pop("location", None)  # raw PostGIS value, not JSON-friendly
        report_id = report["id"]

        cur.execute("""
            SELECT id, media_type, url, caption, is_resolution_proof, stage, created_at
            FROM report_media
            WHERE report_id = %s
            ORDER BY created_at ASC;
        """, (report_id,))
        report["media"] = [dict(m) for m in cur.fetchall()]

        cur.execute("""
            SELECT id, actor_name, actor_role, event_type, old_status, new_status, notes, media_url, created_at
            FROM report_timeline
            WHERE report_id = %s
            ORDER BY created_at ASC;
        """, (report_id,))
        report["timeline"] = [dict(t) for t in cur.fetchall()]

        report["thumbnail_url"] = next(
            (m["url"] for m in report["media"] if not m["is_resolution_proof"]), None
        )
        report["sla_info"] = calculate_sla_status(
            report["created_at"], report["sla_hours"], report["sla_deadline"], report["resolved_at"]
        )

        return report

@router.post("/{report_id}/status")
def update_report_status(report_id: str, dto: StatusUpdateDTO, actor: Actor = Depends(get_actor)):
    """Officer acknowledges/rejects, or field worker starts/blocks work."""
    allowed = STATUS_CHANGES_BY_ROLE.get(actor.role, set())
    if dto.status not in allowed:
        raise HTTPException(status_code=403, detail=f"Role {actor.role} cannot set status {dto.status}.")

    if actor.role == "FIELD_WORKER":
        _require_assigned_worker(_fetch_report_row(report_id), actor)

    with get_db() as cur:
        actor_id = _known_user_id(cur, actor.user_id)
    res = _run_transition(
        report_id=report_id,
        new_status=dto.status,
        actor_id=actor_id,
        actor_name=actor.name,
        actor_role=actor.role,
        notes=dto.notes,
    )
    return {"success": True, "data": res}

@router.post("/{report_id}/assign")
def assign_report(report_id: str, dto: AssignReportDTO, actor: Actor = Depends(get_actor)):
    """Officer assigns report to a field worker."""
    require_role(actor, *STAFF_ROLES)

    with get_db() as cur:
        cur.execute("""
            SELECT u.id, u.full_name, d.name AS department_name
            FROM users u LEFT JOIN departments d ON u.department_id = d.id
            WHERE u.id::text = %s AND u.role = 'FIELD_WORKER';
        """, (dto.assigned_to,))
        worker = cur.fetchone()
        actor_id = _known_user_id(cur, actor.user_id)
    if not worker:
        raise HTTPException(status_code=400, detail="assigned_to must be an existing field worker.")

    team = worker["full_name"]
    res = _run_transition(
        report_id=report_id,
        new_status="ASSIGNED",
        actor_id=actor_id,
        actor_name=actor.name,
        actor_role=actor.role,
        notes=dto.notes or f"Dispatched to {team}",
        assigned_to=str(worker["id"]),
        assigned_team=team,
    )
    return {"success": True, "message": f"Assigned to {team}", "data": res}

@router.post("/{report_id}/resolve")
def resolve_report(report_id: str, dto: ResolveReportDTO, actor: Actor = Depends(get_actor)):
    """Field Worker completes repair and submits resolution proof."""
    require_role(actor, "FIELD_WORKER")
    if not dto.resolution_notes.strip():
        raise HTTPException(status_code=422, detail="resolution_notes is required.")
    report = _fetch_report_row(report_id)
    _require_assigned_worker(report, actor)

    with get_db() as cur:
        actor_id = _known_user_id(cur, actor.user_id)
    res = _run_transition(
        report_id=report_id,
        new_status="RESOLUTION_SUBMITTED",
        actor_id=actor_id,
        actor_name=actor.name,
        actor_role=actor.role,
        notes="Field Worker completed repair work on site and uploaded proof.",
        resolution_notes=dto.resolution_notes,
        before_photo=dto.before_photo,
        after_photo=dto.after_photo
    )

    if dto.after_photo:
        with get_db() as cur:
            cur.execute("""
                INSERT INTO report_media (report_id, media_type, url, caption, is_resolution_proof, stage)
                VALUES (%s, 'PHOTO', %s, 'Resolution proof photo taken after repair', TRUE, 'AFTER_WORK');
            """, (report["id"], dto.after_photo))

    return {"success": True, "message": "Resolution submitted. Ready for Citizen Verification.", "data": res}

@router.post("/{report_id}/verify")
def citizen_verify_resolution(report_id: str, dto: VerifyReportDTO, actor: Actor = Depends(get_actor)):
    """
    Citizen Verification Loop:
    - 'Yes, fixed' -> Mark RESOLVED and archive.
    - 'No, still exists' -> REOPEN ticket with explanation.
    """
    require_role(actor, "CITIZEN")
    report = _fetch_report_row(report_id)
    if report["user_id"] and actor.user_id != str(report["user_id"]):
        raise HTTPException(status_code=403, detail="Only the citizen who filed this report can verify it.")

    new_status = "RESOLVED" if dto.is_fixed else "REOPENED"
    notes = (
        f"Citizen confirmed resolution: '{dto.feedback or 'Issue is fully resolved'}'"
        if dto.is_fixed
        else f"Citizen reported issue still exists! Feedback: '{dto.feedback or 'Problem not fixed correctly'}'"
    )

    with get_db() as cur:
        actor_id = _known_user_id(cur, actor.user_id)
    _run_transition(
        report_id=report_id,
        new_status=new_status,
        actor_id=actor_id,
        actor_name=actor.name,
        actor_role="CITIZEN",
        notes=notes
    )

    with get_db() as cur:
        cur.execute("""
            UPDATE reports SET citizen_verified = %s, citizen_feedback = %s WHERE id = %s;
        """, (dto.is_fixed, dto.feedback, report["id"]))

    return {
        "success": True,
        "status": new_status,
        "message": "Thank you for verifying the civic resolution!" if dto.is_fixed else "Ticket reopened and sent back to the officer."
    }

@router.post("/{report_id}/upvote")
def upvote_report(report_id: str, actor: Actor = Depends(get_actor)):
    """Citizen upvotes / subscribes to existing issue instead of creating duplicate (once per citizen)."""
    require_role(actor, "CITIZEN")
    with get_db() as cur:
        cur.execute("SELECT id, upvotes, public_id FROM reports WHERE id::text = %s;", (report_id,))
        rep = cur.fetchone()
        if not rep:
            raise HTTPException(status_code=404, detail="Civic report not found.")

        user_id = _known_user_id(cur, actor.user_id)
        if user_id:
            cur.execute("""
                INSERT INTO report_subscriptions (report_id, user_id) VALUES (%s, %s)
                ON CONFLICT (report_id, user_id) DO NOTHING RETURNING id;
            """, (rep["id"], user_id))
            if cur.fetchone() is None:
                return {"success": True, "already_upvoted": True, "upvotes": rep["upvotes"], "public_id": rep["public_id"]}

        cur.execute("UPDATE reports SET upvotes = upvotes + 1 WHERE id = %s RETURNING upvotes, public_id;", (rep["id"],))
        row = cur.fetchone()
        return {"success": True, "already_upvoted": False, "upvotes": row["upvotes"], "public_id": row["public_id"]}


# Realistic field jobs handed to a field worker on request, so demos always
# have work to show. Filed under the demo citizen account so the citizen can
# verify the repair and close the loop.
DEMO_CITIZEN_ID = "10000000-0000-0000-0000-000000000001"
DEMO_FIELD_TASKS = [
    ("roads", "pothole", "Pothole near bus stop", "Deep pothole collecting rainwater where commuters step off the bus.",
     13.0336, 80.2677, "Luz Church Road, Mylapore", "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?w=800"),
    ("lighting", "light_out", "Streetlight not working", "Three consecutive streetlights are dark, making the lane unsafe at night.",
     13.0418, 80.2507, "Cathedral Road, Teynampet", "https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=800"),
    ("waste", "garbage_overflow", "Overflowing garbage bin", "Bin overflowing onto the footpath, stray animals scattering waste.",
     13.0440, 80.2560, "TTK Road, Alwarpet", "https://images.unsplash.com/photo-1605600659873-d808a13e4d2a?w=800"),
    ("drainage", "blocked_drain", "Clogged stormwater drain", "Drain inlet blocked with silt and plastic, water stagnating on the road.",
     13.0405, 80.2337, "Usman Road, T. Nagar", "https://images.unsplash.com/photo-1547683905-f686c993aae5?w=800"),
    ("safety", "fallen_tree", "Tree branch blocking road", "Large branch fell after the storm and is blocking one lane.",
     13.0500, 80.2450, "Eldams Road, Teynampet", "https://images.unsplash.com/photo-1527482797697-8795b05a13fe?w=800"),
]


@router.post("/demo/field-task")
def create_demo_field_task(actor: Actor = Depends(get_actor)):
    """Field worker demo helper: create a realistic report and assign it to the caller."""
    import random

    require_role(actor, "FIELD_WORKER")
    with get_db() as cur:
        cur.execute("SELECT id, full_name FROM users WHERE id::text = %s AND role = 'FIELD_WORKER';", (actor.user_id,))
        worker = cur.fetchone()
        if not worker:
            raise HTTPException(status_code=403, detail="Sign in with a field worker account to get demo tasks.")

        cat_code, sub_code, title, desc, lat, lng, address, photo = random.choice(DEMO_FIELD_TASKS)
        cur.execute("""
            SELECT c.id AS category_id, s.id AS subcategory_id
            FROM categories c LEFT JOIN subcategories s ON s.category_id = c.id AND s.code = %s
            WHERE c.code = %s;
        """, (sub_code, cat_code))
        cat = cur.fetchone()
        if not cat:
            raise HTTPException(status_code=500, detail="Categories are not seeded.")

    # Small offset so repeated demo tasks don't stack on one map pin
    lat += random.uniform(-0.004, 0.004)
    lng += random.uniform(-0.004, 0.004)
    dto = CreateReportDTO(
        title=title, description=desc,
        category_id=str(cat["category_id"]),
        subcategory_id=str(cat["subcategory_id"]) if cat["subcategory_id"] else None,
        latitude=lat, longitude=lng, address=address, severity="HIGH",
        photo_urls=[photo],
    )
    boundary = resolve_administrative_boundary(lat, lng)
    routing = route_civic_issue(dto.category_id, dto.subcategory_id, boundary.get("ward_id"))
    created = _save_report(dto, boundary, routing, address, "Revanth Citizen", DEMO_CITIZEN_ID)

    _run_transition(
        report_id=created["id"],
        new_status="ASSIGNED",
        actor_name="Demo Dispatcher",
        actor_role="SYSTEM",
        notes=f"Demo task dispatched to {worker['full_name']}",
        assigned_to=str(worker["id"]),
        assigned_team=worker["full_name"],
    )
    created["status"] = "ASSIGNED"
    return created
