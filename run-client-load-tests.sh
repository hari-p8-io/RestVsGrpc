#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}REST vs gRPC CLIENT LOAD TEST SUITE${NC}"
echo -e "${BLUE}============================================${NC}"

# Check if K6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}Error: K6 is not installed. Please install K6 first.${NC}"
    echo -e "${YELLOW}Install K6: https://k6.io/docs/getting-started/installation/${NC}"
    exit 1
fi

# Check if client is running
echo -e "${YELLOW}Checking if RestGrpcClient is running on port 9090...${NC}"
if ! curl -s http://localhost:9090/api/benchmark/health > /dev/null; then
    echo -e "${RED}Error: RestGrpcClient is not running on port 9090${NC}"
    echo -e "${YELLOW}Please start the client application first:${NC}"
    echo -e "${YELLOW}cd rest-grpc-client && mvn spring-boot:run${NC}"
    exit 1
fi

echo -e "${GREEN}✓ RestGrpcClient is running${NC}"

# Check if main service is running
echo -e "${YELLOW}Checking if RestVsGrpc service is running on port 8080...${NC}"
if ! curl -s http://localhost:8080/camel/api/health > /dev/null; then
    echo -e "${RED}Error: RestVsGrpc service is not running on port 8080${NC}"
    echo -e "${YELLOW}Please start the main service first:${NC}"
    echo -e "${YELLOW}mvn spring-boot:run${NC}"
    exit 1
fi

echo -e "${GREEN}✓ RestVsGrpc service is running${NC}"
echo ""

# Create results directory
mkdir -p load-test-results
cd load-test-results || exit 1

# Function to run a load test
run_load_test() {
    local test_name=$1
    local script_file=$2
    local result_file=$3
    
    echo -e "${BLUE}Starting $test_name load test...${NC}"
    echo -e "${YELLOW}This will take approximately 4.5 minutes${NC}"
    
    # Run K6 test
    k6 run "../$script_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name load test completed successfully${NC}"
        if [ -f "$result_file" ]; then
            echo -e "${YELLOW}Results saved to: load-test-results/$result_file${NC}"
        fi
    else
        echo -e "${RED}✗ $test_name load test failed${NC}"
        return 1
    fi
    echo ""
}

# Run all load tests
echo -e "${BLUE}Running load tests sequentially...${NC}"
echo ""

# Test 1: REST
run_load_test "REST Client" "k6-client-rest-load.js" "rest-load-test-results.json"

# Test 2: gRPC Unary
run_load_test "gRPC Unary Client" "k6-client-grpc-unary-load.js" "grpc-unary-load-test-results.json"

# Test 3: gRPC Streaming
run_load_test "gRPC Streaming Client" "k6-client-grpc-streaming-load.js" "grpc-streaming-load-test-results.json"

# Generate comparison report
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}LOAD TEST COMPARISON REPORT${NC}"
echo -e "${BLUE}============================================${NC}"

# Function to extract metrics from JSON
extract_metrics() {
    local file=$1
    if [ -f "$file" ]; then
        local total_requests=$(jq -r '.metrics.http_reqs.count // 0' "$file")
        local failed_requests=$(jq -r '.metrics.errors.count // 0' "$file")
        local avg_response_time=$(jq -r '.metrics.http_req_duration.avg // 0' "$file")
        local p95_response_time=$(jq -r '.metrics.http_req_duration["p(95)"] // 0' "$file")
        local max_response_time=$(jq -r '.metrics.http_req_duration.max // 0' "$file")
        local requests_per_sec=$(jq -r '.metrics.http_req_rate.rate // 0' "$file")
        local error_rate=$(echo "scale=2; $failed_requests * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
        
        printf "%-20s: %10s requests\n" "Total Requests" "$total_requests"
        printf "%-20s: %10s requests\n" "Failed Requests" "$failed_requests"
        printf "%-20s: %10.2f%%\n" "Error Rate" "$error_rate"
        printf "%-20s: %10.2f ms\n" "Avg Response Time" "$avg_response_time"
        printf "%-20s: %10.2f ms\n" "95th Percentile" "$p95_response_time"
        printf "%-20s: %10.2f ms\n" "Max Response Time" "$max_response_time"
        printf "%-20s: %10.2f req/s\n" "Throughput" "$requests_per_sec"
    else
        echo "Results file not found: $file"
    fi
}

# Display results
if [ -f "rest-load-test-results.json" ]; then
    echo -e "${GREEN}REST CLIENT RESULTS:${NC}"
    extract_metrics "rest-load-test-results.json"
    echo ""
fi

if [ -f "grpc-unary-load-test-results.json" ]; then
    echo -e "${GREEN}gRPC UNARY CLIENT RESULTS:${NC}"
    extract_metrics "grpc-unary-load-test-results.json"
    echo ""
fi

if [ -f "grpc-streaming-load-test-results.json" ]; then
    echo -e "${GREEN}gRPC STREAMING CLIENT RESULTS:${NC}"
    extract_metrics "grpc-streaming-load-test-results.json"
    echo ""
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}All load tests completed!${NC}"
echo -e "${YELLOW}Results are saved in the 'load-test-results' directory${NC}"
echo -e "${BLUE}============================================${NC}"

cd .. 