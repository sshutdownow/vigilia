import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';
import execution from 'k6/execution';
import { Trend } from 'k6/metrics';
import * as conf from './config.js';
import { visitIndex, visitCatalog, createOrder } from './actions.js';
import { sleep } from 'k6';

const limitTrend = new Trend('limit_hit_vus');

function checkLimits(res) {
    if (res.timings.duration > conf.sloTimeLimit || res.status >= 400) {
        const vus = execution.instance.vusActive;
        limitTrend.add(vus);
        console.error(`\nStress Limit Reached: ${vus} VU (Time: ${res.timings.duration}ms, Status: ${res.status})`);
        execution.test.abort('Stress Limit Reached');
    }
}

const steps = 5;
const stepStages = [];
for (let i = 1; i <= steps; i++) {
    let currentTarget = Math.floor(conf.targetVUs * (i / steps));
    stepStages.push({ duration: '15s', target: currentTarget });
    stepStages.push({ duration: '30s', target: currentTarget });
}
stepStages.push({ duration: '30s', target: 0 });

export const options = {
    scenarios: {
        stress_test: {
            executor: 'ramping-vus',
            startVUs: 1,
            stages: stepStages,
            gracefulRampDown: '5s',
            exec: 'default',
        },
    },

    thresholds: {
        'http_req_failed': [{
            threshold: `rate<${conf.sloErrorRate}`,
            abortOnFail: true,
            delayAbortEval: conf.abortDelay
        }],
        'http_req_duration': [{
            threshold: `p(95)<${conf.sloTimeLimit}`,
            abortOnFail: true,
            delayAbortEval: conf.abortDelay
        }],
    },

};

export default function() {
    let res;
    
    res = visitIndex();
    checkLimits(res);
    sleep(0.1);

    res = visitCatalog();
    checkLimits(res);
    sleep(0.4);

    res = createOrder();
    checkLimits(res);
    sleep(0.5);
}

export function handleSummary(data) {
    const result = { 'stdout': textSummary(data, { indent: ' ', enableColors: true }) };
    
    const limitMetric = data.metrics.limit_hit_vus;
    let foundLimit = data.metrics.vus.values.max; 

    if (limitMetric && limitMetric.values.min) {
        foundLimit = Math.floor(limitMetric.values.min);
    }

    const recommended = Math.floor(foundLimit * 0.8) + 1;

    result['limit.json'] = JSON.stringify({
        foundLimitVUs: foundLimit,
        recommendedVUs: recommended
    }, null, 2);
  
    result['k6.env'] = recommended.toString();

    return result;
}
