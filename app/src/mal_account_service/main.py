import json
import logging
import signal
from datetime import datetime, UTC

from fastapi import FastAPI, HTTPException

from mal_account_service.accounts import router as accounts_router
from mal_account_service.config import get_settings
from mal_account_service.metrics import metrics_response, record_http_metrics
from mal_account_service.readiness import mark_draining, readiness_status
from mal_account_service.tracing import configure_tracing


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        return json.dumps(payload)


def configure_logging() -> None:
    settings = get_settings()
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    logging.basicConfig(level=settings.log_level, handlers=[handler], force=True)


def create_app() -> FastAPI:
    configure_logging()
    app = FastAPI(title="Mal Account Service", version="0.1.0")
    app.middleware("http")(record_http_metrics)
    app.include_router(accounts_router)

    configure_tracing(app)
    signal.signal(signal.SIGTERM, mark_draining)

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/readyz")
    def readyz() -> dict[str, str]:
        ready, reason = readiness_status()
        if not ready:
            raise HTTPException(status_code=503, detail=reason)
        return {"status": reason}

    @app.get("/metrics")
    def metrics():
        return metrics_response()

    return app


app = create_app()
