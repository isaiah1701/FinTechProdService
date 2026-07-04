import time
from collections.abc import Callable, Awaitable

from fastapi import Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.responses import Response as StarletteResponse


REQUESTS = Counter(
    "bank_account_service_http_requests_total",
    "HTTP requests served by the account service. Business context: account lookup demand and release impact.",
    ["method", "path", "status"],
)

ERRORS = Counter(
    "bank_account_service_http_request_errors_total",
    "HTTP requests returning 5xx responses. Business context: customer-impacting account lookup failures.",
    ["method", "path", "status"],
)

DURATION = Histogram(
    "bank_account_service_http_request_duration_seconds",
    "HTTP request duration in seconds. Business context: tail latency for banking account reads.",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)


def _route_path(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


async def record_http_metrics(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    started = time.perf_counter()
    status = "500"
    route_path = request.url.path

    try:
        response = await call_next(request)
        status = str(response.status_code)
        route_path = _route_path(request)
        return response
    except Exception:
        status = "500"
        route_path = _route_path(request)
        raise
    finally:
        elapsed = time.perf_counter() - started
        labels = {"method": request.method, "path": route_path, "status": status}
        REQUESTS.labels(**labels).inc()
        if int(status) >= 500:
            ERRORS.labels(**labels).inc()
        DURATION.labels(method=request.method, path=route_path).observe(elapsed)


def metrics_response() -> StarletteResponse:
    return StarletteResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)
