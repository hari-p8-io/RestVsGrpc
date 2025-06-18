// K6 Load Test Script for GCP REST Endpoints
// Tests REST protocol performance with varying loads

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Configuration - GCP External IPs
const CLIENT_BASE_URL = 'http://34.129.37.178:9090';
const MAIN_SERVICE_URL = 'http://34.126.192.30:8080';

// Custom metrics
const restRequests = new Counter('rest_requests_total');
const restErrorRate = new Rate('rest_error_rate');
const restResponseTime = new Trend('rest_response_time');

// Load test configuration
export const options = {
  stages: [
    // Warm-up
    { duration: '30s', target: 10 },
    // Ramp up to moderate load
    { duration: '1m', target: 25 },
    // Steady moderate load
    { duration: '2m', target: 25 },
    // Ramp up to high load
    { duration: '1m', target: 50 },
    // Steady high load
    { duration: '3m', target: 50 },
    // Peak load
    { duration: '1m', target: 100 },
    // Sustained peak
    { duration: '2m', target: 100 },
    // Cool down
    { duration: '30s', target: 0 },
  ],
  
  thresholds: {
    'http_req_duration': ['p(95)<2000'], // 95% under 2s
    'http_req_failed': ['rate<0.05'],    // Error rate under 5%
    'rest_response_time': ['p(90)<1500'], // 90% under 1.5s
    'rest_error_rate': ['rate<0.1'],      // REST error rate under 10%
  },
};

export default function () {
  const vuId = __VU;
  const iterationId = __ITER;
  
  // Test payload
  const payload = {
    id: `gcp-rest-${vuId}-${iterationId}`,
    content: `GCP REST load test message from VU ${vuId}, iteration ${iterationId}`,
    timestamp: new Date().toISOString(),
    protocol: 'REST'
  };

  // Headers
  const headers = {
    'Content-Type': 'application/json',
  };

  // Test direct REST endpoint
  const directResponse = http.post(
    `${MAIN_SERVICE_URL}/camel/api/payload`,
    JSON.stringify(payload),
    { headers }
  );

  restRequests.add(1);
  restResponseTime.add(directResponse.timings.duration);

  const directSuccess = check(directResponse, {
    'Direct REST status is 200': (r) => r.status === 200,
    'Direct REST response time < 3000ms': (r) => r.timings.duration < 3000,
    'Direct REST has response': (r) => r.body && r.body.length > 0,
  });

  if (!directSuccess) {
    restErrorRate.add(1);
    console.log(`Direct REST failed: ${directResponse.status} - ${directResponse.body}`);
  } else {
    restErrorRate.add(0);
  }

  // Test client service REST endpoint
  const clientResponse = http.post(
    `${CLIENT_BASE_URL}/api/benchmark/rest`,
    JSON.stringify(payload),
    { headers }
  );

  const clientSuccess = check(clientResponse, {
    'Client REST status is 200': (r) => r.status === 200,
    'Client REST response time < 5000ms': (r) => r.timings.duration < 5000,
    'Client REST has valid response': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data.restResult && data.restResult.success === true;
      } catch (e) {
        return false;
      }
    },
  });

  if (!clientSuccess) {
    console.log(`Client REST failed: ${clientResponse.status} - ${clientResponse.body}`);
  }

  // Brief pause between requests
  sleep(Math.random() * 2 + 1); // 1-3 seconds
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString();
  return {
    'stdout': `
🚀 GCP REST Load Test Results - ${timestamp}
=================================================
Duration: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms avg
Success Rate: ${((1 - data.metrics.http_req_failed.values.rate) * 100).toFixed(2)}%
Requests: ${data.metrics.http_reqs.values.count}
VUs: ${data.metrics.vus_max.values.max}

Performance Metrics:
- Average Response Time: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms
- 95th Percentile: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
- Max Response Time: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms

REST Specific:
- REST Requests: ${data.metrics.rest_requests_total.values.count}
- REST Error Rate: ${(data.metrics.rest_error_rate.values.rate * 100).toFixed(2)}%
- REST Avg Response: ${data.metrics.rest_response_time.values.avg.toFixed(2)}ms

🎯 Test completed successfully!
`,
    'k6-gcp-rest-results.json': JSON.stringify(data, null, 2),
  };
} 