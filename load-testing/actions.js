import http from 'k6/http';
import { check, sleep, group } from 'k6';
import * as conf from './config.js'; 

export function visitIndex() {
    let res;
    group('1_Main_Page', function () {
        res = http.get(conf.baseUrl, { 
            tags: { name: 'Index', type: 'index', test_run: conf.runLabel } 
        });
        check(res, {
            'status 200': (r) => r.status === 200,
            'title ok': (r) => r.body && r.body.includes('<title>Frontend</title>'),
        });
    });
/*  
    слишком большой трафик
    http.batch([
      ['GET', `${baseUrl}/runtime.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/polyfills.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/styles.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/vendor.js`, null, { tags: { type: 'static', test_run: runLabel } }],
      ['GET', `${baseUrl}/main.js`, null, { tags: { type: 'static', test_run: runLabel } }],
    ]);
*/
    return res;
}

export function visitCatalog() {
    let res;
    group('2_List_Sausages', function () {
        res = http.get(`${conf.baseUrl}/api/products`, { 
            headers: { 'Accept': 'application/json' },
            tags: { name: 'Catalogue', type: 'read', test_run: conf.runLabel } 
        });
        check(res, { 'status 200': (r) => r.status === 200 });
    });

    return res;
}

export function createOrder() {
    let res;
    group('3_Order_Sausages', function () {
        const url = `${conf.baseUrl}/api/orders`;
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
            tags: { name: 'Order', type: 'write', test_run: conf.runLabel },
        };

        res = http.post(url, payload, params);

        check(res, {
            'status 200/201': (r) => r.status === 200 || r.status === 201,
            'has id': (r) => { try { return r.json().hasOwnProperty('id'); } catch(e) { return false; } }
        });
    });

    return res;
}
