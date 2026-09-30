from fastapi import APIRouter
from backend.app.core.database import get_db

router = APIRouter(prefix="/categories", tags=["Categories"])

@router.get("")
def list_categories():
    """Retrieve all civic issue categories with subcategories."""
    with get_db() as cur:
        cur.execute("""
            SELECT id, code, name, icon, description, default_sla_hours, duplicate_radius_meters
            FROM categories
            ORDER BY name ASC;
        """)
        cats = cur.fetchall()
        
        result = []
        for cat in cats:
            cur.execute("""
                SELECT id, code, name, sla_hours, priority_level
                FROM subcategories
                WHERE category_id = %s
                ORDER BY name ASC;
            """, (cat["id"],))
            subs = cur.fetchall()
            
            c_dict = dict(cat)
            c_dict["subcategories"] = [dict(s) for s in subs]
            result.append(c_dict)
            
        return result
