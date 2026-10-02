from typing import Dict, Any, Optional
from datetime import datetime, timezone
from backend.app.core.database import get_db

ALLOWED_TRANSITIONS = {
    "SUBMITTED": ["VALIDATING", "ROUTED", "REJECTED", "DUPLICATE"],
    "VALIDATING": ["ROUTED", "REJECTED", "DUPLICATE"],
    "ROUTED": ["ACKNOWLEDGED", "ASSIGNED", "REJECTED", "DUPLICATE"],
    "ACKNOWLEDGED": ["ASSIGNED", "ROUTED", "REJECTED"],
    "ASSIGNED": ["IN_PROGRESS", "ASSIGNED", "ROUTED"],
    "IN_PROGRESS": ["RESOLUTION_SUBMITTED", "BLOCKED", "ASSIGNED"],
    "BLOCKED": ["IN_PROGRESS", "ASSIGNED"],
    "RESOLUTION_SUBMITTED": ["CITIZEN_VERIFICATION", "RESOLVED", "REOPENED"],
    "CITIZEN_VERIFICATION": ["RESOLVED", "REOPENED"],
    "RESOLVED": ["REOPENED"],
    "REOPENED": ["ACKNOWLEDGED", "ASSIGNED", "ROUTED"],
    "REJECTED": [],
    "DUPLICATE": []
}


class ReportNotFound(LookupError):
    pass


class InvalidTransition(ValueError):
    pass


def transition_report_status(
    report_id: str,
    new_status: str,
    actor_id: Optional[str] = None,
    actor_name: str = "System",
    actor_role: str = "SYSTEM",
    notes: Optional[str] = None,
    resolution_notes: Optional[str] = None,
    before_photo: Optional[str] = None,
    after_photo: Optional[str] = None,
    assigned_to: Optional[str] = None,
    assigned_team: Optional[str] = None,
    department_id: Optional[str] = None
) -> Dict[str, Any]:
    """Execute status transition, validate rules, and log immutable timeline entry."""
    with get_db() as cur:
        # Lock the row so two concurrent transitions cannot both pass validation
        cur.execute("SELECT status, public_id FROM reports WHERE id::text = %s FOR UPDATE;", (report_id,))
        rep = cur.fetchone()
        if not rep:
            raise ReportNotFound(f"Report {report_id} not found.")

        old_status = rep["status"]
        if new_status not in ALLOWED_TRANSITIONS.get(old_status, []):
            raise InvalidTransition(f"Cannot move report from {old_status} to {new_status}.")

        now = datetime.now(timezone.utc)
        update_fields = ["status = %s", "updated_at = %s"]
        params = [new_status, now]

        # resolved_at marks when the repair was completed (stops the SLA clock);
        # a reopen restarts it.
        if new_status == "RESOLUTION_SUBMITTED":
            update_fields.append("resolved_at = %s")
            params.append(now)
        elif new_status == "RESOLVED":
            update_fields.append("resolved_at = COALESCE(resolved_at, %s)")
            params.append(now)
            update_fields.append("closed_at = %s")
            params.append(now)
        elif new_status == "REOPENED":
            update_fields.append("resolved_at = NULL")
            update_fields.append("closed_at = NULL")

        if resolution_notes:
            update_fields.append("resolution_notes = %s")
            params.append(resolution_notes)
        if before_photo:
            update_fields.append("resolution_before_photo = %s")
            params.append(before_photo)
        if after_photo:
            update_fields.append("resolution_after_photo = %s")
            params.append(after_photo)
        if assigned_to:
            update_fields.append("assigned_to = %s")
            params.append(assigned_to)
        if assigned_team:
            update_fields.append("assigned_team = %s")
            params.append(assigned_team)
        if department_id:
            update_fields.append("department_id = %s")
            params.append(department_id)

        params.append(report_id)
        sql = f"UPDATE reports SET {', '.join(update_fields)} WHERE id::text = %s RETURNING id, public_id, status;"
        cur.execute(sql, tuple(params))
        updated = cur.fetchone()

        # Log to immutable timeline
        cur.execute("""
            INSERT INTO report_timeline (
                report_id, actor_id, actor_name, actor_role,
                event_type, old_status, new_status, notes, media_url
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
        """, (
            updated["id"], actor_id, actor_name, actor_role,
            f"STATUS_{new_status}", old_status, new_status,
            notes or f"Status updated to {new_status}", after_photo or before_photo
        ))

        return dict(updated)
