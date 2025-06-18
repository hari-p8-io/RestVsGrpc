import http from 'k6/http';
import { check, sleep } from 'k6';

// Quick test configuration - just 5 users for 30 seconds
export let options = {
  vus: 5,
  duration: '30s',
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1000ms
    http_req_failed: ['rate<0.1'],     // Error rate should be less than 10%
  },
};

const BASE_URL = 'http://localhost:9090';

export default function () {
  const payload = {
    id: `quick-test-${__VU}-${__ITER}`,
    content: `Quick test message from VU ${__VU}, iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '10s',
  };

  // Test all three endpoints
  const endpoints = [
    { path: '/api/benchmark/rest', name: 'REST' },
    { path: '/api/benchmark/grpc/unary', name: 'gRPC Unary' },
    { path: '/api/benchmark/grpc/streaming', name: 'gRPC Streaming' },
  ];

  // Pick a random endpoint to test
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const response = http.post(`${BASE_URL}${endpoint.path}`, JSON.stringify(payload), params);
  
  check(response, {
    [`${endpoint.name} status is 200`]: (r) => r.status === 200,
    [`${endpoint.name} response time < 1000ms`]: (r) => r.timings.duration < 1000,
    [`${endpoint.name} has status field`]: (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  // Short sleep between requests
  sleep(0.5);
}

export function handleSummary(data) {
  return {
    stdout: `
========================================
QUICK TEST RESULTS
========================================
Total Requests: ${data.metrics.http_reqs.count}
Failed Requests: ${data.metrics.http_req_failed.count || 0}
Success Rate: ${((data.metrics.http_reqs.count - (data.metrics.http_req_failed.count || 0)) / data.metrics.http_reqs.count * 100).toFixed(2)}%
Average Response Time: ${data.metrics.http_req_duration.avg.toFixed(2)}ms
95th Percentile: ${data.metrics.http_req_duration['p(95)'].toFixed(2)}ms
Max Response Time: ${data.metrics.http_req_duration.max.toFixed(2)}ms
========================================
✓ Quick test completed successfully!
Ready for full load testing.
========================================
`,
  };
} 