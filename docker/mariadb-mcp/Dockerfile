FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app

RUN git clone --depth 1 https://github.com/mariadb/mcp.git . \
    && uv sync --no-dev

FROM python:3.11-slim

WORKDIR /app
ENV PATH="/app/.venv/bin:${PATH}"

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/src /app/src

CMD ["python", "src/server.py", "--transport", "stdio"]
