from fastapi import APIRouter
from backend.app.core.database import get_db

router = APIRouter(prefix="/analytics", tags=["Analytics & Civic Intelligence"])

@router.get("/overview")
def get_analytics_overview():
    """Retrieve high-level municipal KPIs for Authority Dashboard."""
    with get_db() as cur:
        # All counters in one round trip to the database
        cur.execute("""
            SELECT
                COUNT(*) as total_reports,
                COUNT(*) FILTER (WHERE status IN ('SUBMITTED', 'ROUTED', 'VALIDATING')) as open_reports,
                COUNT(*) FILTER (WHERE status IN ('ACKNOWLEDGED', 'ASSIGNED', 'IN_PROGRESS')) as in_progress_reports,
                COUNT(*) FILTER (WHERE status = 'RESOLUTION_SUBMITTED') as awaiting_verification,
                COUNT(*) FILTER (WHERE status = 'RESOLVED') as resolved_reports,
                COUNT(*) FILTER (WHERE status = 'REOPENED') as reopened_reports,
                COUNT(*) FILTER (WHERE priority = 'CRITICAL' AND status NOT IN ('RESOLVED', 'REJECTED')) as critical_active,
                -- Overdue: the clock stops once the field worker submits the repair
                COUNT(*) FILTER (WHERE status NOT IN ('RESOLVED', 'REJECTED', 'DUPLICATE', 'RESOLUTION_SUBMITTED')
                                   AND sla_deadline < NOW()) as overdue_count,
                -- Breached: finished late, or still unfinished past the deadline
                COUNT(*) FILTER (WHERE (resolved_at IS NOT NULL AND resolved_at > sla_deadline)
                                    OR (resolved_at IS NULL AND status NOT IN ('REJECTED', 'DUPLICATE') AND sla_deadline < NOW())) as breached,
                (SELECT COALESCE(json_agg(w ORDER BY w.count DESC), '[]') FROM (
                    SELECT wd.name as ward_name, COUNT(r2.id) as count
                    FROM wards wd LEFT JOIN reports r2 ON r2.ward_id = wd.id
                    GROUP BY wd.name ORDER BY count DESC LIMIT 5) w) as ward_perf,
                (SELECT COALESCE(json_agg(c ORDER BY c.count DESC), '[]') FROM (
                    SELECT cat.name as category_name, cat.icon, COUNT(r3.id) as count
                    FROM categories cat LEFT JOIN reports r3 ON r3.category_id = cat.id
                    GROUP BY cat.name, cat.icon) c) as cat_dist
            FROM reports;
        """)
        stats = cur.fetchone()
        overdue = stats["overdue_count"]
        breached = stats["breached"]
        ward_perf = stats["ward_perf"]
        cat_dist = stats["cat_dist"]

        total = stats["total_reports"] or 0
        resolved = stats["resolved_reports"] or 0
        sla_compliance_pct = round(((total - breached) / total) * 100, 1) if total else 100.0

        return {
            "total_reports": stats["total_reports"],
            "open_reports": stats["open_reports"],
            "in_progress": stats["in_progress_reports"],
            "awaiting_verification": stats["awaiting_verification"],
            "resolved_reports": resolved,
            "reopened_reports": stats["reopened_reports"],
            "critical_active": stats["critical_active"],
            "overdue_reports": overdue,
            "sla_compliance_pct": sla_compliance_pct,
            "category_distribution": [dict(c) for c in cat_dist],
            "ward_performance": [dict(w) for w in ward_perf]
        }

@router.get("/heatmap")
def get_heatmap_points():
    """Retrieve spatial heatmap points for civic intelligence map."""
    with get_db() as cur:
        cur.execute("""
            SELECT 
                r.latitude as lat,
                r.longitude as lng,
                r.title,
                r.status,
                r.priority,
                c.name as category,
                CASE 
                    WHEN r.priority = 'CRITICAL' THEN 1.0
                    WHEN r.priority = 'HIGH' THEN 0.75
                    WHEN r.priority = 'MEDIUM' THEN 0.5
                    ELSE 0.3
                END as weight
            FROM reports r
            JOIN categories c ON r.category_id = c.id
            WHERE r.status NOT IN ('RESOLVED', 'REJECTED');
        """)
        return [dict(p) for p in cur.fetchall()]
