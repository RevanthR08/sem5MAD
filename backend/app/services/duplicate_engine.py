from typing import List, Dict, Any
from backend.app.core.database import get_db

def find_nearby_duplicates(
    lat: float, 
    lng: float, 
    category_id: str, 
    exclude_report_id: str = None
) -> List[Dict[str, Any]]:
    """
    Intelligent PostGIS duplicate detection:
    Searches for non-resolved reports in the same category within category radius.
    """
    with get_db() as cur:
        # Get category radius
        cur.execute("SELECT duplicate_radius_meters FROM categories WHERE id = %s;", (category_id,))
        cat = cur.fetchone()
        radius = cat["duplicate_radius_meters"] if cat else 60

        query = """
            SELECT 
                r.id,
                r.public_id,
                r.title,
                r.description,
                r.status,
                r.priority,
                r.address,
                r.created_at,
                r.upvotes,
                ROUND(ST_Distance(
                    r.location, 
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
                )::numeric, 1) as distance_meters,
                (SELECT url FROM report_media rm WHERE rm.report_id = r.id LIMIT 1) as thumbnail_url
            FROM reports r
            WHERE 
                r.category_id = %s
                AND r.status NOT IN ('RESOLVED', 'REJECTED')
                AND ST_DWithin(
                    r.location,
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
                    %s
                )
        """
        params = [lng, lat, category_id, lng, lat, radius]
        if exclude_report_id:
            query += " AND r.id != %s"
            params.append(exclude_report_id)

        query += " ORDER BY distance_meters ASC LIMIT 5;"
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        return [dict(row) for row in rows]
