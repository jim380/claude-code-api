FROM python:3.13-slim-bookworm AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential curl gnupg && \
    rm -rf /var/lib/apt/lists/*

ENV VENV_PATH=/install
RUN python -m venv ${VENV_PATH}

WORKDIR /app
COPY pyproject.toml ./
COPY setup.py ./

RUN ${VENV_PATH}/bin/pip install --upgrade pip wheel && \
    ${VENV_PATH}/bin/pip install ".[dev]"  # pull extras in builder only

COPY . /app
RUN ${VENV_PATH}/bin/pip install .

FROM python:3.13-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      tini curl && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g @anthropic-ai/claude-code

COPY --from=builder /install /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN adduser --disabled-password --gecos '' apiuser

ENV PYTHONUNBUFFERED=1 \
    UVICORN_HOST=0.0.0.0 \
    UVICORN_PORT=8000 \
    PROJECT_ROOT=/tmp/claude_projects \
    CLAUDE_BINARY_PATH=/usr/local/bin/claude \
    LOG_LEVEL=info

RUN mkdir -p /tmp/claude_projects && \
    chown -R apiuser:apiuser /tmp/claude_projects && \
    chmod 755 /tmp/claude_projects

WORKDIR /app
COPY --chown=apiuser:apiuser . /app

USER apiuser

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/opt/venv/bin/python", "-m", "uvicorn", "claude_code_api.main:app", "--host", "0.0.0.0", "--port", "8000"]