#!/bin/bash
set -euo pipefail

REGISTRY="${DOCKER_REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-claude-code-api}"
VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo "latest")}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -r, --registry REGISTRY    Docker registry to push to
    -t, --tag TAG             Additional tag for the image
    -p, --platform PLATFORM   Platform(s) to build for (default: linux/amd64,linux/arm64)
    --push                    Push image to registry after build
    --no-cache               Build without cache
    -h, --help               Show this help message

EXAMPLES:
    # Build for local use
    $0

    # Build and push to registry
    $0 --registry myregistry.com --push

    # Build with custom tag
    $0 --tag dev-$(date +%Y%m%d)
EOF
}

PUSH=false
NO_CACHE=""
EXTRA_TAGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            EXTRA_TAGS+=("$2")
            shift 2
            ;;
        -p|--platform)
            PLATFORMS="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! docker buildx version &> /dev/null; then
    log_error "Docker buildx is not available"
    exit 1
fi

log_info "Preparing Docker build..."
log_info "Image: ${IMAGE_NAME}:${VERSION}"
log_info "Platforms: ${PLATFORMS}"

BUILDER_NAME="claude-code-api-builder"
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
    log_info "Creating buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
else
    docker buildx use "$BUILDER_NAME"
fi

TAGS=("${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:latest")

if [[ -n "$REGISTRY" ]]; then
    TAGS=("${REGISTRY}/${IMAGE_NAME}:${VERSION}" "${REGISTRY}/${IMAGE_NAME}:latest")
fi

for tag in "${EXTRA_TAGS[@]}"; do
    if [[ -n "$REGISTRY" ]]; then
        TAGS+=("${REGISTRY}/${IMAGE_NAME}:${tag}")
    else
        TAGS+=("${IMAGE_NAME}:${tag}")
    fi
done

BUILD_CMD="docker buildx build"
BUILD_CMD+=" --platform ${PLATFORMS}"
BUILD_CMD+=" ${NO_CACHE}"

for tag in "${TAGS[@]}"; do
    BUILD_CMD+=" -t ${tag}"
done

if [[ "$PUSH" == "true" ]]; then
    BUILD_CMD+=" --push"
else
    BUILD_CMD+=" --load"
fi

BUILD_CMD+=" ."

log_info "Building Docker image..."
log_info "Command: $BUILD_CMD"

if eval "$BUILD_CMD"; then
    log_info "Build completed successfully!"
    log_info "Tagged as:"
    for tag in "${TAGS[@]}"; do
        echo "  - $tag"
    done
else
    log_error "Build failed!"
    exit 1
fi

if [[ "$PUSH" == "true" ]]; then
    log_info "Image pushed to registry"
else
    log_info "Image loaded locally"
    log_info "Run with: docker run -p 8000:8000 -e CLAUDE_API_KEY=\$CLAUDE_API_KEY ${TAGS[0]}"
fi