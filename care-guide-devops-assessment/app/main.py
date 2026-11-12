import json
import logging
import os
import signal
import threading
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

PORT = int(os.getenv("PORT", "8000"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")

REQUEST_COUNT = Counter(
    "http_requests_total", "Total HTTP requests", ["method", "status"]
)
ERROR_COUNT = Counter(
    "http_errors_total", "Total HTTP errors", ["method"]
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method"],
)

class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(record.created)),
            "level": record.levelname,
            "message": record.getMessage(),
            "environment": ENVIRONMENT,
        }
        if hasattr(record, "request_fields"):
            payload.update(record.request_fields)
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)

logger = logging.getLogger("devops_app")
logger.setLevel(LOG_LEVEL)
logger.handlers.clear()
handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)
logger.propagate = False

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("application_starting")
    yield
    logger.info("application_shutting_down")

app = FastAPI(
    title="Care Guide DevOps Assessment API",
    version=APP_VERSION,
    lifespan=lifespan,
)

@app.middleware("http")
async def observe_requests(request: Request, call_next):
    start = time.perf_counter()
    status = "500"
    try:
        response = await call_next(request)
        status = str(response.status_code)
        return response
    except Exception:
        ERROR_COUNT.labels(method=request.method).inc()
        logger.exception("request_failed")
        raise
    finally:
        elapsed = time.perf_counter() - start
        REQUEST_COUNT.labels(method=request.method, status=status).inc()
        if int(status) >= 400:
            ERROR_COUNT.labels(method=request.method).inc()
        REQUEST_LATENCY.labels(method=request.method).observe(elapsed)
        logger.info(
            "request_completed",
            extra={"request_fields": {
                "method": request.method,
                "path": request.url.path,
                "status_code": int(status),
                "latency_ms": round(elapsed * 1000, 2),
            }},
        )

@app.get("/")
async def root():
    return {
        "message": "Hello from DevOps Task!",
        "status": "running",
        "version": APP_VERSION,
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "environment": ENVIRONMENT}

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
