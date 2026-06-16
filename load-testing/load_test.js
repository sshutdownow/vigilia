import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';
import * as conf from './config.js';
import { visitIndex, visitCatalog, createOrder } from './actions.js';
import { sleep } from 'k6';

export const options = {
    scenarios: {
        warmup: {
            executor: 'constant-vus',
            vus: Math.max(2, Math.floor(conf.targetVUs * 0.25)),
            duration: `${conf.warmupSeconds}s`,
            startTime: '0s',
            exec: 'default',
            tags: { stage: 'warmup' },
        },
        main_test: {
            executor: 'constant-vus',
            vus: conf.targetVUs,
            duration: `${conf.mainSeconds}s`,
            startTime: `${conf.warmupSeconds}s`,
            exec: 'default',
            tags: { stage: 'main' },
        },
    },
    thresholds: {
        'http_req_failed{scenario:main_test}': [`rate<${conf.sloErrorRate}`],
        'http_req_duration{scenario:main_test}': [`p(95)<${conf.sloTimeLimit}`],
    },
    summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(95)', 'p(99)'],
};

export default function() {
    visitIndex();
    sleep(0.1);

    visitCatalog();
    sleep(0.4);

    createOrder();
    sleep(0.5);
}

export function handleSummary(data) {
    return {
        'stdout': textSummary(data, { indent: ' ', enableColors: true }),
        'summary.json': JSON.stringify(data, null, 2),
    };
}
