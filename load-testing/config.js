import execution from 'k6/execution';

const env = __ENV;

const rawUrl = env.BASE_URL || 'sausage-store.xn--80aebib8andqj5a5u.xn--p1ai';
export const baseUrl = rawUrl.startsWith('http') ? rawUrl : `https://${rawUrl}`;
export const runLabel = env.TEST_RUN || 'default';

export const targetVUs = parseInt(env.TEST_VUS) || 25;

const rawDuration = parseInt(env.TEST_DURATION) || 120;
// Warmup: 20% от теста, но не менее 30 сек
export const warmupSeconds = Math.max(30, Math.ceil(rawDuration * 0.2));
export const mainSeconds = rawDuration;

export const sloErrorRate = parseFloat(env.SLO_ERROR_RATE) || 0.01; // 1%
export const sloTimeLimit = parseInt(env.SLO_LIMIT) || 1000;        // 1000ms
