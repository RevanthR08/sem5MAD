from fastapi import APIRouter
from backend.app.core.database import get_db

router = APIRouter(prefix="/analytics", tags=["Analytics & Civic Intelligence"])

@router.get("/overview")
def get_analytics_overview():
    """Retrieve high-level municipal KPIs for Authority Dashboard."""
    with get_db() as cur:
        # Total counts by status
        cur.execute("""
            SELECT 
                COUNT(*) as total_reports,
                COUNT(*) FILTER (WHERE status IN ('SUBMITTED', 'ROUTED', 'VALIDATING')) as open_reports,
                COUNT(*) FILTER (WHERE status IN ('ACKNOWLEDGED', 'ASSIGNED', 'IN_PROGRESS')) as in_progress_reports,
                COUNT(*) FILTER (WHERE status = 'RESOLUTION_SUBMITTED') as awaiting_verification,
                COUNT(*) FILTER (WHERE status = 'RESOLVED') as resolved_reports,
                COUNT(*) FILTER (WHERE status = 'REOPENED') as reopened_reports,
                COUNT(*) FILTER (WHERE priority = 'CRITICAL' AND status NOT IN ('RESOLVED', 'REJECTED')) as critical_active
            FROM reports;
        """)
        stats = cur.fetchone()
        
        # Overdue SLA check
        cur.execute("""
            SELECT COUNT(*) as overdue_count
            FROM reports
            WHERE status NOT IN ('RESOLVED', 'REJECTED')
              AND sla_deadline < NOW();
        """)
        overdue = cur.fetchone()["overdue_count"]
        
        # Ward performance
        cur.execute("""
            SELECT w.name as ward_name, COUNT(r.id) as count
            FROM wards w
            LEFT JOIN reports r ON r.ward_id = w.id
            GROUP BY w.name
            ORDER BY count DESC
            LIMIT 5;
        """)
        ward_perf = cur.fetchall()

        # Category distribution
        cur.execute("""
            SELECT c.name as category_name, c.icon, COUNT(r.id) as count
            FROM categories c
            LEFT JOIN reports r ON r.category_id = c.id
            GROUP BY c.name, c.icon
            ORDER BY count DESC;
        """)
        cat_dist = cur.fetchall()

        total = stats["total_reports"] or 1
        resolved = stats["resolved_reports"] or 0
        sla_compliance_pct = round(((total - overdue) / total) * 100, 1)

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
