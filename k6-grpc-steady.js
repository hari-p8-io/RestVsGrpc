import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const client = new grpc.Client();
client.load(['.'], 'payload.proto');

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
    grpc_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1s
    checks: ['rate>0.9'], // 90% of checks must pass
  },
};

export function setup() {
  // Global setup - client connections will be reused
  return {};
}

export default () => {
  // Connect once per VU, not per request
  if (!client.isConnected) {
    client.connect('rest-grpc-service:6565', { 
      plaintext: true,
      timeout: '30s'
    });
  }
  
  // Simple payload without timestamp fields
  const data = {
    id: `grpc-steady-${__VU}-${__ITER}`,
    name: 'John Doe',
    email: 'john@example.com',
    age: 30
  };
  
  const response = client.invoke('PayloadService/SendPayload', data);
  
  check(response, {
    'status is OK': (r) => r && r.status === grpc.StatusOK,
    'has valid response': (r) => r && r.message,
  });
};

export function teardown(data) {
  client.close();
} 