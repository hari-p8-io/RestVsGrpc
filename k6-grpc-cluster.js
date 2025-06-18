import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const client = new grpc.Client();
client.load(['.'], 'payload.proto');

export let options = {
  vus: 10,
  duration: '20s',
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
  
  // Remove sleep to maximize throughput
  // sleep(0.1); // Small delay between requests
};

export function teardown(data) {
  client.close();
} 