import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '1m', target: 10 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<800'],
  },
};

const API = 'https://stockgo-px32.onrender.com';

export default function () {
  const r = http.get(`${API}/health`);
  check(r, { 'health 200': (x) => x.status === 200 });
  if (__ITER % 10 === 0) {
    const b = http.get(`${API}/auth/has-users`);
    check(b, { 'has-users 200': (x) => x.status === 200 });
  }
  sleep(1);
}
