import httpx
from typing import Dict, Any, Optional
from backend.app.core.database import get_db

async def reverse_geocode_osm(lat: float, lng: float) -> Dict[str, str]:
    """Reverse geocode using Nominatim with timeout and fallback."""
    url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lng}&zoom=18&addressdetails=1"
    headers = {"User-Agent": "CivicConnectApp/1.0 (civic-tech-platform)"}
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                addr = data.get("address", {})
                display_name = data.get("display_name", "")
                road = addr.get("road") or addr.get("pedestrian") or addr.get("suburb", "")
                neighbourhood = addr.get("suburb") or addr.get("neighbourhood") or addr.get("city_district", "")
                city = addr.get("city") or addr.get("town") or addr.get("state_district", "Chennai")
                formatted = f"{road}, {neighbourhood}, {city}".strip(", ")
                return {
                    "address": formatted or display_name,
                    "city": city,
                    "neighbourhood": neighbourhood,
                    "postcode": addr.get("postcode", "")
                }
    except Exception:
        pass
    
    return {
        "address": f"Coordinates: {lat:.4f}, {lng:.4f}, Chennai",
        "city": "Chennai",
        "neighbourhood": "Central Chennai",
        "postcode": "600001"
    }

def resolve_administrative_boundary(lat: float, lng: float) -> Dict[str, Any]:
    """Resolve nearest ward, zone, and authority using PostGIS."""
    with get_db() as cur:
        # Find nearest ward based on distance to center_lat, center_lng
        query = """
            SELECT 
                w.id as ward_id, 
                w.ward_number, 
                w.name as ward_name,
                z.id as zone_id, 
                z.name as zone_name,
                a.id as authority_id, 
                a.name as authority_name,
                a.city as city,
                ST_Distance(
                    ST_SetSRID(ST_MakePoint(w.center_lng, w.center_lat), 4326)::geography,
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
                ) as distance_meters
            FROM wards w
            JOIN zones z ON w.zone_id = z.id
            JOIN authorities a ON w.authority_id = a.id
            ORDER BY distance_meters ASC
            LIMIT 1;
        """
        cur.execute(query, (lng, lat))
        res = cur.fetchone()
        if res:
            return dict(res)
            
    # Default fallback
    return {
        "ward_id": "c0000000-0000-0000-0000-000000000123",
        "ward_number": "Ward 123",
        "ward_name": "Mylapore / Anna Salai",
        "zone_id": "b0000000-0000-0000-0000-000000000009",
        "zone_name": "Teynampet",
        "authority_id": "a0000000-0000-0000-0000-000000000001",
        "authority_name": "Greater Chennai Corporation",
        "city": "Chennai",
        "distance_meters": 0.0
    }
