import logging
import psycopg2
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from backend.app.core.config import settings
from backend.app.api import auth, categories, locations, reports, staff, analytics
from backend.app.core.database import get_db

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Digital Operating System for Civic Problems - Civic Connect Engine"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(psycopg2.OperationalError)
async def database_unavailable(request: Request, exc: psycopg2.OperationalError):
    # Network/DNS trouble reaching the hosted database after retries
    logging.getLogger("uvicorn.error").warning("Database unavailable on %s: %s", request.url.path, str(exc).strip())
    return JSONResponse(status_code=503, content={"detail": "Database temporarily unreachable. Please try again."})

# Include Routers
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(categories.router, prefix=settings.API_V1_PREFIX)
app.include_router(locations.router, prefix=settings.API_V1_PREFIX)
app.include_router(reports.router, prefix=settings.API_V1_PREFIX)
app.include_router(staff.router, prefix=settings.API_V1_PREFIX)
app.include_router(analytics.router, prefix=settings.API_V1_PREFIX)

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "Civic Connect Backend", "version": settings.APP_VERSION}

@app.get("/health/db")
def health_db():
    try:
        with get_db() as cur:
            cur.execute("SELECT 1;")
            cur.execute("SELECT PostGIS_Version();")
            pg_ver = cur.fetchone()
            ver_val = list(pg_ver.values())[0] if pg_ver else "Unknown"
            return {"status": "connected", "database": "PostgreSQL + PostGIS", "postgis_version": ver_val}
    except Exception as e:
        return {"status": "error", "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=True)
