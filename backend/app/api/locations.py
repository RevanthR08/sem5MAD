from fastapi import APIRouter, Query
from starlette.concurrency import run_in_threadpool
from backend.app.services.geo_engine import reverse_geocode_osm, resolve_administrative_boundary

router = APIRouter(prefix="/locations", tags=["Locations"])

@router.get("/reverse-geocode")
async def reverse_geocode(lat: float = Query(...), lng: float = Query(...)):
    """Reverse geocode coordinates to street address and administrative ward/zone."""
    geo_data = await reverse_geocode_osm(lat, lng)
    # Blocking DB call: keep it off the event loop
    admin_data = await run_in_threadpool(resolve_administrative_boundary, lat, lng)
    
    return {
        "latitude": lat,
        "longitude": lng,
        "address": geo_data.get("address", ""),
        "city": admin_data.get("city", "Chennai"),
        "ward_id": admin_data.get("ward_id"),
        "ward_number": admin_data.get("ward_number"),
        "ward_name": admin_data.get("ward_name"),
        "zone_id": admin_data.get("zone_id"),
        "zone_name": admin_data.get("zone_name"),
        "authority_id": admin_data.get("authority_id"),
        "authority_name": admin_data.get("authority_name")
    }
