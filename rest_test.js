import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10, // number of virtual users
  duration: '30s', // test duration
};

export default function () {
  const url = 'http://localhost:8080/api/payload';
  const payload = JSON.stringify({
    id: '123',
    name: 'Alice',
    email: 'alice@example.com',
    age: 30,
    createdDate: '2025-06-16',
    updatedDate: '2025-06-16T17:00:00',
    birthDate: '1995-01-01'
  });
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  let res = http.post(url, payload, params);
  check(res, { 'status was 200': (r) => r.status === 200 || r.status === 201 });
  sleep(1);
}
