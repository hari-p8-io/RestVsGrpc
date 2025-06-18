import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 200,
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 10,
      maxVUs: 50,
    },
  },
};

export default function () {
  const payload = {
    id: `test-${__VU}-${__ITER}`,
    content: `Test message ${__ITER}`,
    timestamp: new Date().toISOString(),
    protocol: 'REST'
  };

  const response = http.post('http://34.126.192.30:8080/api/payload', JSON.stringify(payload), {
    headers: {
      'Content-Type': 'application/json',
    },
  });

  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
  });
} 