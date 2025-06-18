import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
export let errorCount = new Counter('errors');
export let errorRate = new Rate('error_rate');
export let responseTime = new Trend('response_time');

// Test configuration
export let options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users over 30s
    { duration: '1m', target: 50 },    // Stay at 50 users for 1 minute
    { duration: '30s', target: 100 },  // Ramp up to 100 users over 30s
    { duration: '2m', target: 100 },   // Stay at 100 users for 2 minutes
    { duration: '30s', target: 0 },    // Ramp down to 0 users over 30s
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    error_rate: ['rate<0.1'],         // Error rate should be less than 10%
  },
};

// Test data
const BASE_URL = 'http://localhost:9090';
const ENDPOINT = '/api/benchmark/grpc/streaming';

export default function () {
  const payload = {
    id: `grpc-streaming-test-${__VU}-${__ITER}`,
    content: `gRPC streaming load test message from VU ${__VU}, iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '30s',
  };

  const startTime = Date.now();
  const response = http.post(`${BASE_URL}${ENDPOINT}`, JSON.stringify(payload), params);
  const endTime = Date.now();
  
  // Record custom metrics
  responseTime.add(endTime - startTime);
  
  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
    'response has status field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status !== undefined;
      } catch (e) {
        return false;
      }
    },
    'response status is success': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status === 'success';
      } catch (e) {
        return false;
      }
    },
  });

  if (!success) {
    errorCount.add(1);
    errorRate.add(1);
    console.log(`Error response: ${response.status} - ${response.body}`);
  } else {
    errorRate.add(0);
  }

  // Think time between requests (0.1 to 1 second)
  sleep(Math.random() * 0.9 + 0.1);
}

export function handleSummary(data) {
  return {
    'grpc-streaming-load-test-results.json': JSON.stringify(data, null, 2),
    stdout: `
========================================
gRPC STREAMING CLIENT LOAD TEST RESULTS
========================================
Total Requests: ${data.metrics.http_reqs.count}
Failed Requests: ${data.metrics.errors.count || 0}
Error Rate: ${((data.metrics.errors.count || 0) / data.metrics.http_reqs.count * 100).toFixed(2)}%
Average Response Time: ${data.metrics.http_req_duration.avg.toFixed(2)}ms
95th Percentile: ${data.metrics.http_req_duration['p(95)'].toFixed(2)}ms
Max Response Time: ${data.metrics.http_req_duration.max.toFixed(2)}ms
Requests/sec: ${data.metrics.http_req_rate.rate.toFixed(2)}
========================================
`,
  };
} 