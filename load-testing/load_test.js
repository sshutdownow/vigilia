import http from "k6/http";
import { check, sleep, group, textSummary } from "k6";
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/latest/dist/bundle.js';

const testVUs = __ENV.TEST_VUS ? parseInt(__ENV.TEST_VUS) : 50;
const testDuration = __ENV.TEST_DURATION ? parseInt(__ENV.TEST_DURATION) : 180;
const warmupDuration = (testDuration / 5) | 0;

export const options = {
   scenarios: {
    warmup: {
      executor: 'constant-vus',
      vus: 5,
      duration: `${warmupDuration}s`,
      exec: 'runTest',
      tags: { stage: 'warmup' },
    },
    main_test: {
      executor: 'constant-vus',
      vus: testVUs,
      duration: `${testDuration}s`,
      startTime: `${warmupDuration}s`, 
      exec: 'runTest',
      tags: { stage: 'main' },
    },
  },
  // scenarios: {
  //   ramping_load: {
  //     executor: 'ramping-vus',
  //     startVUs: 0,
  //     stages: [
  //       // Линейный рост до максимума
  //       { duration: `${testRamp}s`, target: testVUs },
  //       // Плато (стабильная нагрузка)                        
  //       { duration: `${testDuration}s`, target: testVUs },
  //       // Линейное снижение
  //       { duration: `${testRamp}s`, target: 0 },
  //     ],
  //     gracefulRampDown: '30s',
  //     exec: 'runTest',
  //   },
  // },  
  thresholds: {
    'http_req_failed': ['rate<0.01'],    // Ошибок менее 1%
    'http_req_duration': ['p(95)<1000'], // 95% запросов быстрее 1.0с
    'http_req_duration{scenario:main_test}': ['p(95)<1000'], // отчёт
  },
  summaryTrendStats: ["avg", "min", "med", "max", "p(95)", "p(99)"],
};

export default function() {
  runTest();
}

export function runTest() {
  const baseUrl  = __ENV.BASE_URL ? `https://${__ENV.BASE_URL}` : 'https://sausage-store.vigilia.site';
  const runLabel = __ENV.TEST_RUN || 'default';

  group('Main Page', function () {
    const resIndex = http.get(baseUrl, {
      tags: { type: 'index', test_run: runLabel }
    });
    check(resIndex, {
      'index status is 200': (r) => r.status === 200,
      'body contains title Frontend': (r) => r.body.includes('<title>Frontend</title>'),
    });
    http.batch([
      ['GET', `${baseUrl}/runtime.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/polyfills.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/styles.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/vendor.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/main.js`, null, { tags: { type: 'static', test_run: runLabel } }],
    ]);
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
      'pay status is 200 or 201': (r) => r.status === 200 || r.status === 201,
      'is not 500 error': (r) => r.status !== 500,
      'has order id': (r) => {
        try {
          const body = r.json();
          return r.status < 400 && body !== null && body.hasOwnProperty('id');
        } catch (e) {
          return false;
        }
      },
    });

    if (res.status >= 500 && __VU === 1) {
      console.error(`CRITICAL ERROR 500: URL: ${url} | Response: ${res.body ? res.body.substring(0, 200) : 'empty'}`);
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