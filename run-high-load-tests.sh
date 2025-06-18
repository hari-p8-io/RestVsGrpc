#!/bin/bash

set -e

echo "🚀 Running High Load REST vs gRPC Performance Tests (1 minute each)"
echo "📊 Test Configuration: 100 TPS, 300 TPS, 500 TPS"
echo "🔥 Duration: 60 seconds per test"
echo "⚖️  Load Balancing: 2 pod replicas"
echo ""

# Deploy the high-load ConfigMap
kubectl apply -f k8s/k6-high-load-configmap.yaml

# Create temporary files for results
TEMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Using temp directory: $TEMP_DIR"

# Function to run test and extract metrics
run_test() {
    local test_name=$1
    local script_name=$2
    local tps=$3
    local protocol=$4
    
    echo ""
    echo "📊 Running $test_name test ($tps TPS - $protocol)..."
    echo "⏱️  Expected duration: ~60 seconds"
    
    # Create and run the job
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-$test_name-test
  namespace: default
spec:
  ttlSecondsAfterFinished: 120
  template:
    spec:
      containers:
      - name: k6-test
        image: grafana/k6:0.47.0
        command: ["k6", "run", "/scripts/$script_name"]
        volumeMounts:
        - name: k6-scripts
          mountPath: /scripts
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: k6-scripts
        configMap:
          name: k6-high-load-scripts
      restartPolicy: Never
  backoffLimit: 0
EOF

    # Wait for job completion (150s timeout for 60s test + startup time)
    echo "⏳ Waiting for test completion..."
    kubectl wait --for=condition=complete --timeout=150s job/k6-$test_name-test
    
    # Get logs and parse metrics
    LOGS=$(kubectl logs job/k6-$test_name-test)
    echo "$LOGS" > "$TEMP_DIR/$test_name.log"
    
    # Extract metrics based on protocol
    if [[ "$protocol" == "REST" ]]; then
        AVG_TIME=$(echo "$LOGS" | grep "http_req_duration" | sed -n 's/.*avg=\([0-9.]*\)ms.*/\1/p')
        P95_TIME=$(echo "$LOGS" | grep "http_req_duration" | sed -n 's/.*p(95)=\([0-9.]*\)ms.*/\1/p')
        TOTAL_REQS=$(echo "$LOGS" | grep "http_reqs" | sed -n 's/.*http_reqs[^0-9]*\([0-9]*\).*/\1/p')
        FAILED_RATE=$(echo "$LOGS" | grep "http_req_failed" | sed -n 's/.*http_req_failed[^0-9]*\([0-9.]*\)%.*/\1/p')
    else
        # For gRPC, look for grpc_req_duration metric
        AVG_TIME=$(echo "$LOGS" | grep "grpc_req_duration" | sed -n 's/.*avg=\([0-9.]*\)ms.*/\1/p')
        P95_TIME=$(echo "$LOGS" | grep "grpc_req_duration" | sed -n 's/.*p(95)=\([0-9.]*\)ms.*/\1/p')
        # Try to extract total requests from iterations
        TOTAL_REQS=$(echo "$LOGS" | grep "iterations" | sed -n 's/.*iterations[^0-9]*\([0-9]*\).*/\1/p')
        FAILED_RATE=$(echo "$LOGS" | grep "grpc_failed" | sed -n 's/.*grpc_failed[^0-9]*\([0-9.]*\)%.*/\1/p')
    fi
    
    # Fallback for missing metrics
    AVG_TIME=${AVG_TIME:-"N/A"}
    P95_TIME=${P95_TIME:-"N/A"}
    TOTAL_REQS=${TOTAL_REQS:-"N/A"}
    FAILED_RATE=${FAILED_RATE:-"N/A"}
    
    # Store results
    echo "$tps,$protocol,$AVG_TIME,$P95_TIME,$TOTAL_REQS,$FAILED_RATE" > "$TEMP_DIR/$test_name.csv"
    
    echo "✅ $test_name completed - Avg: ${AVG_TIME}ms, P95: ${P95_TIME}ms, Requests: $TOTAL_REQS, Failed: ${FAILED_RATE}%"
    
    # Cleanup job
    kubectl delete job k6-$test_name-test --ignore-not-found=true
}

echo "🏁 Starting High Load Performance Tests..."

# Run REST tests
run_test "rest-100tps" "k6-rest-100tps.js" "100" "REST"
sleep 10
run_test "rest-300tps" "k6-rest-300tps.js" "300" "REST"
sleep 10
run_test "rest-500tps" "k6-rest-500tps.js" "500" "REST"
sleep 10

# Run gRPC tests
run_test "grpc-100tps" "k6-grpc-100tps.js" "100" "gRPC"
sleep 10
run_test "grpc-300tps" "k6-grpc-300tps.js" "300" "gRPC"
sleep 10
run_test "grpc-500tps" "k6-grpc-500tps.js" "500" "gRPC"

echo ""
echo "📈 High Load Performance Comparison Results:"
echo "=============================================================================="
printf "%-8s %-10s %-12s %-12s %-15s %-12s\n" "TPS" "Protocol" "Avg (ms)" "P95 (ms)" "Total Requests" "Failed %"
echo "=============================================================================="

# Sort and display results
for tps in 100 300 500; do
    echo "--- $tps TPS Results ---"
    if [[ -f "$TEMP_DIR/rest-${tps}tps.csv" ]]; then
        cat "$TEMP_DIR/rest-${tps}tps.csv" | while IFS=',' read -r t p avg p95 total failed; do
            printf "%-8s %-10s %-12s %-12s %-15s %-12s\n" "$t" "$p" "$avg" "$p95" "$total" "$failed"
        done
    fi
    if [[ -f "$TEMP_DIR/grpc-${tps}tps.csv" ]]; then
        cat "$TEMP_DIR/grpc-${tps}tps.csv" | while IFS=',' read -r t p avg p95 total failed; do
            printf "%-8s %-10s %-12s %-12s %-15s %-12s\n" "$t" "$p" "$avg" "$p95" "$total" "$failed"
        done
    fi
    echo "------------------------------------------------------------------------------"
done

echo ""
echo "🔍 Detailed logs saved in: $TEMP_DIR"
echo "✅ High load comparison tests completed!"
echo ""
echo "📊 Performance Summary:"
echo "• Tests run against 2 pod replicas with load balancing"
echo "• Each test duration: 60 seconds"
echo "• Load levels: 100, 300, 500 TPS"
echo "• Metrics include average response time, P95, total requests, and failure rate" 