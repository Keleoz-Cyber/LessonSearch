from fastapi import FastAPI
from routers import grades, majors, classes, students, tasks, records, auth, app_version, sync
from app.core.database import Base
from app.models import *  # 确保所有模型被导入以创建表

app = FastAPI(
    title="考勤助手 API",
    description="考勤助手 App 服务端接口",
    version="0.5.0",
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


@app.get("/health")
def health():
    return {"status": "ok"}
