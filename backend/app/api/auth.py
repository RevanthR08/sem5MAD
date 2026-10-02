import re
from typing import Optional
import psycopg2
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

from backend.app.core.actor import ROLE_ALIASES, Actor, get_actor
from backend.app.core.database import get_db
from backend.app.core.security import hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Roles a person may choose when registering. Admin accounts are created by
# the platform (see seed_data.py), never through public sign-up.
REGISTRABLE_ROLES = {"CITIZEN", "DEPARTMENT_OFFICER", "FIELD_WORKER"}
STAFF_ROLES = {"DEPARTMENT_OFFICER", "FIELD_WORKER"}

# Database role -> role code used by the mobile app
APP_ROLE = {"CITIZEN": "CITIZEN", "DEPARTMENT_OFFICER": "OFFICER", "FIELD_WORKER": "FIELD_WORKER", "SUPER_ADMIN": "ADMIN"}

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class RegisterDTO(BaseModel):
    full_name: str
    email: str
    password: str
    role: str
    phone: Optional[str] = None
    department_id: Optional[str] = None


class LoginDTO(BaseModel):
    email: str
    password: str


def _user_payload(row) -> dict:
    return {
        "id": str(row["id"]),
        "full_name": row["full_name"],
        "email": row["email"],
        "phone": row["phone"],
        "role": APP_ROLE.get(row["role"], "CITIZEN"),
        "department_id": str(row["department_id"]) if row["department_id"] else None,
        "department_name": row["department_name"],
    }


_USER_SELECT = """
    SELECT u.id, u.full_name, u.email, u.phone, u.role, u.department_id, u.password_hash,
           d.name AS department_name
    FROM users u LEFT JOIN departments d ON u.department_id = d.id
"""


@router.post("/register")
def register(dto: RegisterDTO):
    full_name = dto.full_name.strip()
    email = dto.email.strip().lower()
    phone = (dto.phone or "").strip() or None
    role = ROLE_ALIASES.get(dto.role.strip().upper())

    if len(full_name) < 2:
        raise HTTPException(status_code=422, detail="Please enter your full name.")
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=422, detail="Please enter a valid email address.")
    if len(dto.password) < 6:
        raise HTTPException(status_code=422, detail="Password must be at least 6 characters.")
    if role not in REGISTRABLE_ROLES:
        raise HTTPException(status_code=422, detail="Choose Citizen, Department Officer or Field Worker.")
    if role in STAFF_ROLES and not dto.department_id:
        raise HTTPException(status_code=422, detail="Officers and field workers must choose their department.")

    with get_db() as cur:
        department_id, authority_id = None, None
        if role in STAFF_ROLES:
            cur.execute("SELECT id, authority_id FROM departments WHERE id::text = %s;", (dto.department_id,))
            dept = cur.fetchone()
            if not dept:
                raise HTTPException(status_code=422, detail="Unknown department.")
            department_id, authority_id = dept["id"], dept["authority_id"]
        else:
            cur.execute("SELECT id FROM authorities ORDER BY created_at LIMIT 1;")
            auth = cur.fetchone()
            authority_id = auth["id"] if auth else None

        cur.execute("SELECT 1 FROM users WHERE lower(email) = %s OR (%s::text IS NOT NULL AND phone = %s);", (email, phone, phone))
        if cur.fetchone():
            raise HTTPException(status_code=409, detail="An account with this email or phone already exists.")

        try:
            cur.execute("""
                INSERT INTO users (email, phone, full_name, role, department_id, authority_id, password_hash)
                VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id;
            """, (email, phone, full_name, role, department_id, authority_id, hash_password(dto.password)))
        except psycopg2.errors.UniqueViolation:
            raise HTTPException(status_code=409, detail="An account with this email or phone already exists.")
        user_id = cur.fetchone()["id"]

        cur.execute(_USER_SELECT + " WHERE u.id = %s;", (user_id,))
        return {"success": True, "user": _user_payload(cur.fetchone())}


@router.post("/login")
def login(dto: LoginDTO):
    with get_db() as cur:
        cur.execute(_USER_SELECT + " WHERE lower(u.email) = %s;", (dto.email.strip().lower(),))
        row = cur.fetchone()
    if not row or not verify_password(dto.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect email or password.")
    return {"success": True, "user": _user_payload(row)}


class ProfileUpdateDTO(BaseModel):
    full_name: str
    phone: Optional[str] = None


class PasswordChangeDTO(BaseModel):
    current_password: str
    new_password: str


def _current_user(cur, actor: Actor):
    cur.execute(_USER_SELECT + " WHERE u.id::text = %s;", (actor.user_id,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Please sign in again.")
    return row


@router.get("/me")
def get_profile(actor: Actor = Depends(get_actor)):
    """Profile plus activity numbers for the signed-in user's role."""
    with get_db() as cur:
        row = _current_user(cur, actor)
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE user_id = %(id)s) AS reports_filed,
                COUNT(*) FILTER (WHERE user_id = %(id)s AND status = 'RESOLVED') AS reports_resolved,
                COUNT(*) FILTER (WHERE assigned_to = %(id)s AND status IN ('ASSIGNED', 'IN_PROGRESS', 'BLOCKED')) AS active_jobs,
                COUNT(*) FILTER (WHERE assigned_to = %(id)s AND status IN ('RESOLUTION_SUBMITTED', 'RESOLVED')) AS completed_jobs
            FROM reports;
        """, {"id": row["id"]})
        stats = cur.fetchone()
        cur.execute("SELECT COUNT(*) AS actions FROM report_timeline WHERE actor_id = %s;", (row["id"],))
        stats["timeline_actions"] = cur.fetchone()["actions"]
        cur.execute("SELECT created_at FROM users WHERE id = %s;", (row["id"],))
        member_since = cur.fetchone()["created_at"]
    return {"user": _user_payload(row), "stats": dict(stats), "member_since": member_since}


@router.put("/me")
def update_profile(dto: ProfileUpdateDTO, actor: Actor = Depends(get_actor)):
    full_name = dto.full_name.strip()
    phone = (dto.phone or "").strip() or None
    if len(full_name) < 2:
        raise HTTPException(status_code=422, detail="Please enter your full name.")
    with get_db() as cur:
        row = _current_user(cur, actor)
        if phone:
            cur.execute("SELECT 1 FROM users WHERE phone = %s AND id <> %s;", (phone, row["id"]))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="This phone number is used by another account.")
        cur.execute("UPDATE users SET full_name = %s, phone = %s WHERE id = %s;", (full_name, phone, row["id"]))
        cur.execute(_USER_SELECT + " WHERE u.id = %s;", (row["id"],))
        return {"success": True, "user": _user_payload(cur.fetchone())}


@router.post("/me/password")
def change_password(dto: PasswordChangeDTO, actor: Actor = Depends(get_actor)):
    if len(dto.new_password) < 6:
        raise HTTPException(status_code=422, detail="New password must be at least 6 characters.")
    with get_db() as cur:
        row = _current_user(cur, actor)
        if not verify_password(dto.current_password, row["password_hash"]):
            raise HTTPException(status_code=403, detail="Current password is incorrect.")
        cur.execute("UPDATE users SET password_hash = %s WHERE id = %s;", (hash_password(dto.new_password), row["id"]))
    return {"success": True}
