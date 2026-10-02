from fastapi import APIRouter
from backend.app.core.database import get_db

router = APIRouter(prefix="/categories", tags=["Categories"])

@router.get("")
def list_categories():
    """Retrieve all civic issue categories with subcategories (single query)."""
    with get_db() as cur:
        cur.execute("""
            SELECT c.id, c.code, c.name, c.icon, c.description, c.default_sla_hours, c.duplicate_radius_meters,
                   COALESCE(
                       json_agg(
                           json_build_object('id', s.id, 'code', s.code, 'name', s.name,
                                             'sla_hours', s.sla_hours, 'priority_level', s.priority_level)
                           ORDER BY s.name
                       ) FILTER (WHERE s.id IS NOT NULL),
                       '[]'
                   ) AS subcategories
            FROM categories c
            LEFT JOIN subcategories s ON s.category_id = c.id
            GROUP BY c.id
            ORDER BY c.name ASC;
        """)
        return [dict(row) for row in cur.fetchall()]
