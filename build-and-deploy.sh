#!/bin/bash

# Build and Deploy Script for GKE
set -e

# Configuration variables - MUST MATCH gke-setup.sh
PROJECT_ID="silent-oxide-210505"
REGISTRY_LOCATION="australia-southeast2"
REPOSITORY_NAME="rest-grpc-repo"

# Image names
APP_IMAGE_NAME="rest-grpc-service"
K6_IMAGE_NAME="k6-loadtest"

# Full image URLs
APP_IMAGE_URL="${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${APP_IMAGE_NAME}:latest"
K6_IMAGE_URL="${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${K6_IMAGE_NAME}:latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔨 Building and deploying to GKE...${NC}"

# Build the Spring Boot application
echo -e "${YELLOW}📦 Building Spring Boot application...${NC}"
mvn clean package -DskipTests

# Build application Docker image
echo -e "${YELLOW}🐳 Building application Docker image...${NC}"
docker build -t $APP_IMAGE_NAME:latest .

# Build k6 Docker image
echo -e "${YELLOW}🧪 Building k6 test image...${NC}"
docker build -f Dockerfile.k6 -t $K6_IMAGE_NAME:latest .

# Tag images for Artifact Registry
echo -e "${YELLOW}🏷️  Tagging images for Artifact Registry...${NC}"
docker tag $APP_IMAGE_NAME:latest $APP_IMAGE_URL
docker tag $K6_IMAGE_NAME:latest $K6_IMAGE_URL

# Push images to Artifact Registry
echo -e "${YELLOW}📤 Pushing images to Artifact Registry...${NC}"
docker push $APP_IMAGE_URL
docker push $K6_IMAGE_URL

# Update Kubernetes manifests with correct image URLs
echo -e "${YELLOW}⚙️  Updating Kubernetes manifests...${NC}"

# Update deployment.yaml
sed -i.bak "s|image: rest-grpc-service:latest|image: ${APP_IMAGE_URL}|g" k8s/deployment.yaml
sed -i.bak "s|imagePullPolicy: Never|imagePullPolicy: Always|g" k8s/deployment.yaml

# Update service for LoadBalancer (for external access)
sed -i.bak "s|type: NodePort|type: LoadBalancer|g" k8s/service.yaml
sed -i.bak "/nodePort:/d" k8s/service.yaml

# Create GKE-specific manifests
cat > k8s/k6-rest-ramp-job-gke.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-rest-ramp-loadtest-gke
spec:
  template:
    spec:
      containers:
      - name: k6
        image: ${K6_IMAGE_URL}
        imagePullPolicy: Always
        command: ["k6", "run", "k6-rest-cluster.js"]
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
      restartPolicy: Never
  backoffLimit: 1
EOF

cat > k8s/k6-grpc-ramp-job-gke.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-grpc-ramp-loadtest-gke
spec:
  template:
    spec:
      containers:
      - name: k6
        image: ${K6_IMAGE_URL}
        imagePullPolicy: Always
        command: ["k6", "run", "k6-grpc-cluster.js"]
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
      restartPolicy: Never
  backoffLimit: 1
EOF

# Deploy to GKE
echo -e "${YELLOW}🚀 Deploying to GKE cluster...${NC}"

# Deploy RabbitMQ first
echo -e "${YELLOW}🐰 Deploying RabbitMQ...${NC}"
kubectl apply -f k8s/rabbitmq-deployment.yaml

# Wait for RabbitMQ to be ready
echo -e "${YELLOW}⏳ Waiting for RabbitMQ to be ready...${NC}"
kubectl rollout status deployment/rabbitmq --timeout=300s

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for deployment to be ready
echo -e "${YELLOW}⏳ Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/rest-grpc-service --timeout=300s

# Get service information
echo -e "${YELLOW}📋 Getting service information...${NC}"
kubectl get services rest-grpc-service

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${YELLOW}📝 Service is being deployed. It may take a few minutes to get an external IP.${NC}"
echo -e "${YELLOW}💡 Check service status with: kubectl get services rest-grpc-service${NC}"
echo -e "${YELLOW}🧪 Run tests with: ./run-k6-tests.sh${NC}" 