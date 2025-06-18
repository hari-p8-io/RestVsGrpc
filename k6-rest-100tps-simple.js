import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 200, // 200 requests per second
      timeUnit: '1s',
      duration: '300s', // Run for 5 minutes
      preAllocatedVUs: 40, // Start with 40 VUs
      maxVUs: 200, // Allow up to 200 VUs if needed
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.05'], // Error rate must be below 5%
  },
};

export default function () {
  const startTime = Date.now();
  const testId = `rest-80tps-${__VU}-${__ITER}`;

  const url = 'http://rest-grpc-service:8080/camel/api/payload';
  const payload = JSON.stringify({
    id: testId,
    name: 'Test User',
    email: 'test@loadtest.com',
    age: 30,
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  let res = http.post(url, payload, params);

  check(res, {
    'status was 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  sleep(0.01);
}

export function teardown(data) {
  console.log('REST 80 TPS simple test completed');
} 