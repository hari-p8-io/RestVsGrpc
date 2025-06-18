// K6 Load Test Script for GCP Deployment
// This script tests REST, gRPC Unary, and gRPC Streaming endpoints
// with comprehensive metrics collection and realistic load patterns

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Configuration - Update BASE_URL for your GCP deployment
const BASE_URL = __ENV.BASE_URL || 'http://localhost:9090';

// Custom metrics
const restRequests = new Counter('rest_requests_total');
const grpcUnaryRequests = new Counter('grpc_unary_requests_total');
const grpcStreamingRequests = new Counter('grpc_streaming_requests_total');
const restErrorRate = new Rate('rest_error_rate');
const grpcUnaryErrorRate = new Rate('grpc_unary_error_rate');
const grpcStreamingErrorRate = new Rate('grpc_streaming_error_rate');
const restResponseTime = new Trend('rest_response_time');
const grpcUnaryResponseTime = new Trend('grpc_unary_response_time');
const grpcStreamingResponseTime = new Trend('grpc_streaming_response_time');

// Load test configuration
export let options = {
  stages: [
    // Warm-up phase
    { duration: '1m', target: 10 },
    // Ramp up to moderate load
    { duration: '2m', target: 50 },
    // Ramp up to high load
    { duration: '2m', target: 100 },
    // Peak load test
    { duration: '5m', target: 100 },
    // Stress test - push to higher load
    { duration: '2m', target: 150 },
    // Spike test
    { duration: '1m', target: 200 },
    // Ramp down
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    http_req_failed: ['rate<0.05'], // Error rate under 5%
    rest_response_time: ['p(95)<1500'],
    grpc_unary_response_time: ['p(95)<1500'],
    grpc_streaming_response_time: ['p(95)<1000'], // Streaming should be faster
    rest_error_rate: ['rate<0.05'],
    grpc_unary_error_rate: ['rate<0.05'],
    grpc_streaming_error_rate: ['rate<0.05'],
  },
};

// Test data generator
function generateTestData(protocol, iteration) {
  return {
    id: `load-test-${protocol}-${__VU}-${iteration}`,
    content: `Load test message for ${protocol} - VU ${__VU}, iteration ${iteration}`,
    timestamp: new Date().toISOString(),
    protocol: protocol
  };
}

// Test functions
function testRestEndpoint(iteration) {
  const payload = generateTestData('REST', iteration);
  const response = http.post(`${BASE_URL}/api/benchmark/rest`, JSON.stringify(payload), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  restRequests.add(1);
  restResponseTime.add(response.timings.duration);
  
  const success = check(response, {
    'REST status is 200': (r) => r.status === 200,
    'REST response time < 3000ms': (r) => r.timings.duration < 3000,
    'REST has status field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  restErrorRate.add(!success);
  return response;
}

function testGrpcUnaryEndpoint(iteration) {
  const payload = generateTestData('gRPC', iteration);
  const response = http.post(`${BASE_URL}/api/benchmark/grpc/unary`, JSON.stringify(payload), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  grpcUnaryRequests.add(1);
  grpcUnaryResponseTime.add(response.timings.duration);
  
  const success = check(response, {
    'gRPC Unary status is 200': (r) => r.status === 200,
    'gRPC Unary response time < 3000ms': (r) => r.timings.duration < 3000,
    'gRPC Unary has status field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  grpcUnaryErrorRate.add(!success);
  return response;
}

function testGrpcStreamingEndpoint(iteration) {
  const payload = generateTestData('gRPC_STREAMING', iteration);
  const response = http.post(`${BASE_URL}/api/benchmark/grpc/streaming`, JSON.stringify(payload), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  grpcStreamingRequests.add(1);
  grpcStreamingResponseTime.add(response.timings.duration);
  
  const success = check(response, {
    'gRPC Streaming status is 200': (r) => r.status === 200,
    'gRPC Streaming response time < 2000ms': (r) => r.timings.duration < 2000,
    'gRPC Streaming has status field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  grpcStreamingErrorRate.add(!success);
  return response;
}

// Main test function
export default function () {
  const iteration = __ITER;
  
  // Distribute load across all three endpoints
  // Each VU will test all three protocols in sequence
  
  // Test REST endpoint
  testRestEndpoint(iteration);
  sleep(0.5);
  
  // Test gRPC Unary endpoint
  testGrpcUnaryEndpoint(iteration);
  sleep(0.5);
  
  // Test gRPC Streaming endpoint
  testGrpcStreamingEndpoint(iteration);
  sleep(0.5);
}

// Custom summary function
export function handleSummary(data) {
  const restReqs = data.metrics.rest_requests_total?.values?.count || 0;
  const grpcUnaryReqs = data.metrics.grpc_unary_requests_total?.values?.count || 0;
  const grpcStreamingReqs = data.metrics.grpc_streaming_requests_total?.values?.count || 0;
  
  const restAvg = data.metrics.rest_response_time?.values?.avg || 0;
  const grpcUnaryAvg = data.metrics.grpc_unary_response_time?.values?.avg || 0;
  const grpcStreamingAvg = data.metrics.grpc_streaming_response_time?.values?.avg || 0;
  
  const restP95 = data.metrics.rest_response_time?.values?.['p(95)'] || 0;
  const grpcUnaryP95 = data.metrics.grpc_unary_response_time?.values?.['p(95)'] || 0;
  const grpcStreamingP95 = data.metrics.grpc_streaming_response_time?.values?.['p(95)'] || 0;
  
  const restErrorRate = (data.metrics.rest_error_rate?.values?.rate || 0) * 100;
  const grpcUnaryErrorRate = (data.metrics.grpc_unary_error_rate?.values?.rate || 0) * 100;
  const grpcStreamingErrorRate = (data.metrics.grpc_streaming_error_rate?.values?.rate || 0) * 100;
  
  const summary = `
╔══════════════════════════════════════════════════════════════════════════════╗
║                           GCP LOAD TEST RESULTS                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ PROTOCOL COMPARISON:                                                         ║
║                                                                              ║
║ REST:                                                                        ║
║   • Requests: ${restReqs.toString().padEnd(8)} | Avg: ${restAvg.toFixed(2).padStart(7)}ms | P95: ${restP95.toFixed(2).padStart(7)}ms | Errors: ${restErrorRate.toFixed(2).padStart(5)}%   ║
║                                                                              ║
║ gRPC Unary:                                                                  ║
║   • Requests: ${grpcUnaryReqs.toString().padEnd(8)} | Avg: ${grpcUnaryAvg.toFixed(2).padStart(7)}ms | P95: ${grpcUnaryP95.toFixed(2).padStart(7)}ms | Errors: ${grpcUnaryErrorRate.toFixed(2).padStart(5)}%   ║
║                                                                              ║
║ gRPC Streaming:                                                              ║
║   • Requests: ${grpcStreamingReqs.toString().padEnd(8)} | Avg: ${grpcStreamingAvg.toFixed(2).padStart(7)}ms | P95: ${grpcStreamingP95.toFixed(2).padStart(7)}ms | Errors: ${grpcStreamingErrorRate.toFixed(2).padStart(5)}%   ║
║                                                                              ║
║ PERFORMANCE RANKING (by avg response time):                                 ║
║   1. ${grpcStreamingAvg <= restAvg && grpcStreamingAvg <= grpcUnaryAvg ? 'gRPC Streaming' : grpcUnaryAvg <= restAvg ? 'gRPC Unary' : 'REST'} - ${Math.min(grpcStreamingAvg, grpcUnaryAvg, restAvg).toFixed(2)}ms                                                ║
║   2. ${grpcStreamingAvg <= restAvg && grpcStreamingAvg <= grpcUnaryAvg ? 
        (grpcUnaryAvg <= restAvg ? 'gRPC Unary' : 'REST') : 
        grpcUnaryAvg <= restAvg ? 
          (grpcStreamingAvg <= restAvg ? 'gRPC Streaming' : 'REST') : 
          (grpcStreamingAvg <= grpcUnaryAvg ? 'gRPC Streaming' : 'gRPC Unary')} - ${[grpcStreamingAvg, grpcUnaryAvg, restAvg].sort((a,b) => a-b)[1].toFixed(2)}ms                                                ║
║   3. ${grpcStreamingAvg >= restAvg && grpcStreamingAvg >= grpcUnaryAvg ? 'gRPC Streaming' : grpcUnaryAvg >= restAvg ? 'gRPC Unary' : 'REST'} - ${Math.max(grpcStreamingAvg, grpcUnaryAvg, restAvg).toFixed(2)}ms                                                ║
║                                                                              ║
║ Total Requests: ${(restReqs + grpcUnaryReqs + grpcStreamingReqs).toString().padEnd(10)} | Duration: ${(data.state.testRunDurationMs / 1000 / 60).toFixed(1)} minutes                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
`;

  console.log(summary);
  
  return {
    'stdout': summary,
    'gcp-load-test-results.json': JSON.stringify(data, null, 2),
  };
} 