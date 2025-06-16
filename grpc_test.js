import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const client = new grpc.Client();
client.load(['./'], 'payload.proto');

export let options = {
  vus: 10,
  duration: '30s',
};

export default () => {
  client.connect('localhost:6565', { plaintext: true });
  const data = {
    id: '123',
    name: 'Alice',
    email: 'alice@example.com',
    age: 30,
    createdDate: { seconds: Math.floor(Date.now() / 1000) },
    updatedDate: { seconds: Math.floor(Date.now() / 1000) },
    birthDate: { seconds: 788918400 } // 1995-01-01T00:00:00Z
  };
  const response = client.invoke('com.benchmark.service.grpc.PayloadService/SendPayload', data);
  check(response, { 'status is OK': (r) => r && r.status === grpc.StatusOK });
  client.close();
  sleep(1);
};
