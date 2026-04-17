import http from "k6/http";
import { check } from "k6";

export const options = {
  thresholds: {
    http_req_failed: ['rate<0.01'],    // Ошибок менее 1%
    http_req_duration: ['p(95)<1000'], // 95% запросов быстрее 1.0с
  },
};

export default function () {
  const baseUrl = `https://${__ENV.BASE_URL}`;

  group('Main Page', function () {
    const resIndex = http.get(baseUrl);
    check(resIndex, {
      'index status is 200': (r) => r.status === 200,
    });
  });

  sleep(1);
  
  group('Pay Order', function () {
    const payload = JSON.stringify({
        product: "sausage",
        quantity: 1
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const resPay = http.post(`${baseUrl}/api/orders`, payload, params);
    
    check(resPay, {
      'pay status is 201 or 200': (r) => r.status === 201 || r.status === 200,
    });
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'load-performance.json': JSON.stringify(data, null, 2),
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
}
