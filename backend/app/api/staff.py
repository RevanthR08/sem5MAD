from fastapi import APIRouter
from backend.app.core.database import get_db

router = APIRouter(prefix="/staff", tags=["Staff & Management"])

@router.get("/departments")
def list_departments():
    with get_db() as cur:
        cur.execute("""
            SELECT d.id, d.code, d.name, d.email, d.head_officer_name,
                   (SELECT COUNT(*) FROM reports r WHERE r.department_id = d.id AND r.status NOT IN ('RESOLVED', 'REJECTED')) as active_tickets
            FROM departments d
            ORDER BY d.name ASC;
        """)
        return cur.fetchall()

@router.get("/wards")
def list_wards():
    with get_db() as cur:
        cur.execute("""
            SELECT w.id, w.ward_number, w.name, w.center_lat, w.center_lng, z.name as zone_name
            FROM wards w
            JOIN zones z ON w.zone_id = z.id
            ORDER BY w.ward_number ASC;
        """)
        return cur.fetchall()

@router.get("/workers")
def list_workers():
    with get_db() as cur:
        cur.execute("""
            SELECT u.id, u.full_name, u.role, u.phone, u.avatar_url, d.name as department_name,
                   (SELECT COUNT(*) FROM reports r WHERE r.assigned_to = u.id AND r.status IN ('ASSIGNED', 'IN_PROGRESS')) as active_jobs
            FROM users u
            LEFT JOIN departments d ON u.department_id = d.id
            WHERE u.role IN ('FIELD_WORKER', 'DEPARTMENT_OFFICER')
            ORDER BY u.full_name ASC;
        """)
        return cur.fetchall()
