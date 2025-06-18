// K6 Load Test Script for GCP gRPC Unary Endpoints - 60 TPS
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const CLIENT_BASE_URL = __ENV.CLIENT_BASE_URL || 'http://localhost:9090';
const grpcUnaryRequests = new Counter('grpc_unary_requests_total');
const grpcUnaryErrorRate = new Rate('grpc_unary_error_rate');
const grpcUnaryResponseTime = new Trend('grpc_unary_response_time');

export const options = {
  stages: [
    { duration: '30s', target: 60 },
    { duration: '3m', target: 60 },
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
    id: `grpc-unary-60tps-${__VU}-${__ITER}`,
    content: `gRPC Unary load test at 60 TPS - VU ${__VU} iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
    protocol: 'gRPC_Unary'
  };

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };
  const startTime = Date.now();
  const response = http.post(`${CLIENT_BASE_URL}/api/benchmark/grpc/unary`, JSON.stringify(payload), params);
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
    console.error(`gRPC Unary request failed: ${response.status} - ${response.body}`);
  } else {
    grpcUnaryErrorRate.add(0);
  }

  sleep(1);
}

export function handleSummary(data) {
  return { 'grpc-unary-60tps-results.json': JSON.stringify(data, null, 2) };
}
