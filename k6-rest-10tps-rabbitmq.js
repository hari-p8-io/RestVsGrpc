import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import encoding from 'encoding';

const endToEndLatency = new Trend('end_to_end_latency');
const messageDeliveryRate = new Rate('message_delivery_rate');
const correlationCounter = new Counter('correlation_requests');

const RABBITMQ_MGMT_URL = 'http://rabbitmq-management:15672';
const RABBITMQ_USER = 'guest';
const RABBITMQ_PASS = 'guest';
const REST_QUEUE = 'rest-payload-queue';

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
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.05'],
    end_to_end_latency: ['p(95)<5000'],
    message_delivery_rate: ['rate>0.95'],
  },
};

const correlationTracker = new Map();

export default function () {
  const startTime = Date.now();
  const testId = `rest-10tps-${__VU}-${__ITER}`;
  
  const url = 'http://rest-grpc-service:8080/camel/api/payload';
  const payload = JSON.stringify({
    id: testId,
    name: 'Load Test User',
    email: `user-${__VU}-${__ITER}@loadtest.com`,
    age: 25 + (__VU % 50)
  });
  
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  let res = http.post(url, payload, params);
  
  const requestSuccess = check(res, { 
    'status was 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
    'has correlation ID': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.correlationId && body.correlationId.length > 0;
      } catch (e) {
        return false;
      }
    }
  });
  
  if (requestSuccess && res.status === 200) {
    try {
      const responseBody = JSON.parse(res.body);
      const correlationId = responseBody.correlationId;
      
      if (correlationId) {
        correlationCounter.add(1);
        correlationTracker.set(correlationId, {
          startTime: startTime,
          requestTime: Date.now(),
          testId: testId
        });
        // Check for message in RabbitMQ queue after a short delay
        checkMessageInQueue(correlationId, startTime);
      }
    } catch (e) {
      // Ignore
    }
  }
}

function checkMessageInQueue(correlationId, startTime) {
  try {
    // Get messages from RabbitMQ queue
    const queueUrl = `${RABBITMQ_MGMT_URL}/api/queues/%2F/${REST_QUEUE}/get`;
    const auth = `${RABBITMQ_USER}:${RABBITMQ_PASS}`;
    const encodedAuth = encoding.b64encode(auth);
    
    const queueParams = {
      headers: {
        'Authorization': `Basic ${encodedAuth}`,
        'Content-Type': 'application/json'
      }
    };
    
    const queuePayload = JSON.stringify({
      count: 10,
      ackmode: 'ack_requeue_false',
      encoding: 'auto'
    });
    
    const queueRes = http.post(queueUrl, queuePayload, queueParams);
    
    if (queueRes.status === 200) {
      const messages = JSON.parse(queueRes.body);
      
      for (let message of messages) {
        try {
          const messageBody = JSON.parse(message.payload);
          if (messageBody.correlationId === correlationId) {
            const endTime = Date.now();
            const endToEndTime = endTime - startTime;
            
            endToEndLatency.add(endToEndTime);
            messageDeliveryRate.add(1);
            
            console.log(`End-to-end latency for ${correlationId}: ${endToEndTime}ms`);
            return;
          }
        } catch (e) {
          // Skip malformed messages
        }
      }
    }
    
    // Message not found, mark as failed delivery
    messageDeliveryRate.add(0);
    
  } catch (e) {
    messageDeliveryRate.add(0);
  }
}

export function teardown(data) {
  console.log('REST 10 TPS test completed');
  console.log(`Tracked ${correlationTracker.size} correlation IDs`);
} 