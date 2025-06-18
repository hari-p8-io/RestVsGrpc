import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { Counter, Rate, Trend } from 'k6/metrics';
import { encodeBase64 } from 'k6/encoding';

// Custom metrics for end-to-end timing
const endToEndLatency = new Trend('end_to_end_latency');
const messageDeliveryRate = new Rate('message_delivery_rate');
const correlationCounter = new Counter('correlation_requests');

// RabbitMQ Management API configuration
const RABBITMQ_MGMT_URL = 'http://rabbitmq-service:15672';
const RABBITMQ_USER = 'guest';
const RABBITMQ_PASS = 'guest';
const REST_QUEUE = 'rest-payload-queue';

export let options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 100, // 100 requests per second
      timeUnit: '1s',
      duration: '120s', // Run for 2 minutes
      preAllocatedVUs: 20, // Start with 20 VUs
      maxVUs: 100, // Allow up to 100 VUs if needed
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.05'], // Error rate must be below 5%
    end_to_end_latency: ['p(95)<5000'], // End-to-end latency under 5s
    message_delivery_rate: ['rate>0.95'], // 95% message delivery success
  },
};

// Track correlation IDs and their timestamps
const correlationTracker = new Map();

export default function () {
  const startTime = Date.now();
  const testId = `rest-100tps-${__VU}-${__ITER}`;
  
  const url = 'http://rest-grpc-service:8080/camel/api/payload';
  const payload = JSON.stringify({
    id: testId,
    name: 'Load Test User',
    email: `user-${__VU}-${__ITER}@loadtest.com`,
    age: 25 + (__VU % 50)
  });
  
  const params = {
    headers: { 
      'Content-Type': 'application/json',
      'X-Request-Start': startTime.toString()
    },
  };
  
  // Send request to REST endpoint
  let res = http.post(url, payload, params);
  console.log('Response body:', res.body);
  
  const requestSuccess = check(res, { 
    'status was 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
    'has correlation ID': (r) => {
      try {
        let body = JSON.parse(r.body);
        if (typeof body === 'string') {
          body = JSON.parse(body);
        }
        return body.correlationId && body.correlationId.length > 0;
      } catch (e) {
        return false;
      }
    }
  });
  
  if (requestSuccess && res.status === 200) {
    try {
      let responseBody = JSON.parse(res.body);
      if (typeof responseBody === 'string') {
        responseBody = JSON.parse(responseBody);
      }
      const correlationId = responseBody.correlationId;
      
      if (correlationId) {
        correlationCounter.add(1);
        correlationTracker.set(correlationId, {
          startTime: startTime,
          requestTime: Date.now(),
          testId: testId
        });
        
        // Synchronous delay before checking the queue
        sleep(1); // 1s
        checkMessageInQueue(correlationId, startTime);
      }
    } catch (e) {
      console.error('Failed to parse response:', e);
    }
  }
}

function checkMessageInQueue(correlationId, startTime) {
  try {
    // Get messages from RabbitMQ queue
    const queueUrl = `${RABBITMQ_MGMT_URL}/api/queues/%2F/${REST_QUEUE}/get`;
    const auth = `${RABBITMQ_USER}:${RABBITMQ_PASS}`;
    const encodedAuth = encodeBase64(auth);
    
    const queueParams = {
      headers: {
        'Authorization': `Basic ${encodedAuth}`,
        'Content-Type': 'application/json'
      }
    };
    
    const queuePayload = JSON.stringify({
      count: 10,
      ackmode: 'ack_requeue_true',
      encoding: 'auto'
    });
    
    const queueRes = http.post(queueUrl, queuePayload, queueParams);
    
    if (queueRes.status === 200) {
      console.log('RabbitMQ API response:', queueRes.body);
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
    } else {
      console.error('RabbitMQ API error:', queueRes.status, queueRes.body);
    }
    
    // Message not found, mark as failed delivery
    messageDeliveryRate.add(0);
    
  } catch (e) {
    console.error('Error checking queue:', JSON.stringify(e));
    messageDeliveryRate.add(0);
  }
}

export function teardown(data) {
  console.log('REST 100 TPS test completed');
  console.log(`Tracked ${correlationTracker.size} correlation IDs`);
} 