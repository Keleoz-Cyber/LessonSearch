from fastapi import FastAPI
from fastapi.responses import JSONResponse
from contextlib import closing
from datetime import datetime, timezone
from sqlalchemy import text
from routers import grades, majors, classes, students, tasks, records, auth, app_version, sync, data_version
from app.routers import week, user, submission, duty, announcement, ranking
from app.core.database import get_db
from app.services.schema_readiness import check_schema
from app.version import API_VERSION, API_CAPABILITIES

app = FastAPI(
    title="考勤助手 API",
    description="考勤助手 App 服务端接口",
    version=API_VERSION,
)

app.include_router(auth.router, prefix="/api")
app.include_router(app_version.router, prefix="/api")
app.include_router(sync.router, prefix="/api")
app.include_router(grades.router, prefix="/api")
app.include_router(majors.router, prefix="/api")
app.include_router(classes.router, prefix="/api")
app.include_router(students.router, prefix="/api")
app.include_router(tasks.router, prefix="/api")
app.include_router(records.router, prefix="/api")
app.include_router(records.record_router, prefix="/api")
app.include_router(week.router, prefix="/api")
app.include_router(user.router, prefix="/api")
app.include_router(submission.router, prefix="/api")
app.include_router(duty.router, prefix="/api")
app.include_router(announcement.router, prefix="/api")
app.include_router(ranking.router, prefix="/api")
app.include_router(data_version.router, prefix="/api")


@app.get("/health")
@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "version": API_VERSION,
        "capabilities": API_CAPABILITIES,
    }


@app.get("/health/db")
@app.get("/api/health/db")
def health_db():
    try:
        with closing(get_db()) as sessions:
            db = next(sessions)
            db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception:
        # Connection exceptions may contain usernames, hosts or SQL parameters.
        return JSONResponse(status_code=503, content={"status": "error", "database": "unavailable"})


@app.get("/health/ready")
@app.get("/api/health/ready")
def health_ready():
    try:
        with closing(get_db()) as sessions:
            db = next(sessions)
            db.execute(text("SELECT 1"))
            schema = check_schema(db.connection())
        if not schema["ready"]:
            return JSONResponse(status_code=503, content={"status": "not_ready", "schema": "upgrade_required"})
        return {"status": "ok", "schema": "ready", "version": API_VERSION}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "not_ready", "database": "unavailable"})
