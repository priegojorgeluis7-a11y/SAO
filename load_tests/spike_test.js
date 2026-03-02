import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';

export const options = {
  stages: [
    { duration: '2m', target: 10 },     // Baseline: 10 users
    { duration: '30s', target: 500 },   // Spike to 500
    { duration: '30s', target: 1000 },  // Spike to 1000
    { duration: '3m', target: 1000 },   // Hold spike
    { duration: '1m', target: 10 },     // Return to baseline
    { duration: '1m', target: 0 },      // Ramp down
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],
    http_req_duration: ['p(95)<1000'],
  },
};

export default function() {
  let response = http.get(
    `${BASE_URL}/activities?limit=50`,
    { headers: { 'Accept': 'application/json' } }
  );
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time under 1s': (r) => r.timings.duration < 1000,
  });
}
