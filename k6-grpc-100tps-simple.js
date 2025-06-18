import grpc from 'k6/net/grpc';
import { check, Trend, Rate } from 'k6/metrics';
import { sleep } from 'k6';

// Custom metrics
export const grpc_duration = new Trend('grpc_duration');
export const grpc_failed = new Rate('grpc_failed');

export let options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 200, // 200 requests per second
      timeUnit: '1s',
      duration: '300s', // Run for 5 minutes
      preAllocatedVUs: 40,
      maxVUs: 200,
    },
  },
  thresholds: {
    grpc_duration: ['p(95)<2000'], // 95% of gRPC requests should be < 2s
    grpc_failed: ['rate<0.05'],    // <5% failure rate
  },
};

const client = new grpc.Client();
client.load(['.'], 'payload.proto');

export default function () {
  client.connect('rest-grpc-service:6565', { plaintext: true });

  const payload = {
    id: `grpc-80tps-${__VU}-${__ITER}`,
    name: 'Test User',
    email: 'test@loadtest.com',
    age: 30,
  };

  const start = Date.now();
  let success = false;
  try {
    const response = client.invoke('PayloadService/SendPayload', payload);
    if (response && typeof response === 'object' && Number(response.status) === 0) {
      success = true;
    } else {
      success = false;
      console.error('gRPC error: Unexpected response', JSON.stringify(response));
    }
    grpc_failed.add(!success);
  } catch (e) {
    console.error('gRPC error:', e && e.message ? e.message : e);
    grpc_failed.add(true);
  } finally {
    grpc_duration.add(Date.now() - start);
    client.close();
  }
  sleep(0.01);
}

export function teardown(data) {
  console.log('gRPC 100 TPS simple test completed');
} 