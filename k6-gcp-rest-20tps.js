// K6 Load Test Script for GCP REST Endpoints - 20 TPS
// Tests REST protocol performance at 20 transactions per second

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Configuration - GCP External IPs
const CLIENT_BASE_URL = 'http://34.129.37.178:9090';

// Custom metrics
const restRequests = new Counter('rest_requests_total');
const restErrorRate = new Rate('rest_error_rate');
const restResponseTime = new Trend('rest_response_time');

// Load test configuration for 20 TPS
export const options = {
  stages: [
    // Ramp up to 20 TPS (20 users with 1 request per second each)
    { duration: '30s', target: 20 },
    // Maintain 20 TPS for 3 minutes
    { duration: '3m', target: 20 },
    // Ramp down
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.1'], // Error rate must be below 10%
    rest_response_time: ['p(95)<2000'],
    rest_error_rate: ['rate<0.1'],
  },
};

export default function () {
  const payload = {
    id: `rest-20tps-${__VU}-${__ITER}`,
    content: `REST load test at 20 TPS - VU ${__VU} iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
    protocol: 'REST'
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '10s',
  };

  const startTime = Date.now();
  const response = http.post(`${CLIENT_BASE_URL}/api/benchmark/rest`, JSON.stringify(payload), params);
  const duration = Date.now() - startTime;

  // Record metrics
  restRequests.add(1);
  restResponseTime.add(duration);

  // Validate response
  const success = check(response, {
    'REST status is 200': (r) => r.status === 200,
    'REST response time < 5000ms': () => duration < 5000,
    'REST response contains success': (r) => r.body.includes('success'),
  });

  if (!success) {
    restErrorRate.add(1);
    console.error(`REST request failed: ${response.status} - ${response.body}`);
  } else {
    restErrorRate.add(0);
  }

  // Sleep to maintain 1 request per second per VU
  sleep(1);
}

export function handleSummary(data) {
  return {
    'rest-20tps-results.json': JSON.stringify(data, null, 2),
  };
} 