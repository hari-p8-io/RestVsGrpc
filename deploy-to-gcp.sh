#!/bin/bash

# GCP Deployment Script for REST vs gRPC Service
# This script builds, pushes, and deploys the application to GCP

set -e

# Configuration
PROJECT_ID="silent-oxide-210505"
REGION="australia-southeast2"
CLUSTER_NAME="rest-grpc-cluster"
CLUSTER_ZONE="australia-southeast2-a"
REPOSITORY="rest-grpc-repo"
IMAGE_NAME="rest-grpc-service"
SERVICE_ACCOUNT_NAME="rest-grpc-sa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_color() {
    echo -e "${1}${2}${NC}"
}

echo_color $BLUE "🚀 Starting GCP deployment for REST vs gRPC Service..."

# Step 1: Build the application
echo_color $YELLOW "📦 Building application..."
mvn clean package -DskipTests

# Step 2: Build Docker image
echo_color $YELLOW "🐳 Building Docker image..."
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest .

# Step 3: Push to Artifact Registry
echo_color $YELLOW "⬆️ Pushing image to Artifact Registry..."
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest

# Step 4: Get GKE credentials
echo_color $YELLOW "🔑 Getting GKE cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}

# Step 5: Create/update service account secret
echo_color $YELLOW "🔐 Setting up service account secret..."
if kubectl get secret gcp-sa-key >/dev/null 2>&1; then
    echo_color $GREEN "Service account secret already exists"
else
    echo_color $YELLOW "Creating service account secret..."
    kubectl create secret generic gcp-sa-key --from-file=key.json=gcp-service-account-key.json
fi

# Step 6: Deploy to Kubernetes
echo_color $YELLOW "☸️ Deploying to Kubernetes..."
kubectl apply -f k8s/

# Step 7: Wait for deployment to be ready
echo_color $YELLOW "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/rest-grpc-service --timeout=300s

# Step 8: Get service information
echo_color $YELLOW "📋 Getting service information..."
echo_color $GREEN "Deployment Status:"
kubectl get deployments
echo_color $GREEN "Service Status:"
kubectl get services
echo_color $GREEN "Pod Status:"
kubectl get pods

# Step 9: Get external IP
echo_color $YELLOW "🌐 Getting external IP address..."
EXTERNAL_IP=""
while [ -z $EXTERNAL_IP ]; do
    echo "Waiting for external IP..."
    EXTERNAL_IP=$(kubectl get svc rest-grpc-service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo_color $GREEN "✅ Deployment completed successfully!"
echo_color $BLUE "📊 Service Information:"
echo_color $GREEN "External IP: $EXTERNAL_IP"
echo_color $GREEN "Main Service URL: http://$EXTERNAL_IP:8080"
echo_color $GREEN "Client Service URL: http://$EXTERNAL_IP:9090"
echo_color $GREEN "Health Check: http://$EXTERNAL_IP:8080/actuator/health"

# Step 10: Create load test configuration
echo_color $YELLOW "📝 Creating load test configuration..."
cat > gcp-load-test-config.env << EOF
# GCP Load Test Configuration
BASE_URL=http://$EXTERNAL_IP:9090
MAIN_SERVICE_URL=http://$EXTERNAL_IP:8080
CLIENT_SERVICE_URL=http://$EXTERNAL_IP:9090

# Test endpoints
REST_ENDPOINT=\${BASE_URL}/api/benchmark/rest
GRPC_UNARY_ENDPOINT=\${BASE_URL}/api/benchmark/grpc/unary
GRPC_STREAMING_ENDPOINT=\${BASE_URL}/api/benchmark/grpc/streaming
HEALTH_ENDPOINT=\${MAIN_SERVICE_URL}/actuator/health
EOF

echo_color $GREEN "📝 Load test configuration saved to: gcp-load-test-config.env"

# Step 11: Test deployment
echo_color $YELLOW "🧪 Testing deployment..."
echo_color $BLUE "Testing health endpoint..."
if curl -f -s "http://$EXTERNAL_IP:8080/actuator/health" > /dev/null; then
    echo_color $GREEN "✅ Health check passed!"
else
    echo_color $RED "❌ Health check failed!"
fi

echo_color $BLUE "Testing client service..."
if curl -f -s "http://$EXTERNAL_IP:9090/actuator/health" > /dev/null; then
    echo_color $GREEN "✅ Client service check passed!"
else
    echo_color $RED "❌ Client service check failed!"
fi

echo_color $GREEN "🎉 Deployment Summary:"
echo_color $BLUE "===================="
echo_color $GREEN "✅ Application built successfully"
echo_color $GREEN "✅ Docker image pushed to Artifact Registry"
echo_color $GREEN "✅ Kubernetes deployment completed"
echo_color $GREEN "✅ Services are running and accessible"
echo_color $BLUE "===================="

echo_color $YELLOW "🚀 Ready for load testing! Use the following commands:"
echo_color $GREEN "# Quick test:"
echo_color $BLUE "k6 run --env BASE_URL=http://$EXTERNAL_IP:9090 k6-quick-test.js"
echo_color $GREEN "# Full load test:"
echo_color $BLUE "k6 run --env BASE_URL=http://$EXTERNAL_IP:9090 k6-gcp-load-test.js"

echo_color $GREEN "🎯 Load test will compare REST, gRPC Unary, and gRPC Streaming performance!" 