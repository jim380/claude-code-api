# Deploy with Docker

**Proceed at your own risk**. Your account might be banned due to T&C violation.

## Prerequisites

- Docker
- Docker Compose
- An Anthropic API key or subscription plan (optional - can use subscription)

## Quick Start

### Build

```bash
# Build the image
$ docker compose build

# Or build with custom image name/tag
$ export DOCKER_IMAGE=myregistry.com/claude-code-api
$ export DOCKER_TAG=v1.0.0
$ docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .

# Multi-arch build
$ docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${DOCKER_IMAGE:-claude-code-api}:${DOCKER_TAG:-latest} .
```

### Run

```bash
$ mkdir -p projects
$ chmod 777 projects

$ docker compose up -d
$ docker compose down
```

### Authenticate

```bash
# login using subscription
$ docker compose exec api claude
```
