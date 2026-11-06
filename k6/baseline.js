import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.BASE_URL || 'http://34.18.109.143';

export const options = {
  scenarios: {
    mixed: {
      executor: 'constant-arrival-rate',
      rate: 4,
      timeUnit: '1s',
      duration: '3m',
      preAllocatedVUs: 8,
      maxVUs: 20,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.5'],
  },
};

export default function () {
  const home = http.get(`${BASE}/web/`);
  check(home, { 'home 200': (r) => r.status === 200 });

  const tid = `K6-${__VU}-${__ITER}`;
  const lane = (__ITER % 7 === 0) ? 'SLOW' : 'DXB-AMM';
  const checkout = http.post(`${BASE}/web/Checkout`, {
    trackingId: tid,
    lane: lane,
    weightKg: '8',
  });
  check(checkout, { 'checkout 200': (r) => r.status === 200 });

  const ok = http.get(`${BASE}/tracking/api/tracking/${tid}`);
  check(ok, { 'tracking okish': (r) => r.status === 200 || r.status === 500 });

  if (__ITER % 11 === 0) {
    const missing = http.get(`${BASE}/tracking/api/tracking/missing`);
    check(missing, { 'missing 404': (r) => r.status === 404 });
  }
  if (__ITER % 19 === 0) {
    http.get(`${BASE}/tracking/api/tracking/boom`);
  }
  sleep(0.2);
}
