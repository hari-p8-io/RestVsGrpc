#!/bin/bash

# Multi-Architecture Docker Build Script for REST vs gRPC Services
# Builds and pushes Docker images for both ARM64 and AMD64 architectures

set -e

# Configuration
PROJECT_ID="silent-oxide-210505"
REGION="australia-southeast2"
REPOSITORY="rest-grpc-repo"
MAIN_SERVICE_IMAGE="rest-grpc-service"
CLIENT_SERVICE_IMAGE="rest-grpc-client"
TAG=${1:-latest}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_color() {
    echo -e "${1}${2}${NC}"
}

echo_color $BLUE "🚀 Building Multi-Architecture Docker Images..."

# Check if Docker buildx is available
if ! docker buildx version >/dev/null 2>&1; then
    echo_color $RED "❌ Docker buildx is required for multi-architecture builds"
    echo_color $YELLOW "Please install Docker Desktop or enable buildx"
    exit 1
fi

# Create a new builder instance if it doesn't exist
if ! docker buildx ls | grep -q "multiarch-builder"; then
    echo_color $YELLOW "📦 Creating multiarch builder..."
    docker buildx create --name multiarch-builder --driver docker-container --bootstrap
fi

# Use the multiarch builder
docker buildx use multiarch-builder

# Configure Docker registry
REGISTRY_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}"

# Authenticate with Google Cloud
echo_color $YELLOW "🔐 Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build and push main service (multi-architecture)
echo_color $YELLOW "🏗️  Building main service for multiple architectures..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag ${REGISTRY_URL}/${MAIN_SERVICE_IMAGE}:${TAG} \
    --tag ${REGISTRY_URL}/${MAIN_SERVICE_IMAGE}:latest \
    --push \
    .

# Build and push client service (multi-architecture)
echo_color $YELLOW "🏗️  Building client service for multiple architectures..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag ${REGISTRY_URL}/${CLIENT_SERVICE_IMAGE}:${TAG} \
    --tag ${REGISTRY_URL}/${CLIENT_SERVICE_IMAGE}:latest \
    --push \
    --file rest-grpc-client/Dockerfile \
    rest-grpc-client/

# Verify images
echo_color $YELLOW "🔍 Verifying multi-architecture images..."
docker buildx imagetools inspect ${REGISTRY_URL}/${MAIN_SERVICE_IMAGE}:${TAG}
docker buildx imagetools inspect ${REGISTRY_URL}/${CLIENT_SERVICE_IMAGE}:${TAG}

echo_color $GREEN "✅ Multi-architecture Docker images built and pushed successfully!"
echo_color $BLUE "📋 Images available:"
echo_color $BLUE "   Main Service: ${REGISTRY_URL}/${MAIN_SERVICE_IMAGE}:${TAG}"
echo_color $BLUE "   Client Service: ${REGISTRY_URL}/${CLIENT_SERVICE_IMAGE}:${TAG}"
echo_color $BLUE "   Architectures: linux/amd64, linux/arm64" 