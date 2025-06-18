import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const client = new grpc.Client();
client.load(['.'], 'payload.proto');

export let options = {
  stages: [
    { duration: '10s', target: 2 },   // Warm-up: ramp to 2 users over 10s
    { duration: '15s', target: 5 },   // Load increase: ramp to 5 users over 15s
    { duration: '15s', target: 12 },  // Peak load: ramp to 12 users over 15s
    { duration: '10s', target: 12 },  // Sustain peak: hold 12 users for 10s
    { duration: '10s', target: 0 },   // Scale down: ramp down to 0 over 10s
  ],
  thresholds: {
    grpc_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1s
    checks: ['rate>0.9'],              // 90% of checks must pass
  },
};

export function setup() {
  // Global setup
  return {};
}

export default () => {
  // Connect once per VU, reuse connection
  if (!client.isConnected) {
    client.connect('rest-grpc-service:6565', { 
      plaintext: true,
      timeout: '30s'
    });
  }
  
  const data = {
    id: `test-grpc-${__VU}-${__ITER}`,
    name: 'John Doe',
    email: 'john@example.com',
    age: 30
  };
  
  const response = client.invoke('PayloadService/SendPayload', data);
  
  check(response, {
    'status is OK': (r) => r && r.status === grpc.StatusOK,
    'response time < 500ms': (r) => client.lastRequestTime < 500,
  });
  
  // Small dynamic sleep based on current load
  const currentVUs = __ENV.K6_VUS || 1;
  const sleepTime = Math.max(0.01, 0.1 - (currentVUs * 0.001)); // Less sleep with more VUs
  sleep(sleepTime);
};

export function teardown(data) {
  client.close();
} 