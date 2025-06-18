#!/bin/bash

set -e

echo "========================================================"
echo "REST vs gRPC Performance Comparison"
echo "Testing: 20 TPS, 80 TPS, and 100 TPS"
echo "Duration: 2 minutes each test"
echo "========================================================"

# Results file
RESULTS_FILE="performance_results.txt"
echo "Protocol,TPS,Avg_ms,P95_ms,Max_ms,Total_Reqs,Failed_Percent,Actual_RPS" > $RESULTS_FILE

# Function to extract metrics from k6 logs
extract_metrics() {
    local logs="$1"
    local test_type="$2"
    local tps="$3"
    
    # Extract metrics based on the actual k6 output format
    local avg_duration=$(echo "$logs" | grep "http_req_duration" | grep "avg=" | grep -o "avg=[0-9.]*ms" | cut -d= -f2 | sed 's/ms//')
    local p95_duration=$(echo "$logs" | grep "http_req_duration" | grep "p(95)=" | grep -o "p(95)=[0-9.]*ms" | cut -d= -f2 | sed 's/ms//')
    local max_duration=$(echo "$logs" | grep "http_req_duration" | grep "max=" | grep -o "max=[0-9.]*ms" | cut -d= -f2 | sed 's/ms//')
    local total_requests=$(echo "$logs" | grep "http_reqs" | grep -o "[0-9]*" | head -1)
    local failed_percent=$(echo "$logs" | grep "http_req_failed" | grep -o "[0-9.]*%" | sed 's/%//')
    local actual_rps=$(echo "$logs" | grep "http_reqs" | grep -o "[0-9.]*\/s" | cut -d/ -f1)
    
    # Handle missing values
    avg_duration=${avg_duration:-"N/A"}
    p95_duration=${p95_duration:-"N/A"}
    max_duration=${max_duration:-"N/A"}
    total_requests=${total_requests:-"N/A"}
    failed_percent=${failed_percent:-"N/A"}
    actual_rps=${actual_rps:-"N/A"}
    
    echo "$test_type,$tps,$avg_duration,$p95_duration,$max_duration,$total_requests,$failed_percent,$actual_rps" >> $RESULTS_FILE
    
    echo "  Results: Avg=${avg_duration}ms, P95=${p95_duration}ms, Requests=${total_requests}, Failed=${failed_percent}%"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local script_name="$2"
    local test_type="$3"
    local tps="$4"
    
    echo "========================================="
    echo "Running $test_type test at $tps TPS..."
    echo "========================================="
    
    # Clean up any existing job
    kubectl delete job $test_name --ignore-not-found=true >/dev/null 2>&1
    
    # Create and run job
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $test_name
  namespace: default
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: k6
        image: grafana/k6:latest
        command: ["k6"]
        args: ["run", "/scripts/$script_name"]
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
      volumes:
      - name: k6-scripts
        configMap:
          name: k6-comprehensive-scripts
EOF
    
    # Wait for completion
    echo "  Waiting for test to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/$test_name
    
    if kubectl get job $test_name -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        echo "  ✅ Test completed successfully"
        
        # Get logs and extract metrics
        local logs=$(kubectl logs job/$test_name)
        extract_metrics "$logs" "$test_type" "$tps"
        
    else
        echo "  ❌ Test failed"
        echo "$test_type,$tps,FAILED,FAILED,FAILED,FAILED,FAILED,FAILED" >> $RESULTS_FILE
    fi
    
    # Clean up
    kubectl delete job $test_name --ignore-not-found=true >/dev/null 2>&1
    sleep 2
}

# Main execution
echo "🚀 Starting performance comparison tests..."

# Check service status
echo "Checking service status..."
kubectl get pods -l app=rest-grpc-service

# Deploy test scripts
echo "Deploying test scripts..."
kubectl apply -f k8s/k6-comprehensive-configmap.yaml >/dev/null

sleep 3

# Run all tests sequentially
run_test "k6-rest-20tps-test" "k6-rest-20tps.js" "REST" "20"
run_test "k6-grpc-20tps-test" "k6-grpc-20tps.js" "gRPC" "20"
run_test "k6-rest-80tps-test" "k6-rest-80tps.js" "REST" "80"
run_test "k6-grpc-80tps-test" "k6-grpc-80tps.js" "gRPC" "80"
run_test "k6-rest-100tps-test" "k6-rest-100tps.js" "REST" "100"
run_test "k6-grpc-100tps-test" "k6-grpc-100tps.js" "gRPC" "100"

# Generate summary table
echo ""
echo "========================================================"
echo "📊 PERFORMANCE COMPARISON RESULTS"
echo "========================================================"
echo ""

# Display the results in a nice table format
printf "%-12s | %-8s | %-10s | %-10s | %-10s | %-12s | %-10s | %-10s\n" \
       "Protocol" "TPS" "Avg (ms)" "P95 (ms)" "Max (ms)" "Total Reqs" "Failed %" "Actual RPS"
echo "-------------|----------|------------|------------|------------|--------------|------------|------------"

# Read and display results
tail -n +2 $RESULTS_FILE | while IFS=',' read -r protocol tps avg p95 max total failed rps; do
    printf "%-12s | %-8s | %-10s | %-10s | %-10s | %-12s | %-10s | %-10s\n" \
           "$protocol" "$tps" "$avg" "$p95" "$max" "$total" "$failed" "$rps"
done

echo "-------------|----------|------------|------------|------------|--------------|------------|------------"

echo ""
echo "📈 PERFORMANCE INSIGHTS:"

# Generate insights by comparing REST vs gRPC for each TPS level
for tps in 20 80 100; do
    rest_avg=$(grep "REST,$tps," $RESULTS_FILE | cut -d, -f3)
    grpc_avg=$(grep "gRPC,$tps," $RESULTS_FILE | cut -d, -f3)
    
    if [[ "$rest_avg" != "N/A" && "$grpc_avg" != "N/A" && "$rest_avg" != "FAILED" && "$grpc_avg" != "FAILED" ]]; then
        if command -v bc >/dev/null 2>&1; then
            improvement=$(echo "scale=2; (($rest_avg - $grpc_avg) / $rest_avg) * 100" | bc -l)
            echo "  • At ${tps} TPS: gRPC is ${improvement}% faster than REST (avg response time)"
        else
            echo "  • At ${tps} TPS: REST avg=${rest_avg}ms, gRPC avg=${grpc_avg}ms"
        fi
    fi
done

echo ""
echo "📄 Detailed results saved to: $RESULTS_FILE"
echo "✅ Performance comparison completed!" 