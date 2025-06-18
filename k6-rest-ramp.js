import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '10s', target: 2 },   // Warm-up: ramp to 2 users over 10s
    { duration: '15s', target: 5 },   // Load increase: ramp to 5 users over 15s
    { duration: '15s', target: 12 },  // Peak load: ramp to 12 users over 15s
    { duration: '10s', target: 12 },  // Sustain peak: hold 12 users for 10s
    { duration: '10s', target: 0 },   // Scale down: ramp down to 0 over 10s
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1s
    http_req_failed: ['rate<0.1'],     // Error rate must be below 10%
    checks: ['rate>0.9'],              // 90% of checks must pass
  },
};

export default () => {
  const payload = {
    id: `test-rest-${__VU}-${__ITER}`,
    name: 'John Doe',
    email: 'john@example.com',
    age: 30
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '30s',
  };

  const response = http.post('http://rest-grpc-service:8080/api/payload', JSON.stringify(payload), params);
  
  check(response, {
    'status was 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  // Small dynamic sleep based on current load
  const currentVUs = __ENV.K6_VUS || 1;
  const sleepTime = Math.max(0.01, 0.1 - (currentVUs * 0.001)); // Less sleep with more VUs
  sleep(sleepTime);
}; 