import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.BASE_URL || 'http://34.18.109.143';
const RATE = Number(__ENV.RATE || 10);
const DURATION = __ENV.DURATION || '10m';

export const options = {
  scenarios: {
    mixed: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: 40,
      maxVUs: 120,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.6'],
  },
};

export default function () {
  const home = http.get(`${BASE}/web/`);
  check(home, { 'home 200': (r) => r.status === 200 });

  const tid = `OH-${__VU}-${__ITER}`;
  // Keep SLOW very rare so WAITFOR does not starve the arrival-rate executor.
  const lane = (__ITER % 200 === 0) ? 'SLOW' : 'DXB-AMM';
  const checkout = http.post(`${BASE}/web/Checkout`, {
    trackingId: tid,
    lane: lane,
    weightKg: '8',
  });
  check(checkout, { 'checkout 200': (r) => r.status === 200 });

  const ok = http.get(`${BASE}/tracking/api/tracking/${tid}`);
  check(ok, { 'tracking okish': (r) => r.status === 200 || r.status === 500 });
  sleep(0.05);
}
