import http from "k6/http";
import { check, sleep, group, textSummary } from "k6";
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/latest/dist/bundle.js';

export const options = {
  scenarios: {
    warmup: {
      executor: 'constant-vus',
      vus: 3,
      duration: '10s',
      exec: 'runTest',
      tags: { stage: 'warmup' },
    },
    main_test: {
      executor: 'constant-vus',
      vus: __ENV.K6_VUS ? parseInt(__ENV.K6_VUS) : 100,
      duration: __ENV.K6_DURATION || '600s',
      startTime: '10s',
      exec: 'runTest',
      tags: { stage: 'main' },
    },
  },
  thresholds: {
    'http_req_failed{stage:main}': ['rate<0.01'],    // Ошибок менее 1%
    'http_req_duration{stage:main}': ['p(95)<1000'], // 95% запросов быстрее 1.0с
  },
};

export default function () {
  const baseUrl  = __ENV.BASE_URL ? `https://${__ENV.BASE_URL}` : 'https://sausage-store.vigilia.site';
  const runLabel = __ENV.TEST_RUN || 'default';

  group('Main Page', function () {
    const resIndex = http.get(baseUrl, {
      tags: { type: 'main', test_run: runLabel }
    });
    check(resIndex, {
      'index status is 200': (r) => r.status === 200,
      'body contains sausage': (r) => r.body.includes('Сосисочная у дома'),
    });
  });

  sleep(0.1);
  
  group('Order Sausage', function () {
    const url = `${baseUrl}/api/orders`;
    
    const payload = JSON.stringify({
      "productOrders": [
        {
          "quantity": 1,
          "product": {
            "id": 1,
            "name": "Сливочная",
            "price": 320,
            "pictureUrl": "https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/6.jpg"
          }
        }
      ]
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      tags: { type: 'order', test_run: runLabel },
    };

    const res = http.post(url, payload, params);
    
    check(res, {
      'is not 500 error': (r) => r.status !== 500,
      'pay status is 200 or 201': (r) => r.status === 200 || r.status === 201,
      'has order id': (r) => {
        try {
          return r.status < 400 && r.json().hasOwnProperty('id');
        } catch (e) {
          return false;
        }
      },
    });

    if (res.status >= 500 && __VU === 1) {
      console.error(`CRITICAL ERROR 500: URL: ${url} | Response: ${res.body.substring(0, 200)}`);
    }
  });

  sleep(0.1);
}

export function handleSummary(data) {
  return {
    //'summary.html': htmlReport(data),
    //'load-performance.json': JSON.stringify(data, null, 2),
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
}