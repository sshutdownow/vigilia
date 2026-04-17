import http from "k6/http";
import { check, sleep, group, textSummary } from "k6";

export const options = {
  thresholds: {
    http_req_failed: ['rate<0.01'],    // Ошибок менее 1%
    http_req_duration: ['p(95)<1000'], // 95% запросов быстрее 1.0с
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL ? `https://${__ENV.BASE_URL}/` : 'https://sausage-store.vigilia.site/';

  group('Main Page', function () {
    const resIndex = http.get(baseUrl);
    check(resIndex, {
      'index status is 200': (r) => r.status === 200,
      'body contains sausage': (r) => r.body.includes('sausage'),
    });
  });

  sleep(2);
  
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
    };

    const res = http.post(url, payload, params);
    
    check(res, {
      'pay status is 200 or 201': (r) => r.status === 200 || r.status === 201,
      'has order id': (r) => r.json().hasOwnProperty('id'),
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