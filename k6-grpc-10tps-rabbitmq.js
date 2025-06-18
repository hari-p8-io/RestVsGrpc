import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const endToEndLatency = new Trend('end_to_end_latency');
const messageDeliveryRate = new Rate('message_delivery_rate');
const correlationCounter = new Counter('correlation_requests');

const RABBITMQ_MGMT_URL = 'http://rabbitmq-management:15672';
const RABBITMQ_USER = 'guest';
const RABBITMQ_PASS = 'guest';
const GRPC_QUEUE = 'grpc-payload-queue';

const client = new grpc.Client();
client.load(['.'], 'payload.proto');

export let options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 10, // 10 requests per second
      timeUnit: '1s',
      duration: '60s', // Run for 1 minute
      preAllocatedVUs: 2,
      maxVUs: 20,
    },
  },
  thresholds: {
    grpc_req_duration: ['p(95)<2000'],
    checks: ['rate>0.95'],
    end_to_end_latency: ['p(95)<5000'],
    message_delivery_rate: ['rate>0.95'],
  },
};

const correlationTracker = new Map();

export function setup() {
  return {};
}

export default () => {
  const startTime = Date.now();
  const testId = `grpc-10tps-${__VU}-${__ITER}`;
  
  if (!client.isConnected) {
    client.connect('rest-grpc-service:6565', { 
      plaintext: true,
      timeout: '30s'
    });
  }
  
  const data = {
    id: testId,
    name: 'Load Test User',
    email: `user-${__VU}-${__ITER}@loadtest.com`,
    age: 25 + (__VU % 50)
  };
  
  const response = client.invoke('PayloadService/SendPayload', data);
  
  const requestSuccess = check(response, {
    'status is OK': (r) => r && r.status === grpc.StatusOK,
    'has valid response': (r) => r && r.message,
    'response time < 2000ms': (r) => r && r.timings && r.timings.duration < 2000,
    'has correlation ID': (r) => {
      try {
        return r && r.message && r.message.message && r.message.message.includes('correlation:');
      } catch (e) {
        return false;
      }
    }
  });
  
  if (requestSuccess && response.status === grpc.StatusOK) {
    try {
      const responseMessage = response.message.message;
      const correlationMatch = responseMessage.match(/correlation:\s*([a-f0-9-]+)/);
      
      if (correlationMatch && correlationMatch[1]) {
        const correlationId = correlationMatch[1];
        correlationCounter.add(1);
        correlationTracker.set(correlationId, {
          startTime: startTime,
          requestTime: Date.now(),
          testId: testId
        });
      }
    } catch (e) {
      // Ignore
    }
  }
};

export function teardown(data) {
  client.close();
  console.log('gRPC 10 TPS test completed');
  console.log(`Tracked ${correlationTracker.size} correlation IDs`);
} 