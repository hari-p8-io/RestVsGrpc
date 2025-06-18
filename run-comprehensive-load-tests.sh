#!/bin/bash

# Comprehensive Load Testing Script for REST vs gRPC on GCP
# Tests all three protocols (REST, gRPC Unary, gRPC Streaming) at 20, 60, and 100 TPS

set -e

# Environment variable configuration
CLIENT_BASE_URL=${CLIENT_BASE_URL:-"http://localhost:9090"}
MAIN_SERVICE_URL=${MAIN_SERVICE_URL:-"http://localhost:8080"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_color() {
    echo -e "${1}${2}${NC}"
}

# Validate environment variables
validate_environment() {
    echo_color $BLUE "🔧 Validating environment configuration..."
    
    if [[ "$CLIENT_BASE_URL" == "http://localhost:9090" ]]; then
        echo_color $YELLOW "⚠️  Using default CLIENT_BASE_URL: $CLIENT_BASE_URL"
        echo_color $YELLOW "   Set CLIENT_BASE_URL environment variable for production use"
    else
        echo_color $GREEN "✅ CLIENT_BASE_URL configured: $CLIENT_BASE_URL"
    fi
    
    if [[ "$MAIN_SERVICE_URL" == "http://localhost:8080" ]]; then
        echo_color $YELLOW "⚠️  Using default MAIN_SERVICE_URL: $MAIN_SERVICE_URL"
        echo_color $YELLOW "   Set MAIN_SERVICE_URL environment variable for production use"
    else
        echo_color $GREEN "✅ MAIN_SERVICE_URL configured: $MAIN_SERVICE_URL"
    fi
}

# Function to check for service errors
check_service_logs() {
    local test_name=$1
    echo_color $BLUE "🔍 Checking service logs for errors during $test_name..."
    
    # Check main service logs
    local main_errors=$(kubectl logs rest-grpc-service-6484c86d99-rqpzf --tail=50 | grep -i "error\|exception\|failed" | wc -l)
    
    # Check client service logs  
    local client_errors=$(kubectl logs $(kubectl get pods -l app=rest-grpc-client -o jsonpath='{.items[0].metadata.name}') --tail=50 | grep -i "error\|exception\|failed" | wc -l)
    
    if [ $main_errors -gt 0 ] || [ $client_errors -gt 0 ]; then
        echo_color $RED "⚠️  Found $main_errors errors in main service and $client_errors errors in client service"
        echo_color $YELLOW "📋 Recent main service logs:"
        kubectl logs rest-grpc-service-6484c86d99-rqpzf --tail=20
        echo_color $YELLOW "📋 Recent client service logs:"
        kubectl logs $(kubectl get pods -l app=rest-grpc-client -o jsonpath='{.items[0].metadata.name}') --tail=20
        return 1
    else
        echo_color $GREEN "✅ No errors found in service logs"
        return 0
    fi
}

# Function to run a specific test
run_test() {
    local protocol=$1
    local tps=$2
    local script_name=$3
    
    echo_color $BLUE "🚀 Starting $protocol test at $tps TPS..."
    echo_color $YELLOW "📊 Script: $script_name"
    echo_color $YELLOW "⏰ Start time: $(date)"
    
    # Run the K6 test with environment variables
    if CLIENT_BASE_URL="$CLIENT_BASE_URL" k6 run $script_name; then
        echo_color $GREEN "✅ $protocol test at $tps TPS completed successfully"
        
        # Check for service errors
        if check_service_logs "$protocol at $tps TPS"; then
            echo_color $GREEN "✅ No service errors detected"
        else
            echo_color $RED "❌ Service errors detected during $protocol test at $tps TPS"
            return 1
        fi
    else
        echo_color $RED "❌ $protocol test at $tps TPS failed"
        return 1
    fi
    
    echo_color $YELLOW "⏰ End time: $(date)"
    echo_color $BLUE "⏳ Waiting 30 seconds before next test..."
    sleep 30
}

# Function to create higher TPS scripts
create_higher_tps_scripts() {
    local tps=$1
    
    # Create REST script for this TPS
    cat > "k6-gcp-rest-${tps}tps.js" << EOF
// K6 Load Test Script for GCP REST Endpoints - ${tps} TPS
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const CLIENT_BASE_URL = __ENV.CLIENT_BASE_URL || 'http://localhost:9090';
const restRequests = new Counter('rest_requests_total');
const restErrorRate = new Rate('rest_error_rate');
const restResponseTime = new Trend('rest_response_time');

export const options = {
  stages: [
    { duration: '30s', target: ${tps} },
    { duration: '3m', target: ${tps} },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.1'],
    rest_response_time: ['p(95)<3000'],
    rest_error_rate: ['rate<0.1'],
  },
};

export default function () {
  const payload = {
    id: \`rest-${tps}tps-\${__VU}-\${__ITER}\`,
    content: \`REST load test at ${tps} TPS - VU \${__VU} iteration \${__ITER}\`,
    timestamp: new Date().toISOString(),
    protocol: 'REST'
  };

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };
  const startTime = Date.now();
  const response = http.post(\`\${CLIENT_BASE_URL}/api/benchmark/rest\`, JSON.stringify(payload), params);
  const duration = Date.now() - startTime;

  restRequests.add(1);
  restResponseTime.add(duration);

  const success = check(response, {
    'REST status is 200': (r) => r.status === 200,
    'REST response time < 10000ms': () => duration < 10000,
    'REST response contains success': (r) => r.body.includes('success'),
  });

  if (!success) {
    restErrorRate.add(1);
    console.error(\`REST request failed: \${response.status} - \${response.body}\`);
  } else {
    restErrorRate.add(0);
  }

  sleep(1);
}

export function handleSummary(data) {
  return { 'rest-${tps}tps-results.json': JSON.stringify(data, null, 2) };
}
EOF

    # Create gRPC Unary script for this TPS
    cat > "k6-gcp-grpc-unary-${tps}tps.js" << EOF
// K6 Load Test Script for GCP gRPC Unary Endpoints - ${tps} TPS
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const CLIENT_BASE_URL = __ENV.CLIENT_BASE_URL || 'http://localhost:9090';
const grpcUnaryRequests = new Counter('grpc_unary_requests_total');
const grpcUnaryErrorRate = new Rate('grpc_unary_error_rate');
const grpcUnaryResponseTime = new Trend('grpc_unary_response_time');

export const options = {
  stages: [
    { duration: '30s', target: ${tps} },
    { duration: '3m', target: ${tps} },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.1'],
    grpc_unary_response_time: ['p(95)<3000'],
    grpc_unary_error_rate: ['rate<0.1'],
  },
};

export default function () {
  const payload = {
    id: \`grpc-unary-${tps}tps-\${__VU}-\${__ITER}\`,
    content: \`gRPC Unary load test at ${tps} TPS - VU \${__VU} iteration \${__ITER}\`,
    timestamp: new Date().toISOString(),
    protocol: 'gRPC_Unary'
  };

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };
  const startTime = Date.now();
  const response = http.post(\`\${CLIENT_BASE_URL}/api/benchmark/grpc/unary\`, JSON.stringify(payload), params);
  const duration = Date.now() - startTime;

  grpcUnaryRequests.add(1);
  grpcUnaryResponseTime.add(duration);

  const success = check(response, {
    'gRPC Unary status is 200': (r) => r.status === 200,
    'gRPC Unary response time < 10000ms': () => duration < 10000,
    'gRPC Unary response contains success': (r) => r.body.includes('success'),
  });

  if (!success) {
    grpcUnaryErrorRate.add(1);
    console.error(\`gRPC Unary request failed: \${response.status} - \${response.body}\`);
  } else {
    grpcUnaryErrorRate.add(0);
  }

  sleep(1);
}

export function handleSummary(data) {
  return { 'grpc-unary-${tps}tps-results.json': JSON.stringify(data, null, 2) };
}
EOF

    # Create gRPC Streaming script for this TPS
    cat > "k6-gcp-grpc-streaming-${tps}tps.js" << EOF
// K6 Load Test Script for GCP gRPC Streaming Endpoints - ${tps} TPS
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const CLIENT_BASE_URL = __ENV.CLIENT_BASE_URL || 'http://localhost:9090';
const grpcStreamingRequests = new Counter('grpc_streaming_requests_total');
const grpcStreamingErrorRate = new Rate('grpc_streaming_error_rate');
const grpcStreamingResponseTime = new Trend('grpc_streaming_response_time');

export const options = {
  stages: [
    { duration: '30s', target: ${tps} },
    { duration: '3m', target: ${tps} },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.1'],
    grpc_streaming_response_time: ['p(95)<3000'],
    grpc_streaming_error_rate: ['rate<0.1'],
  },
};

export default function () {
  const payload = {
    id: \`grpc-streaming-${tps}tps-\${__VU}-\${__ITER}\`,
    content: \`gRPC Streaming load test at ${tps} TPS - VU \${__VU} iteration \${__ITER}\`,
    timestamp: new Date().toISOString(),
    protocol: 'gRPC_Streaming'
  };

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };
  const startTime = Date.now();
  const response = http.post(\`\${CLIENT_BASE_URL}/api/benchmark/grpc/streaming\`, JSON.stringify(payload), params);
  const duration = Date.now() - startTime;

  grpcStreamingRequests.add(1);
  grpcStreamingResponseTime.add(duration);

  const success = check(response, {
    'gRPC Streaming status is 200': (r) => r.status === 200,
    'gRPC Streaming response time < 10000ms': () => duration < 10000,
    'gRPC Streaming response contains success': (r) => r.body.includes('success'),
  });

  if (!success) {
    grpcStreamingErrorRate.add(1);
    console.error(\`gRPC Streaming request failed: \${response.status} - \${response.body}\`);
  } else {
    grpcStreamingErrorRate.add(0);
  }

  sleep(1);
}

export function handleSummary(data) {
  return { 'grpc-streaming-${tps}tps-results.json': JSON.stringify(data, null, 2) };
}
EOF
}

# Main execution
echo_color $GREEN "🚀 Starting Comprehensive Load Testing Suite"
echo_color $BLUE "📅 Test execution started at: $(date)"

# Validate environment configuration
validate_environment

# Check if services are healthy before starting
echo_color $BLUE "🔍 Checking service health..."
if ! curl -s "${CLIENT_BASE_URL}/actuator/health" | grep -q "UP"; then
    echo_color $RED "❌ Client service is not healthy at ${CLIENT_BASE_URL}"
    exit 1
fi

if ! curl -s "${MAIN_SERVICE_URL}/camel/api/health" | grep -q "UP"; then
    echo_color $RED "❌ Main service is not healthy at ${MAIN_SERVICE_URL}"
    exit 1
fi

echo_color $GREEN "✅ All services are healthy"

# Create scripts for 60 and 100 TPS
echo_color $BLUE "📝 Creating test scripts for higher TPS levels..."
create_higher_tps_scripts 60
create_higher_tps_scripts 100

# Initialize results tracking
echo "Protocol,TPS,Avg_Response_Time_ms,P95_Response_Time_ms,P99_Response_Time_ms,Error_Rate_%,Total_Requests,RPS" > comprehensive_test_results.csv

# Test execution order: 20 TPS -> 60 TPS -> 100 TPS for each protocol
declare -a tps_levels=("20" "60" "100")
declare -a protocols=("REST" "gRPC_Unary" "gRPC_Streaming")

for tps in "${tps_levels[@]}"; do
    echo_color $GREEN "🔄 Testing at $tps TPS level"
    
    # REST Test
    if run_test "REST" "$tps" "k6-gcp-rest-${tps}tps.js"; then
        echo_color $GREEN "✅ REST test at $tps TPS completed successfully"
    else
        echo_color $RED "❌ REST test at $tps TPS failed - stopping execution"
        exit 1
    fi
    
    # gRPC Unary Test
    if run_test "gRPC_Unary" "$tps" "k6-gcp-grpc-unary-${tps}tps.js"; then
        echo_color $GREEN "✅ gRPC Unary test at $tps TPS completed successfully"
    else
        echo_color $RED "❌ gRPC Unary test at $tps TPS failed - stopping execution"
        exit 1
    fi
    
    # gRPC Streaming Test
    if run_test "gRPC_Streaming" "$tps" "k6-gcp-grpc-streaming-${tps}tps.js"; then
        echo_color $GREEN "✅ gRPC Streaming test at $tps TPS completed successfully"
    else
        echo_color $RED "❌ gRPC Streaming test at $tps TPS failed - stopping execution"
        exit 1
    fi
    
    echo_color $GREEN "🎉 All tests at $tps TPS completed successfully!"
    echo_color $BLUE "⏳ Waiting 60 seconds before next TPS level..."
    sleep 60
done

echo_color $GREEN "🎉 All comprehensive load tests completed successfully!"
echo_color $BLUE "📊 Results saved in individual JSON files and comprehensive_test_results.csv"
echo_color $BLUE "📅 Test execution completed at: $(date)" 