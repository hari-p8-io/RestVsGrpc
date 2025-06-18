#!/bin/bash

set -e

echo "========================================================"
echo "REST vs gRPC Comprehensive Performance Comparison"
echo "Testing: 20 TPS, 80 TPS, and 100 TPS"
echo "Duration: 2 minutes each test"
echo "========================================================"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Results storage using temporary files instead of associative arrays
RESULTS_DIR="/tmp/k6-results"
mkdir -p $RESULTS_DIR

# Function to wait for job completion and extract metrics
wait_for_job_and_extract_metrics() {
    local job_name=$1
    local timeout=${2:-300}
    local test_type=$3
    local tps=$4
    
    echo -e "${BLUE}Waiting for job $job_name to complete...${NC}"
    kubectl wait --for=condition=complete --timeout=${timeout}s job/$job_name || {
        echo -e "${RED}❌ Job $job_name failed or timed out${NC}"
        return 1
    }
    
    echo -e "${GREEN}✅ Job $job_name completed successfully${NC}"
    
    # Get logs and extract metrics
    local logs=$(kubectl logs job/$job_name)
    
    # Extract key metrics from k6 output
    if [[ $test_type == "grpc" ]]; then
        # Extract gRPC specific metrics
        local avg_duration=$(echo "$logs" | grep "grpc_duration" | grep -o "avg=[0-9.]*" | cut -d= -f2 || echo "0")
        local p95_duration=$(echo "$logs" | grep "grpc_duration" | grep -o "p(95)=[0-9.]*" | cut -d= -f2 || echo "0")
        local max_duration=$(echo "$logs" | grep "grpc_duration" | grep -o "max=[0-9.]*" | cut -d= -f2 || echo "0")
        local total_requests=$(echo "$logs" | grep "grpc calls" | grep -o "[0-9]*" | head -1 || echo "0")
        local failed_requests=$(echo "$logs" | grep "grpc_failed" | grep -o "[0-9.]*%" | sed 's/%//' || echo "0")
        local actual_rps=$(echo "$logs" | grep "grpc calls" | grep -o "[0-9.]*\/s" | cut -d/ -f1 || echo "0")
    else
        # Extract REST/HTTP specific metrics  
        local avg_duration=$(echo "$logs" | grep "http_req_duration" | grep -o "avg=[0-9.]*" | cut -d= -f2 || echo "0")
        local p95_duration=$(echo "$logs" | grep "http_req_duration" | grep -o "p(95)=[0-9.]*" | cut -d= -f2 || echo "0")
        local max_duration=$(echo "$logs" | grep "http_req_duration" | grep -o "max=[0-9.]*" | cut -d= -f2 || echo "0")
        local total_requests=$(echo "$logs" | grep "http_reqs" | grep -o "[0-9]*" | head -1 || echo "0")
        local failed_requests=$(echo "$logs" | grep "http_req_failed" | grep -o "[0-9.]*%" | sed 's/%//' || echo "0")
        local actual_rps=$(echo "$logs" | grep "http_reqs" | grep -o "[0-9.]*\/s" | cut -d/ -f1 || echo "0")
    fi
    
    # Store results in temporary files
    echo "$avg_duration" > "$RESULTS_DIR/${test_type}_${tps}_avg"
    echo "$p95_duration" > "$RESULTS_DIR/${test_type}_${tps}_p95"
    echo "$max_duration" > "$RESULTS_DIR/${test_type}_${tps}_max"
    echo "$total_requests" > "$RESULTS_DIR/${test_type}_${tps}_total"
    echo "$failed_requests" > "$RESULTS_DIR/${test_type}_${tps}_failed"
    echo "$actual_rps" > "$RESULTS_DIR/${test_type}_${tps}_rps"
    
    echo -e "${YELLOW}Metrics extracted: Avg=${avg_duration}ms, P95=${p95_duration}ms, Requests=${total_requests}, Failed=${failed_requests}%${NC}"
}

# Function to create and run a job
create_and_run_job() {
    local job_name=$1
    local script_name=$2
    local test_type=$3
    local tps=$4
    
    echo -e "${BLUE}Creating and running job: $job_name${NC}"
    
    # Delete existing job if it exists
    kubectl delete job $job_name --ignore-not-found=true
    
    # Create job manifest
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  namespace: default
  labels:
    test-type: $test_type
    tps: "$tps"
spec:
  template:
    metadata:
      labels:
        test-type: $test_type
    spec:
      restartPolicy: Never
      containers:
      - name: k6
        image: grafana/k6:latest
        imagePullPolicy: Always
        command: ["k6"]
        args: ["run", "--out", "json=/tmp/results.json", "/scripts/$script_name"]
        volumeMounts:
        - name: k6-scripts
          mountPath: /scripts
        workingDir: /scripts
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: K6_NO_CONNECTION_REUSE
          value: "false"
      volumes:
      - name: k6-scripts
        configMap:
          name: k6-comprehensive-scripts
EOF
    
    wait_for_job_and_extract_metrics $job_name 400 $test_type $tps
}

# Function to generate comparison table
generate_comparison_table() {
    echo ""
    echo "========================================================"
    echo "📊 COMPREHENSIVE PERFORMANCE COMPARISON RESULTS"
    echo "========================================================"
    echo ""
    
    # Table header
    printf "%-12s | %-8s | %-10s | %-10s | %-10s | %-12s | %-10s | %-10s\n" \
           "Protocol" "TPS" "Avg (ms)" "P95 (ms)" "Max (ms)" "Total Reqs" "Failed %" "Actual RPS"
    echo "-------------|----------|------------|------------|------------|--------------|------------|------------"
    
    # Function to read result file or return N/A
    get_result() {
        local file="$RESULTS_DIR/$1"
        if [[ -f "$file" ]]; then
            cat "$file"
        else
            echo "N/A"
        fi
    }
    
    # Generate rows for each test
    for tps in 20 80 100; do
        # REST row
        printf "%-12s | %-8s | %-10s | %-10s | %-10s | %-12s | %-10s | %-10s\n" \
               "REST" "$tps" \
               "$(get_result rest_${tps}_avg)" \
               "$(get_result rest_${tps}_p95)" \
               "$(get_result rest_${tps}_max)" \
               "$(get_result rest_${tps}_total)" \
               "$(get_result rest_${tps}_failed)" \
               "$(get_result rest_${tps}_rps)"
        
        # gRPC row
        printf "%-12s | %-8s | %-10s | %-10s | %-10s | %-12s | %-10s | %-10s\n" \
               "gRPC" "$tps" \
               "$(get_result grpc_${tps}_avg)" \
               "$(get_result grpc_${tps}_p95)" \
               "$(get_result grpc_${tps}_max)" \
               "$(get_result grpc_${tps}_total)" \
               "$(get_result grpc_${tps}_failed)" \
               "$(get_result grpc_${tps}_rps)"
        
        echo "-------------|----------|------------|------------|------------|--------------|------------|------------"
    done
    
    echo ""
    echo "📈 PERFORMANCE INSIGHTS:"
    echo ""
    
    # Calculate performance differences
    for tps in 20 80 100; do
        rest_avg=$(get_result rest_${tps}_avg)
        grpc_avg=$(get_result grpc_${tps}_avg)
        
        if [[ "$rest_avg" != "N/A" && "$grpc_avg" != "N/A" && "$rest_avg" != "0" && "$grpc_avg" != "0" ]]; then
            improvement=$(echo "scale=2; (($rest_avg - $grpc_avg) / $rest_avg) * 100" | bc -l 2>/dev/null || echo "0")
            echo "  • At ${tps} TPS: gRPC is ${improvement}% faster than REST (avg response time)"
        fi
    done
    
    echo ""
    echo "✅ Test completed successfully!"
}

# Main execution flow
echo "🚀 Starting comprehensive performance tests..."

# Check if service is running
echo "Checking service status..."
kubectl get pods -l app=rest-grpc-service

# Deploy the comprehensive ConfigMap
echo "Deploying test scripts..."
kubectl apply -f k8s/k6-comprehensive-configmap.yaml

# Wait a moment for ConfigMap to be available
sleep 2

echo ""
echo "📋 Test execution plan:"
echo "  1. REST 20 TPS (2 min)"
echo "  2. gRPC 20 TPS (2 min)"
echo "  3. REST 80 TPS (2 min)"
echo "  4. gRPC 80 TPS (2 min)"
echo "  5. REST 100 TPS (2 min)"
echo "  6. gRPC 100 TPS (2 min)"
echo "  Total estimated time: ~12 minutes"
echo ""

# Run tests sequentially
echo "🔄 Starting test sequence..."

# 20 TPS Tests
echo -e "${YELLOW}=== 20 TPS Tests ===${NC}"
create_and_run_job "k6-rest-20tps-test" "k6-rest-20tps.js" "rest" "20"
sleep 5
create_and_run_job "k6-grpc-20tps-test" "k6-grpc-20tps.js" "grpc" "20"
sleep 5

# 80 TPS Tests
echo -e "${YELLOW}=== 80 TPS Tests ===${NC}"
create_and_run_job "k6-rest-80tps-test" "k6-rest-80tps.js" "rest" "80"
sleep 5
create_and_run_job "k6-grpc-80tps-test" "k6-grpc-80tps.js" "grpc" "80"
sleep 5

# 100 TPS Tests
echo -e "${YELLOW}=== 100 TPS Tests ===${NC}"
create_and_run_job "k6-rest-100tps-test" "k6-rest-100tps.js" "rest" "100"
sleep 5
create_and_run_job "k6-grpc-100tps-test" "k6-grpc-100tps.js" "grpc" "100"

# Generate final comparison table
generate_comparison_table

# Cleanup
echo ""
echo "🧹 Cleaning up test jobs..."
kubectl delete job k6-rest-20tps-test k6-grpc-20tps-test --ignore-not-found=true
kubectl delete job k6-rest-80tps-test k6-grpc-80tps-test --ignore-not-found=true
kubectl delete job k6-rest-100tps-test k6-grpc-100tps-test --ignore-not-found=true

echo ""
echo "🎉 Comprehensive performance testing completed!" 