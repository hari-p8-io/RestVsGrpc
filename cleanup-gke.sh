#!/bin/bash

# GKE Cleanup Script
set -e

# Configuration variables - MUST MATCH gke-setup.sh
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

echo -e "${YELLOW}🧹 Starting GKE cleanup process...${NC}"

# Function to ask for confirmation
confirm() {
    read -p "Are you sure you want to $1? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipping $1${NC}"
        return 1
    fi
    return 0
}

# Set project
gcloud config set project $PROJECT_ID

# Clean up Kubernetes resources
echo -e "${YELLOW}🔍 Checking for Kubernetes resources...${NC}"
if kubectl get cluster-info &>/dev/null; then
    echo -e "${YELLOW}🗑️  Cleaning up Kubernetes resources...${NC}"
    
    # Delete jobs
    kubectl delete jobs --all --ignore-not-found=true
    
    # Delete services and deployments
    kubectl delete -f k8s/ --ignore-not-found=true
    
    echo -e "${GREEN}✅ Kubernetes resources cleaned up${NC}"
else
    echo -e "${YELLOW}ℹ️  No active kubectl context found${NC}"
fi

# Delete GKE cluster
if confirm "delete the GKE cluster ($CLUSTER_NAME)"; then
    echo -e "${YELLOW}☸️  Deleting GKE cluster...${NC}"
    gcloud container clusters delete $CLUSTER_NAME \
        --region=$ZONE \
        --quiet || true
    echo -e "${GREEN}✅ GKE cluster deleted${NC}"
fi

# Delete Artifact Registry repository
if confirm "delete the Artifact Registry repository ($REPOSITORY_NAME)"; then
    echo -e "${YELLOW}📦 Deleting Artifact Registry repository...${NC}"
    gcloud artifacts repositories delete $REPOSITORY_NAME \
        --location=$REGISTRY_LOCATION \
        --quiet || true
    echo -e "${GREEN}✅ Artifact Registry repository deleted${NC}"
fi

# Clean up local Docker images
if confirm "clean up local Docker images"; then
    echo -e "${YELLOW}🐳 Cleaning up local Docker images...${NC}"
    docker rmi rest-grpc-service:latest k6-loadtest:latest 2>/dev/null || true
    docker rmi ${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/rest-grpc-service:latest 2>/dev/null || true
    docker rmi ${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/k6-loadtest:latest 2>/dev/null || true
    echo -e "${GREEN}✅ Local Docker images cleaned up${NC}"
fi

# Restore original Kubernetes manifests
echo -e "${YELLOW}📁 Restoring original Kubernetes manifests...${NC}"
if [ -f "k8s/deployment.yaml.bak" ]; then
    mv k8s/deployment.yaml.bak k8s/deployment.yaml
fi
if [ -f "k8s/service.yaml.bak" ]; then
    mv k8s/service.yaml.bak k8s/service.yaml
fi

# Remove GKE-specific job files
rm -f k8s/k6-rest-ramp-job-gke.yaml
rm -f k8s/k6-grpc-ramp-job-gke.yaml

echo -e "${GREEN}🎉 Cleanup completed!${NC}"
echo -e "${YELLOW}💡 Note: This script doesn't delete the GCP project or disable APIs${NC}"
echo -e "${YELLOW}💡 If you want to completely clean up, you may also want to:${NC}"
echo -e "   • Delete any remaining images in Artifact Registry manually"
echo -e "   • Check for any other resources in the GCP Console" 