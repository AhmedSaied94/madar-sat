# Multi-stage, buildable for linux/arm64 (buildx + QEMU in CI). The final stage
# has no build tools and runs as a non-root user.

FROM python:3.13-slim AS builder
# Pinned uv binary from its official image; keep it in step with the uv that wrote uv.lock.
COPY --from=ghcr.io/astral-sh/uv:0.12.23 /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

FROM python:3.13-slim
# ffmpeg/ffprobe are needed only by the media rehost command, but it runs as a
# one-off container of this same image.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 madar
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app
COPY openapi ./openapi
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
USER madar
EXPOSE 8000 8001
# Compose overrides this for api-admin with `app.admin:app -w 1 -b 0.0.0.0:8001`.
CMD ["gunicorn", "app.public:app", "-k", "uvicorn.workers.UvicornWorker", "-w", "2", "-b", "0.0.0.0:8000"]
