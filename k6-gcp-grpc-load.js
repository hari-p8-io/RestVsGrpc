// K6 Load Test Script for GCP gRPC Endpoints
// Tests gRPC Unary and Streaming protocol performance with varying loads

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Configuration - GCP External IPs
const CLIENT_BASE_URL = 'http://34.129.37.178:9090';

// Custom metrics
const grpcUnaryRequests = new Counter('grpc_unary_requests_total');
const grpcStreamingRequests = new Counter('grpc_streaming_requests_total');
const grpcUnaryErrorRate = new Rate('grpc_unary_error_rate');
const grpcStreamingErrorRate = new Rate('grpc_streaming_error_rate');
const grpcUnaryResponseTime = new Trend('grpc_unary_response_time');
const grpcStreamingResponseTime = new Trend('grpc_streaming_response_time');

// Load test configuration
export const options = {
  stages: [
    // Warm-up
    { duration: '30s', target: 10 },
    // Ramp up to moderate load
    { duration: '1m', target: 25 },
    // Steady moderate load
    { duration: '2m', target: 25 },
    // Ramp up to high load
    { duration: '1m', target: 50 },
    // Steady high load
    { duration: '3m', target: 50 },
    // Peak load
    { duration: '1m', target: 100 },
    // Sustained peak
    { duration: '2m', target: 100 },
    // Cool down
    { duration: '30s', target: 0 },
  ],
  
  thresholds: {
    'http_req_duration': ['p(95)<2000'], // 95% under 2s
    'http_req_failed': ['rate<0.05'],    // Error rate under 5%
    'grpc_unary_response_time': ['p(90)<1500'], // 90% under 1.5s
    'grpc_streaming_response_time': ['p(90)<800'], // 90% under 800ms (streaming should be faster)
    'grpc_unary_error_rate': ['rate<0.1'],      // gRPC error rate under 10%
    'grpc_streaming_error_rate': ['rate<0.1'],  // Streaming error rate under 10%
  },
};

export default function () {
  const vuId = __VU;
  const iterationId = __ITER;
  
  // Test payload
  const payload = {
    id: `gcp-grpc-${vuId}-${iterationId}`,
    content: `GCP gRPC load test message from VU ${vuId}, iteration ${iterationId}`,
    timestamp: new Date().toISOString(),
    protocol: 'gRPC'
  };

  // Headers
  const headers = {
    'Content-Type': 'application/json',
  };

  // Test gRPC Unary endpoint
  const unaryResponse = http.post(
    `${CLIENT_BASE_URL}/api/benchmark/grpc/unary`,
    JSON.stringify(payload),
    { headers }
  );

  grpcUnaryRequests.add(1);
  grpcUnaryResponseTime.add(unaryResponse.timings.duration);

  const unarySuccess = check(unaryResponse, {
    'gRPC Unary status is 200': (r) => r.status === 200,
    'gRPC Unary response time < 3000ms': (r) => r.timings.duration < 3000,
    'gRPC Unary has valid response': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data.grpcUnaryResult && data.grpcUnaryResult.success === true;
      } catch (e) {
        return false;
      }
    },
  });

  if (!unarySuccess) {
    grpcUnaryErrorRate.add(1);
    console.log(`gRPC Unary failed: ${unaryResponse.status} - ${unaryResponse.body}`);
  } else {
    grpcUnaryErrorRate.add(0);
  }

  // Test gRPC Streaming endpoint
  const streamingResponse = http.post(
    `${CLIENT_BASE_URL}/api/benchmark/grpc/streaming`,
    JSON.stringify(payload),
    { headers }
  );

  grpcStreamingRequests.add(1);
  grpcStreamingResponseTime.add(streamingResponse.timings.duration);

  const streamingSuccess = check(streamingResponse, {
    'gRPC Streaming status is 200': (r) => r.status === 200,
    'gRPC Streaming response time < 2000ms': (r) => r.timings.duration < 2000,
    'gRPC Streaming has valid response': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data.grpcStreamingResult && data.grpcStreamingResult.success === true;
      } catch (e) {
        return false;
      }
    },
  });

  if (!streamingSuccess) {
    grpcStreamingErrorRate.add(1);
    console.log(`gRPC Streaming failed: ${streamingResponse.status} - ${streamingResponse.body}`);
  } else {
    grpcStreamingErrorRate.add(0);
  }

  // Brief pause between requests
  sleep(Math.random() * 2 + 1); // 1-3 seconds
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString();
  return {
    'stdout': `
🚀 GCP gRPC Load Test Results - ${timestamp}
=================================================
Duration: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms avg
Success Rate: ${((1 - data.metrics.http_req_failed.values.rate) * 100).toFixed(2)}%
Requests: ${data.metrics.http_reqs.values.count}
VUs: ${data.metrics.vus_max.values.max}

Performance Metrics:
- Average Response Time: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms
- 95th Percentile: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
- Max Response Time: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms

gRPC Unary:
- Unary Requests: ${data.metrics.grpc_unary_requests_total.values.count}
- Unary Error Rate: ${(data.metrics.grpc_unary_error_rate.values.rate * 100).toFixed(2)}%
- Unary Avg Response: ${data.metrics.grpc_unary_response_time.values.avg.toFixed(2)}ms

gRPC Streaming:
- Streaming Requests: ${data.metrics.grpc_streaming_requests_total.values.count}
- Streaming Error Rate: ${(data.metrics.grpc_streaming_error_rate.values.rate * 100).toFixed(2)}%
- Streaming Avg Response: ${data.metrics.grpc_streaming_response_time.values.avg.toFixed(2)}ms

🎯 Test completed successfully!
`,
    'k6-gcp-grpc-results.json': JSON.stringify(data, null, 2),
  };
} 