import time
from fastapi import APIRouter
from pydantic import BaseModel
import httpx

router = APIRouter(tags=["应用"])

# 简单的内存缓存
_cache: dict = {
    "data": None,
    "expires_at": 0,
}
CACHE_TTL = 300  # 5分钟


class VersionInfo(BaseModel):
    version: str
    download_url: str
    release_notes: str


@router.get("/version", response_model=VersionInfo)
async def get_latest_version():
    now = time.time()
    
    if _cache["data"] and _cache["expires_at"] > now:
        return _cache["data"]
    
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            "https://api.github.com/repos/Keleoz-Cyber/LessonSearch/releases",
            headers={"Accept": "application/vnd.github.v3+json"},
        )
        resp.raise_for_status()
        data = resp.json()
    
    if not data:
        return VersionInfo(version="0.0.0", download_url="", release_notes="")
    
    latest = data[0]
    
    version = latest.get("tag_name", "").lstrip("v")
    download_url = ""
    release_notes = latest.get("body", "")
    
    for asset in latest.get("assets", []):
        if asset.get("name", "").endswith(".apk"):
            download_url = asset.get("browser_download_url", "")
            break
    
    if not download_url:
        download_url = f"https://github.com/Keleoz-Cyber/LessonSearch/releases/tag/v{version}"
    
    result = VersionInfo(
        version=version,
        download_url=download_url,
        release_notes=release_notes,
    )
    
    _cache["data"] = result
    _cache["expires_at"] = now + CACHE_TTL
    
    return result