"""Stable updates must refer to an APK that was actually published."""
import re
import time
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(tags=["应用"])
RELEASES_URL = "https://api.github.com/repos/Keleoz-Cyber/LessonSearch/releases"
_cache: dict = {"data": None, "expires_at": 0}
CACHE_TTL = 300


class VersionInfo(BaseModel):
    version: str
    download_url: str
    release_notes: str


def select_release(releases: list) -> VersionInfo:
    candidates = []
    for release in releases:
        if not isinstance(release, dict) or release.get("draft") or release.get("prerelease"):
            continue
        tag = release.get("tag_name", "")
        if not isinstance(tag, str) or not re.fullmatch(r"v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", tag):
            continue
        version = tag.removeprefix("v")
        for asset in release.get("assets") or []:
            name = asset.get("name", "")
            url = asset.get("browser_download_url", "")
            if not isinstance(name, str) or not isinstance(url, str):
                continue
            parsed = urlparse(url)
            prefix = f"/Keleoz-Cyber/LessonSearch/releases/download/{tag}/"
            if (name.lower().endswith(".apk") and asset.get("state") == "uploaded"
                    and asset.get("size", 0) > 0 and parsed.scheme == "https"
                    and parsed.netloc == "github.com" and parsed.path.startswith(prefix)):
                candidates.append((tuple(map(int, version.split("."))), VersionInfo(
                    version=version, download_url=url, release_notes=release.get("body") or "")))
                break
    return max(candidates, key=lambda item: item[0])[1] if candidates else VersionInfo(
        version="0.0.0", download_url="", release_notes="")


@router.get("/version", response_model=VersionInfo)
async def get_latest_version():
    if _cache["data"] and _cache["expires_at"] > time.time():
        return _cache["data"]
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(RELEASES_URL, headers={"Accept": "application/vnd.github+json"})
            resp.raise_for_status()
            releases = resp.json()
        if not isinstance(releases, list):
            raise ValueError("Unexpected release list")
        result = select_release(releases)
    except (httpx.HTTPError, ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=503, detail="暂时无法获取更新，请稍后重试") from None
    _cache.update(data=result, expires_at=time.time() + CACHE_TTL)
    return result
