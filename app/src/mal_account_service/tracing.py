import os

from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor

from mal_account_service.config import get_settings


def configure_tracing(app: object) -> None:
    settings = get_settings()
    provider = TracerProvider(
        resource=Resource.create({"service.name": settings.service_name})
    )
    if os.getenv("OTEL_CONSOLE_EXPORTER", "false").lower() == "true":
        provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app)


def get_tracer() -> trace.Tracer:
    return trace.get_tracer("mal_account_service")
