import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
export const grpc_duration = new Trend('grpc_duration');
export const grpc_failed = new Rate('grpc_failed');

export let options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 80, // 80 requests per second
      timeUnit: '1s',
      duration: '120s', // Run for 2 minutes
      preAllocatedVUs: 20,
      maxVUs: 80,
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
  client.connect('rest-grpc-service.default.svc.cluster.local:6565', { 
    plaintext: true,
    timeout: '10s'
  });

  const startTime = Date.now();
  const testId = `grpc-80tps-${__VU}-${__ITER}-${startTime}`;
  
  const payload = {
    id: testId,
    content: `gRPC 80TPS load test message ${__ITER}`,
    timestamp: new Date().toISOString(),
  };

  const start = Date.now();
  let success = false;
  let responseMessage = '';
  
  try {
    const response = client.invoke('PayloadService/SendPayload', payload);
    const duration = Date.now() - start;
    grpc_duration.add(duration);
    
    if (response && response.status === grpc.StatusOK) {
      success = true;
      responseMessage = response.message || '';
    } else {
      success = false;
      console.error('gRPC error: Unexpected response', JSON.stringify(response));
    }
    
    check(response, {
      'gRPC status is OK': (r) => r && r.status === grpc.StatusOK,
      'response time < 2000ms': () => duration < 2000,
      'has correlation ID': (r) => {
        try {
          return r && r.status === grpc.StatusOK && r.message && r.message.status === 'success' && r.message.message && r.message.message.includes('correlation ID:');
        } catch (e) {
          return false;
        }
      },
    });
    
  } catch (e) {
    const duration = Date.now() - start;
    grpc_duration.add(duration);
    console.error('gRPC error:', e && e.message ? e.message : e);
    success = false;
  } finally {
    grpc_failed.add(!success);
    client.close();
  }
  
  if (!success) {
    console.log(`gRPC request failed for ${testId}`);
  }
  
  sleep(0.01);
}

export function teardown(data) {
  console.log('gRPC 80 TPS test completed');
} 