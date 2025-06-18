#!/bin/bash

# K6 Test Runner Script for GKE
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧪 Running K6 Performance Tests on GKE...${NC}"

# Function to wait for job completion and show logs
wait_for_job_and_show_logs() {
    local job_name=$1
    local test_type=$2
    
    echo -e "${YELLOW}⏳ Waiting for $test_type test to complete...${NC}"
    
    # Wait for job to complete (max 10 minutes)
    kubectl wait --for=condition=complete --timeout=600s job/$job_name || {
        echo -e "${RED}❌ Job $job_name timed out or failed${NC}"
        kubectl describe job $job_name
        return 1
    }
    
    echo -e "${GREEN}✅ $test_type test completed!${NC}"
    
    # Get pod name and show logs
    POD_NAME=$(kubectl get pods --selector=job-name=$job_name -o jsonpath='{.items[0].metadata.name}')
    echo -e "${BLUE}📊 $test_type Test Results:${NC}"
    kubectl logs $POD_NAME
    
    # Clean up job
    echo -e "${YELLOW}🧹 Cleaning up $test_type test job...${NC}"
    kubectl delete job $job_name
}

# Check if service is ready
echo -e "${YELLOW}🔍 Checking if rest-grpc-service is ready...${NC}"
kubectl get service rest-grpc-service

# Get external IP
EXTERNAL_IP=""
while [ -z $EXTERNAL_IP ]; do
    echo -e "${YELLOW}⏳ Waiting for external IP...${NC}"
    EXTERNAL_IP=$(kubectl get service rest-grpc-service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo -e "${GREEN}🌐 External IP obtained: $EXTERNAL_IP${NC}"

# Check if the service is responding
echo -e "${YELLOW}🔍 Testing service connectivity...${NC}"
for i in {1..30}; do
    if curl -f -s http://$EXTERNAL_IP:8080/actuator/health > /dev/null; then
        echo -e "${GREEN}✅ Service is responding!${NC}"
        break
    else
        echo -e "${YELLOW}⏳ Waiting for service to be ready... (attempt $i/30)${NC}"
        sleep 10
    fi
    
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Service is not responding after 5 minutes. Please check the deployment.${NC}"
        kubectl get pods
        kubectl describe service rest-grpc-service
        exit 1
    fi
done

# Show service health
echo -e "${BLUE}🏥 Service Health Check:${NC}"
curl -s http://$EXTERNAL_IP:8080/actuator/health | jq '.' 2>/dev/null || curl -s http://$EXTERNAL_IP:8080/actuator/health

# Run REST performance test
echo -e "${GREEN}🚀 Starting REST Performance Test...${NC}"
kubectl apply -f k8s/k6-rest-ramp-job-gke.yaml

wait_for_job_and_show_logs "k6-rest-ramp-loadtest-gke" "REST"

echo -e "${YELLOW}⏸️  Waiting 30 seconds before next test...${NC}"
sleep 30

# Run gRPC performance test  
echo -e "${GREEN}🚀 Starting gRPC Performance Test...${NC}"
kubectl apply -f k8s/k6-grpc-ramp-job-gke.yaml

wait_for_job_and_show_logs "k6-grpc-ramp-loadtest-gke" "gRPC"

echo -e "${GREEN}🎉 All performance tests completed!${NC}"
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "• REST test: Completed"
echo -e "• gRPC test: Completed"
echo -e "• Service URL: http://$EXTERNAL_IP:8080"
echo -e "• gRPC endpoint: $EXTERNAL_IP:6565"

# Optional: Show cluster resource usage
echo -e "${YELLOW}📈 Cluster Resource Usage:${NC}"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl top pods 2>/dev/null || echo "Pod metrics not available" 