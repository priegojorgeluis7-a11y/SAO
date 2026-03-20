import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';
const TEST_EMAIL = __ENV.SAO_LOADTEST_EMAIL || 'testuser@test.com';
const TEST_PASSWORD = __ENV.SAO_LOADTEST_PASSWORD || '';
let accessToken = '';

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp to 100 users
    { duration: '5m', target: 500 },   // Ramp to 500 users
    { duration: '5m', target: 1000 },  // Ramp to 1000 users
    { duration: '3m', target: 2000 },  // Ramp to 2000 users (stress)
    { duration: '5m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],  // 95% < 500ms, 99% < 1s
    http_req_failed: ['rate<0.1'],                    // Error rate < 0.1%
  },
};

export function setup() {
  if (!TEST_PASSWORD) {
    throw new Error('Missing SAO_LOADTEST_PASSWORD environment variable for load tests');
  }

  // Login once per test
  let response = http.post(`${BASE_URL}/auth/login`, {
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
  });
  
  if (response.status !== 200) {
    console.log(`❌ Setup login failed: ${response.status}`);
    return {};
  }

  accessToken = response.json('access_token');
  console.log(`✅ Setup complete, token obtained`);
  
  return { token: accessToken };
}

export default function(data) {
  const token = data.token || '';
  const headers = { 'Authorization': `Bearer ${token}` };
  
  // 1. Get activities
  let res1 = http.get(
    `${BASE_URL}/activities?page=1&limit=20`,
    { headers }
  );
  
  check(res1, {
    'activities: status 200': (r) => r.status === 200,
    'activities: time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
  
  // 2. Search activities
  let res2 = http.get(
    `${BASE_URL}/activities?search=test&limit=20`,
    { headers }
  );
  
  check(res2, {
    'search: status 200': (r) => r.status === 200,
    'search: time < 1s': (r) => r.timings.duration < 1000,
  });
  
  sleep(1);
  
  // 3. Sync operation
  let res3 = http.get(
    `${BASE_URL}/sync/pull?limit=50&since=2024-01-01`,
    { headers }
  );
  
  check(res3, {
    'sync: status 200': (r) => r.status === 200,
  });
  
  sleep(2);
}
