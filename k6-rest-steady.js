import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  scenarios: {
    steady_load: {
      executor: 'constant-arrival-rate',
      rate: 20, // 20 requests per second
      timeUnit: '1s',
      duration: '60s', // Run for 60 seconds
      preAllocatedVUs: 5, // Start with 5 VUs
      maxVUs: 50, // Allow up to 50 VUs if needed
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1s
    http_req_failed: ['rate<0.1'], // Error rate must be below 10%
  },
};

export default function () {
  const url = 'http://rest-grpc-service:8080/camel/api/payload';
  const payload = JSON.stringify({
    id: `rest-steady-${__VU}-${__ITER}`,
    name: 'John Doe',
    email: 'john@example.com',
    age: 30
  });
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  let res = http.post(url, payload, params);
  check(res, { 
    'status was 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
  });
} 