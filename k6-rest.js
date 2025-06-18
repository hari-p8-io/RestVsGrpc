import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10,
  duration: '30s',
};

export default function () {
  const url = 'http://localhost:8080/api/payload';
  const payload = JSON.stringify({
    id: 'test-id',
    name: 'John Doe',
    email: 'john@example.com',
    age: 30,
    createdDate: '2024-01-01T00:00:00Z',
    updatedDate: '2024-01-02T12:00:00Z',
    birthDate: '1990-01-01T00:00:00Z'
  });
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  let res = http.post(url, payload, params);
  check(res, { 'status was 200': (r) => r.status === 200 });
  sleep(1);
}
