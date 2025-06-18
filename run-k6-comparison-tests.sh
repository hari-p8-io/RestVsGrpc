#!/bin/bash

set -e

echo "========================================"
echo "REST vs gRPC Performance Comparison Test"
echo "20 TPS for 2 minutes each"
echo "========================================"

# Function to wait for job completion
wait_for_job() {
    local job_name=$1
    local timeout=${2:-300}
    
    echo "Waiting for job $job_name to complete..."
    kubectl wait --for=condition=complete --timeout=${timeout}s job/$job_name
    
    if kubectl get job $job_name -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        echo "✅ Job $job_name completed successfully"
        return 0
    else
        echo "❌ Job $job_name failed or timed out"
        return 1
    fi
}

# Function to get job logs
get_job_logs() {
    local job_name=$1
    echo "📊 Getting logs for $job_name..."
    kubectl logs job/$job_name --tail=50
}

# Function to cleanup job
cleanup_job() {
    local job_name=$1
    echo "🧹 Cleaning up job $job_name..."
    kubectl delete job $job_name --ignore-not-found=true
}

# Clean up any existing jobs and apply ConfigMap
echo "🧹 Cleaning up any existing test jobs..."
cleanup_job "k6-rest-20tps-test"
cleanup_job "k6-grpc-20tps-test"

echo "📦 Applying ConfigMap with k6 scripts..."
kubectl apply -f k8s/k6-configmap.yaml

# Wait a moment for ConfigMap to be ready
sleep 2

echo ""
echo "🚀 Starting REST 20 TPS Test..."
echo "========================================"
kubectl apply -f k8s/k6-rest-job.yaml

if wait_for_job "k6-rest-20tps-test" 300; then
    echo ""
    echo "📊 REST Test Results:"
    echo "===================="
    get_job_logs "k6-rest-20tps-test"
    
    # Wait a bit before starting the next test
    echo ""
    echo "⏱️  Waiting 30 seconds before starting gRPC test..."
    sleep 30
    
    echo ""
    echo "🚀 Starting gRPC 20 TPS Test..."
    echo "========================================"
    kubectl apply -f k8s/k6-grpc-job.yaml
    
    if wait_for_job "k6-grpc-20tps-test" 300; then
        echo ""
        echo "📊 gRPC Test Results:"
        echo "===================="
        get_job_logs "k6-grpc-20tps-test"
        
        echo ""
        echo "✅ Both tests completed successfully!"
        echo ""
        echo "📋 Test Summary:"
        echo "================"
        echo "REST Test Job: k6-rest-20tps-test"
        echo "gRPC Test Job: k6-grpc-20tps-test"
        echo ""
        echo "To view detailed logs again:"
        echo "kubectl logs job/k6-rest-20tps-test"
        echo "kubectl logs job/k6-grpc-20tps-test"
        echo ""
        echo "To clean up the jobs:"
        echo "kubectl delete job k6-rest-20tps-test k6-grpc-20tps-test"
        
    else
        echo "❌ gRPC test failed!"
        get_job_logs "k6-grpc-20tps-test"
        exit 1
    fi
else
    echo "❌ REST test failed!"
    get_job_logs "k6-rest-20tps-test"
    exit 1
fi

echo ""
echo "🎉 Performance comparison test completed!" 