// K6 Load Test Script for GCP REST Endpoints - 100 TPS
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const CLIENT_BASE_URL = 'http://34.129.37.178:9090';
const restRequests = new Counter('rest_requests_total');
const restErrorRate = new Rate('rest_error_rate');
const restResponseTime = new Trend('rest_response_time');

export const options = {
  stages: [
    { duration: '30s', target: 100 },
    { duration: '3m', target: 100 },
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
    id: `rest-100tps-${__VU}-${__ITER}`,
    content: `REST load test at 100 TPS - VU ${__VU} iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
    protocol: 'REST'
  };

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };
  const startTime = Date.now();
  const response = http.post(`${CLIENT_BASE_URL}/api/benchmark/rest`, JSON.stringify(payload), params);
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
    console.error(`REST request failed: ${response.status} - ${response.body}`);
  } else {
    restErrorRate.add(0);
  }

  sleep(1);
}

export function handleSummary(data) {
  return { 'rest-100tps-results.json': JSON.stringify(data, null, 2) };
}
