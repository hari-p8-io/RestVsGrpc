import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const client = new grpc.Client();
client.load(['src/main/proto'], 'payload.proto');

export let options = {
  vus: 10,
  duration: '30s',
};

export default () => {
  client.connect('localhost:6565', { plaintext: true });
  const now = new Date();
  const timestamp = (date) => ({
    seconds: Math.floor(date.getTime() / 1000),
    nanos: 0
  });
  const data = {
    id: 'test-id',
    name: 'John Doe',
    email: 'john@example.com',
    age: 30,
    created_date: timestamp(new Date('2024-01-01T00:00:00Z')),
    updated_date: timestamp(new Date('2024-01-02T12:00:00Z')),
    birth_date: timestamp(new Date('1990-01-01T00:00:00Z'))
  };
  const response = client.invoke('PayloadService/SendPayload', data);
  check(response, { 'status is OK': (r) => r && r.status === grpc.StatusOK });
  client.close();
  sleep(1);
};
