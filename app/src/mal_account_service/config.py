from dataclasses import dataclass
from functools import lru_cache
import os


@dataclass(frozen=True)
class Settings:
    service_name: str
    database_url: str
    log_level: str


@lru_cache
def get_settings() -> Settings:
    return Settings(
        service_name=os.getenv("SERVICE_NAME", "mal-account-service"),
        database_url=os.getenv("DATABASE_URL", ""),
        log_level=os.getenv("LOG_LEVEL", "INFO"),
    )
