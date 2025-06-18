import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import http from 'k6/http';

// Custom metrics for end-to-end timing
const endToEndLatency = new Trend('end_to_end_latency');
const messageDeliveryRate = new Rate('message_delivery_rate');
const correlationCounter = new Counter('correlation_requests');

// RabbitMQ Management API configuration
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
      rate: 100, // 100 requests per second
      timeUnit: '1s',
      duration: '120s', // Run for 2 minutes
      preAllocatedVUs: 20, // Start with 20 VUs
      maxVUs: 100, // Allow up to 100 VUs if needed
    },
  },
  thresholds: {
    grpc_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    checks: ['rate>0.95'], // 95% of checks must pass
    end_to_end_latency: ['p(95)<5000'], // End-to-end latency under 5s
    message_delivery_rate: ['rate>0.95'], // 95% message delivery success
  },
};

// Track correlation IDs and their timestamps
const correlationTracker = new Map();

export function setup() {
  return {};
}

export default () => {
  const startTime = Date.now();
  const testId = `grpc-100tps-${__VU}-${__ITER}`;
  
  // Connect once per VU, not per request
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
      // Extract correlation ID from message like "Processed with correlation: uuid"
      const correlationMatch = responseMessage.match(/correlation:\s*([a-f0-9-]+)/);
      
      if (correlationMatch && correlationMatch[1]) {
        const correlationId = correlationMatch[1];
        correlationCounter.add(1);
        correlationTracker.set(correlationId, {
          startTime: startTime,
          requestTime: Date.now(),
          testId: testId
        });
        
        // Check for message in RabbitMQ queue after a short delay
        setTimeout(() => {
          checkMessageInQueue(correlationId, startTime);
        }, 100); // 100ms delay to allow message processing
      }
    } catch (e) {
      console.error('Failed to parse gRPC response:', e);
    }
  }
};

function checkMessageInQueue(correlationId, startTime) {
  try {
    // Get messages from RabbitMQ queue
    const queueUrl = `${RABBITMQ_MGMT_URL}/api/queues/%2F/${GRPC_QUEUE}/get`;
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
    console.error('Error checking queue:', e);
    messageDeliveryRate.add(0);
  }
}

export function teardown(data) {
  client.close();
  console.log('gRPC 100 TPS test completed');
  console.log(`Tracked ${correlationTracker.size} correlation IDs`);
} 