import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Custom metrics
export const helloDuration = new Trend('hello_duration');
export const helloFailures = new Rate('hello_fail_rate');
export const helloBytes = new Counter('hello_bytes');

export const options = {
  scenarios: {
    ramping_hello: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 }, // ramp up
        { duration: '1m', target: 20 },  // sustain
        { duration: '30s', target: 50 }, // spike
        { duration: '1m', target: 50 },  // sustain spike
        { duration: '30s', target: 0 },  // ramp down
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<800'],
    hello_duration: ['p(95)<400'],
    hello_fail_rate: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.HELLO_BASE_URL || 'http://localhost:30090';

export default function () {
  const res = http.get(`${BASE_URL}/api/hello`, { timeout: '5s' });
  const ok = check(res, {
    'status is 200': (r) => r.status === 200,
    'body not empty': (r) => !!r.body && r.body.length > 0,
  });
  helloDuration.add(res.timings.duration);
  helloFailures.add(!ok);
  helloBytes.add(res.body ? res.body.length : 0, { status: res.status });
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': `\nSummary:\nRequests: ${data.metrics.http_reqs.count}\nAvg Duration: ${data.metrics.http_req_duration.avg.toFixed(2)}ms\np95: ${data.metrics.http_req_duration['p(95)'].toFixed(2)}ms\nFailures: ${(data.metrics.hello_fail_rate.rate * 100).toFixed(2)}%\n`,
    'k6-summary.json': JSON.stringify(data, null, 2),
  };
}
