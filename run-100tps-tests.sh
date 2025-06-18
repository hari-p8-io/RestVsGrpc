#!/bin/bash

# K6 Test Runner for 100 TPS with RabbitMQ Integration
set -e

PROJECT_ID="silent-oxide-210505"
REGISTRY_LOCATION="australia-southeast2"
REPOSITORY_NAME="rest-grpc-repo"
K6_IMAGE_URL="${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/k6-loadtest:latest"

echo "🧪 Running 100 TPS Performance Tests with RabbitMQ Integration..."

# Check services
echo "🔍 Checking services..."
kubectl get service rest-grpc-service
kubectl get service rabbitmq-service

# Wait for external IP
echo "⏳ Waiting for external IP..."
while true; do
    EXTERNAL_IP=$(kubectl get service rest-grpc-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
        echo "🌐 External IP: $EXTERNAL_IP"
        break
    fi
    sleep 10
done

# Test connectivity
echo "🔍 Testing connectivity..."
curl -f -s "http://$EXTERNAL_IP:8080/camel/api/health" || exit 1
echo "✅ Service is ready!"

# Function to run test
run_test() {
    local test_file=$1
    local test_name=$2
    local test_name_lc=$(echo "$test_name" | tr '[:upper:]' '[:lower:]')
    
    echo "🚀 Starting $test_name test..."
    
    cat > k8s/k6-${test_name_lc}-job.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-${test_name_lc}-100tps-test
spec:
  template:
    spec:
      containers:
      - name: k6
        image: ${K6_IMAGE_URL}
        imagePullPolicy: Always
        command: ["k6", "run", "/scripts/$test_file"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "2000m"
      restartPolicy: Never
  backoffLimit: 1
EOF
    
    kubectl apply -f k8s/k6-${test_name_lc}-job.yaml
    kubectl wait --for=condition=complete --timeout=300s job/k6-${test_name_lc}-100tps-test
    
    echo "📊 $test_name Test Results:"
    kubectl logs job/k6-${test_name_lc}-100tps-test
    
    kubectl delete job k6-${test_name_lc}-100tps-test
    sleep 30
}

# Run tests
if [[ $# -eq 1 ]]; then
    if [[ $1 == *"rest"* ]]; then
        run_test "$1" "REST"
    elif [[ $1 == *"grpc"* ]]; then
        run_test "$1" "gRPC"
    fi
else
    run_test "k6-rest-100tps-rabbitmq.js" "REST"
    run_test "k6-grpc-100tps-rabbitmq.js" "gRPC"
fi

echo "🎉 Tests completed!" 