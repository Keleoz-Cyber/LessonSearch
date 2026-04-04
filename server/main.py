from fastapi import FastAPI
from routers import grades, majors, classes, students, tasks, records, auth

app = FastAPI(
    title="查课 API",
    description="查课 App 服务端接口",
    version="0.2.0",
)

app.include_router(auth.router, prefix="/api")
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
