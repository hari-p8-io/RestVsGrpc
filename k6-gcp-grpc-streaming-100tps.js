// K6 Load Test Script for GCP gRPC Streaming Endpoints - 100 TPS
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const CLIENT_BASE_URL = __ENV.CLIENT_BASE_URL || 'http://localhost:9090';
const grpcStreamingRequests = new Counter('grpc_streaming_requests_total');
const grpcStreamingErrorRate = new Rate('grpc_streaming_error_rate');
const grpcStreamingResponseTime = new Trend('grpc_streaming_response_time');

export const options = {
  stages: [
    { duration: '30s', target: 100 },
    { duration: '3m', target: 100 },
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
    id: `grpc-streaming-100tps-${__VU}-${__ITER}`,
    content: `gRPC Streaming load test at 100 TPS - VU ${__VU} iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
    protocol: 'gRPC_Streaming'
  };

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };
  const startTime = Date.now();
  const response = http.post(`${CLIENT_BASE_URL}/api/benchmark/grpc/streaming`, JSON.stringify(payload), params);
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
    console.error(`gRPC Streaming request failed: ${response.status} - ${response.body}`);
  } else {
    grpcStreamingErrorRate.add(0);
  }

  sleep(1);
}

export function handleSummary(data) {
  return { 'grpc-streaming-100tps-results.json': JSON.stringify(data, null, 2) };
}
