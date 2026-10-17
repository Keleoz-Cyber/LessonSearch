"""Configuration helpers without environment loading or database connections."""
from pathlib import Path
from typing import Mapping

from sqlalchemy.engine import URL

DEFAULT_JWT_SECRET = "your-secret-key-change-in-production"


def select_env_file(server_dir: Path, environ: Mapping[str, str]) -> Path:
    explicit = environ.get("LESSONSEARCH_ENV_FILE")
    if explicit:
        return Path(explicit).expanduser().resolve()
    local = server_dir / ".env"
    root = server_dir.parent / ".env"
    return local if local.exists() or not root.exists() else root


def validate_production(environ: Mapping[str, str]) -> None:
    if environ.get("APP_ENV", "development").lower() != "production":
        return
    secret = environ.get("JWT_SECRET", "")
    if len(secret.strip()) < 32 or secret == DEFAULT_JWT_SECRET:
        raise ValueError("Production requires a non-default JWT_SECRET of at least 32 characters")
    if not environ.get("DB_PASSWORD"):
        raise ValueError("Production requires an explicitly configured DB_PASSWORD")


def database_url(environ: Mapping[str, str]) -> URL:
    # URL.create accepts raw credentials; @, :, /, # and % are not re-parsed.
    return URL.create(
        "mysql+pymysql",
        username=environ.get("DB_USER", "root"),
        password=environ.get("DB_PASSWORD", ""),
        host=environ.get("DB_HOST", "localhost"),
        port=int(environ.get("DB_PORT", "3306")),
        database=environ.get("DB_NAME", "lesson_search"),
        query={"charset": "utf8mb4"},
    )
