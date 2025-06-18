import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
export const rest_duration = new Trend('rest_duration');
export const rest_failed = new Rate('rest_failed');

export let options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 20, // 20 requests per second
      timeUnit: '1s',
      duration: '120s', // Run for 2 minutes
      preAllocatedVUs: 5, // Start with 5 VUs
      maxVUs: 20, // Allow up to 20 VUs if needed
    },
  },
  thresholds: {
    rest_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    rest_failed: ['rate<0.05'], // Error rate must be below 5%
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.05'],
  },
};

export default function () {
  const startTime = Date.now();
  const testId = `rest-20tps-${__VU}-${__ITER}-${startTime}`;

  const url = 'http://rest-grpc-service.default.svc.cluster.local:8080/camel/api/payload';
  const payload = JSON.stringify({
    id: testId,
    content: `REST load test message ${__ITER}`,
    timestamp: new Date().toISOString(),
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  const start = Date.now();
  let res = http.post(url, payload, params);
  const duration = Date.now() - start;
  
  rest_duration.add(duration);
  
  const success = check(res, {
    'status was 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
    'has correlation ID': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body && body.correlationId && body.correlationId.length > 0;
      } catch (e) {
        return false;
      }
    },
  });

  rest_failed.add(!success);
  
  if (!success) {
    console.log(`REST request failed: Status ${res.status}, Body: ${res.body}`);
  }

  sleep(0.01);
}

export function teardown(data) {
  console.log('REST 20 TPS test completed');
} 