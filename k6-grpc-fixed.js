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

export default () => {
  client.connect('localhost:6565', { 
    plaintext: true,
    timeout: '10s'
  });
  
  const timestamp = (date) => ({
    seconds: Math.floor(date.getTime() / 1000),
    nanos: 0
  });
  
  const data = {
    id: `test-grpc-${__VU}-${__ITER}`,
    name: 'John Doe',
    email: 'john@example.com',
    age: 30,
    created_date: timestamp(new Date('2024-01-01T00:00:00Z')),
    updated_date: timestamp(new Date('2024-01-02T12:00:00Z')),
    birth_date: timestamp(new Date('1990-01-01T00:00:00Z'))
  };
  
  try {
    const response = client.invoke('PayloadService/SendPayload', data);
    check(response, { 
      'status is OK': (r) => r && r.status === grpc.StatusOK,
      'response received': (r) => r && r.message !== undefined
    });
  } catch (e) {
    console.log('gRPC request failed:', e.message);
  }
  
  client.close();
  sleep(0.1); // Reduced sleep for more intensive testing
}; 