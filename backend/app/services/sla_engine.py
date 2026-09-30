from datetime import datetime, timezone
from typing import Dict, Any, Optional

def calculate_sla_status(created_at: datetime, sla_hours: int, sla_deadline: Optional[datetime], resolved_at: Optional[datetime]) -> Dict[str, Any]:
    """Calculate real-time SLA metrics for a report."""
    now = datetime.now(timezone.utc)
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
        
    deadline = sla_deadline
    if deadline and deadline.tzinfo is None:
        deadline = deadline.replace(tzinfo=timezone.utc)
        
    if not deadline:
        from datetime import timedelta
        deadline = created_at + timedelta(hours=sla_hours)
        
    if resolved_at:
        if resolved_at.tzinfo is None:
            resolved_at = resolved_at.replace(tzinfo=timezone.utc)
        met_sla = resolved_at <= deadline
        return {
            "status": "COMPLIED" if met_sla else "BREACHED",
            "badge_color": "green" if met_sla else "red",
            "label": "Resolved within SLA" if met_sla else "Resolved with Overdue",
            "hours_remaining": 0,
            "deadline": deadline.isoformat()
        }
        
    diff = deadline - now
    hours_left = diff.total_seconds() / 3600.0
    
    if hours_left < 0:
        return {
            "status": "OVERDUE",
            "badge_color": "red",
            "label": f"Overdue by {abs(int(hours_left))}h",
            "hours_remaining": round(hours_left, 1),
            "deadline": deadline.isoformat(),
            "is_breached": True
        }
    elif hours_left <= 4:
        return {
            "status": "DUE_SOON",
            "badge_color": "orange",
            "label": f"Due soon ({round(hours_left, 1)}h remaining)",
            "hours_remaining": round(hours_left, 1),
            "deadline": deadline.isoformat(),
            "is_breached": False
        }
    else:
        return {
            "status": "WITHIN_SLA",
            "badge_color": "green",
            "label": f"Within SLA ({int(hours_left)}h remaining)",
            "hours_remaining": round(hours_left, 1),
            "deadline": deadline.isoformat(),
            "is_breached": False
        }
