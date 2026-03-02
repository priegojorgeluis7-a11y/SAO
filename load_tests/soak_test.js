import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';

export const options = {
  stages: [
    { duration: '5m', target: 50 },   // Ramp to 50
    { duration: '60m', target: 50 },  // Hold for 1 hour (soak)
    { duration: '5m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],    // Stricter: < 0.01% error rate
    http_req_duration: ['p(99)<2000'], // 99% < 2s
  },
};

export default function() {
  let response = http.get(
    `${BASE_URL}/activities?limit=20`,
    { headers: { 'Accept': 'application/json' } }
  );
  
  check(response, {
    'status 200': (r) => r.status === 200,
    'time < 2s': (r) => r.timings.duration < 2000,
  });
}
