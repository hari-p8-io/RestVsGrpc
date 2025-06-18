#!/bin/bash

# Connect to Existing GKE Cluster Script
set -e

# Configuration variables
PROJECT_ID="silent-oxide-210505"
CLUSTER_NAME="autopilot-cluster-1"
ZONE="australia-southeast2"
REGISTRY_LOCATION="australia-southeast2"
REPOSITORY_NAME="rest-grpc-repo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔗 Connecting to existing GKE cluster...${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
if ! command_exists gcloud; then
    echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud CLI.${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Set project
echo -e "${YELLOW}🔐 Setting GCP project...${NC}"
gcloud config set project $PROJECT_ID

# Get cluster credentials
echo -e "${YELLOW}🔑 Getting cluster credentials for $CLUSTER_NAME...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --region=$ZONE

# Verify cluster connection
echo -e "${YELLOW}✅ Verifying cluster connection...${NC}"
kubectl cluster-info
kubectl get nodes

# Enable required APIs
echo -e "${YELLOW}🔧 Enabling required GCP APIs...${NC}"
gcloud services enable artifactregistry.googleapis.com

# Create Artifact Registry repository if it doesn't exist
echo -e "${YELLOW}📦 Creating Artifact Registry repository...${NC}"
gcloud artifacts repositories create $REPOSITORY_NAME \
    --repository-format=docker \
    --location=$REGISTRY_LOCATION \
    --description="Repository for REST vs gRPC performance test images" 2>/dev/null || {
    echo -e "${YELLOW}ℹ️  Repository $REPOSITORY_NAME already exists${NC}"
}

# Configure Docker for Artifact Registry
echo -e "${YELLOW}🐳 Configuring Docker for Artifact Registry...${NC}"
gcloud auth configure-docker ${REGISTRY_LOCATION}-docker.pkg.dev

echo -e "${GREEN}✅ Successfully connected to autopilot-cluster-1!${NC}"
echo -e "${YELLOW}📝 Cluster information:${NC}"
echo -e "   Project: $PROJECT_ID"
echo -e "   Cluster: $CLUSTER_NAME"
echo -e "   Zone: $ZONE"
echo -e "   Registry: $REGISTRY_LOCATION"

echo -e "${YELLOW}🚀 Next steps:${NC}"
echo "1. Run: ./build-and-deploy.sh to build and deploy the application"
echo "2. Run: ./run-k6-tests.sh to execute the performance tests" 