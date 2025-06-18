import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10,
  duration: '20s',
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1s
    http_req_failed: ['rate<0.1'], // Error rate must be below 10%
  },
};

export default function () {
  const url = 'http://localhost:8081/camel/api/payload';
  const payload = JSON.stringify({
    id: `test-${__VU}-${__ITER}`,
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
  });
  
  // Add small delay between requests
  sleep(0.1);
} 