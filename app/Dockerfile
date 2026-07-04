FROM python:3.12.4-slim-bookworm AS builder

WORKDIR /build
COPY app/requirements.txt .
RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir --upgrade pip \
    && /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12.4-slim-bookworm

ENV PATH="/venv/bin:${PATH}" \
    PYTHONPATH="/app/src" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --home-dir /app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /venv /venv
COPY app/src ./src

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')"

CMD ["uvicorn", "mal_account_service.main:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers"]
