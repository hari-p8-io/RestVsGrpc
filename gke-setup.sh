#!/bin/bash

# GKE Setup and Deployment Script
set -e

# Configuration variables - UPDATE THESE
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

echo -e "${GREEN}🚀 Starting GKE deployment process...${NC}"

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

# Authenticate and set project
echo -e "${YELLOW}🔐 Setting up GCP authentication...${NC}"
echo "Please make sure you're authenticated with: gcloud auth login"
echo "Setting project to: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}🔧 Enabling required GCP APIs...${NC}"
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Create Artifact Registry repository
echo -e "${YELLOW}📦 Creating Artifact Registry repository...${NC}"
gcloud artifacts repositories create $REPOSITORY_NAME \
    --repository-format=docker \
    --location=$REGISTRY_LOCATION \
    --description="Repository for REST vs gRPC performance test images" || true

# Configure Docker for Artifact Registry
echo -e "${YELLOW}🐳 Configuring Docker for Artifact Registry...${NC}"
gcloud auth configure-docker ${REGISTRY_LOCATION}-docker.pkg.dev

# Create GKE cluster
echo -e "${YELLOW}☸️  Creating GKE cluster...${NC}"
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --num-nodes=3 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-autorepair \
    --enable-autoupgrade \
    --disk-size=50GB || true

# Get cluster credentials
echo -e "${YELLOW}🔑 Getting cluster credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --region=$ZONE

echo -e "${GREEN}✅ GKE cluster setup completed!${NC}"
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Update the PROJECT_ID, CLUSTER_NAME, and ZONE variables in this script"
echo "2. Run: ./build-and-deploy.sh to build and deploy the application"
echo "3. Run: ./run-k6-tests.sh to execute the performance tests" 