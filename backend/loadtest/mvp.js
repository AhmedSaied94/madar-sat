// k6 load test for the MVP launch (D4, research R2, FR-002).
//
// Run it on VPS-2 against the public API host, from `backend/`:
//
//   docker run --rm -i grafana/k6:2.3.0 run \
//     -e HOST=https://api.<VPS1_IP>.sslip.io \
//     -e LIVE_RPS=170 -e MATCHES_RPS=50 -e DURATION=10m - < backend/loadtest/mvp.js
//
// The full procedure (the limiter allowlist, the CPU sampling, clearing it again) is in
// `docs/runbooks/load-testing.md`.
//
// Two open-model scenarios, because latency must not throttle the load:
//   live     constant arrival rate on GET /v1/live; a share of the iterations (`REVALIDATE_SHARE`,
//            default 0.5) resends the last ETag as If-None-Match
//   matches  constant arrival rate on GET /v1/matches?from=&to= for one UTC day, today to +3, with
//            about 10 % of the iterations reading one match detail from ids already seen
//
// Cache tag: the API sends no cache response header, so the tag is request-side (T006). The first
// fetch of a URL per minute, per VU, is `cache:miss`; every repeat (a 304 or a full 200 from the
// API's response cache) is `cache:hit`. The report says so (`cache_tags`), and the runbook reads it
// next to the API's own `rc:` counters. Each scenario also has its own p95 threshold, so a full
// `/v1/live` 200 is held to 150 ms whatever its tag.
//
// A `429` is never a pass: the response callback accepts only `200` and `304`, and the report
// counts the `429`s separately.

import { check } from 'k6';
import http from 'k6/http';
import { Counter } from 'k6/metrics';

const HOST = (__ENV.HOST || '').replace(/\/+$/, '');
if (!HOST) {
  throw new Error('HOST is required, for example -e HOST=https://api.<VPS1_IP>.sslip.io');
}

const DURATION = __ENV.DURATION || '10m';
const LIVE_RPS = Number(__ENV.LIVE_RPS || 170);
const MATCHES_RPS = Number(__ENV.MATCHES_RPS || 50);
const REVALIDATE_SHARE = Number(__ENV.REVALIDATE_SHARE ?? 0.5);
if (!(REVALIDATE_SHARE >= 0 && REVALIDATE_SHARE <= 1)) {
  throw new Error('REVALIDATE_SHARE must be between 0 and 1');
}

// Only 200 and 304 are success, so a 429 (the limiter answering the generator) fails the run.
http.setResponseCallback(http.expectedStatuses(200, 304));

const cacheHitRequests = new Counter('cache_hit_requests');
const cacheMissRequests = new Counter('cache_miss_requests');
const notModified = new Counter('etag_304_requests');
const rateLimited = new Counter('rate_limited_429_requests');

export const options = {
  scenarios: {
    live: {
      executor: 'constant-arrival-rate',
      exec: 'live',
      rate: LIVE_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.max(20, Math.ceil(LIVE_RPS / 8)),
      maxVUs: Math.max(100, LIVE_RPS),
      gracefulStop: '30s',
    },
    matches: {
      executor: 'constant-arrival-rate',
      exec: 'matches',
      rate: MATCHES_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.max(10, Math.ceil(MATCHES_RPS / 8)),
      maxVUs: Math.max(50, MATCHES_RPS),
      gracefulStop: '30s',
    },
  },
  thresholds: {
    // FR-002: cached reads p95 < 150 ms on both scenarios, uncached p95 < 400 ms, < 1 % errors.
    // US1 AC1: every /v1/live response (304 or full 200) p95 < 150 ms; matches as a whole < 400 ms.
    'http_req_duration{cache:hit}': ['p(95)<150'],
    'http_req_duration{cache:miss}': ['p(95)<400'],
    'http_req_duration{scenario:live}': ['p(95)<150'],
    'http_req_duration{scenario:matches}': ['p(95)<400'],
    http_req_failed: ['rate<0.01'],
    // A 200 from /v1/matches must be the envelope with a `data` array.
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['min', 'avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  discardResponseBodies: false,
};

// Per-VU state: each VU has its own module instance, which is what makes a revalidation realistic.
let liveEtag = null;
let liveMinute = -1;
let matchEtags = {};
let matchMinutes = -1;
let matchIds = [];

function headerValue(response, name) {
  for (const key of Object.keys(response.headers)) {
    if (key.toLowerCase() === name) {
      return response.headers[key];
    }
  }
  return null;
}

function record(response, cacheHit) {
  (cacheHit ? cacheHitRequests : cacheMissRequests).add(1);
  if (response.status === 304) {
    notModified.add(1);
  }
  if (response.status === 429) {
    rateLimited.add(1);
  }
}

// The route takes a `from`/`to` window (timezone-aware, at most 8 days), not a date: one UTC day.
function utcDayWindow(offsetDays) {
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);
  start.setUTCDate(start.getUTCDate() + offsetDays);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  const iso = (day) => day.toISOString().replace(/\.\d{3}Z$/, 'Z');
  return `from=${encodeURIComponent(iso(start))}&to=${encodeURIComponent(iso(end))}`;
}

export function live() {
  const minute = Math.floor(Date.now() / 60000);
  const firstThisMinute = minute !== liveMinute;
  liveMinute = minute;
  const revalidate = liveEtag !== null && Math.random() < REVALIDATE_SHARE;
  const response = http.get(`${HOST}/v1/live`, {
    tags: { cache: firstThisMinute ? 'miss' : 'hit' },
    headers: revalidate ? { 'If-None-Match': liveEtag } : {},
  });

  record(response, !firstThisMinute);
  const etag = headerValue(response, 'etag');
  if (etag) {
    liveEtag = etag;
  }
}

export function matches() {
  const minute = Math.floor(Date.now() / 60000);
  if (minute !== matchMinutes) {
    // A new minute starts fresh, so the tag matches what the API's one-minute cache windows do.
    matchEtags = {};
    matchMinutes = minute;
  }

  const detail = matchIds.length > 0 && Math.random() < 0.1;
  const path = detail ? `/v1/matches/${matchIds[Math.floor(Math.random() * matchIds.length)]}` : `/v1/matches?${utcDayWindow(__ITER % 4)}`;
  const url = `${HOST}${path}`;
  const known = matchEtags[path] || null;
  const revalidate = known !== null;

  const response = http.get(url, {
    tags: { cache: revalidate ? 'hit' : 'miss' },
    headers: revalidate ? { 'If-None-Match': known } : {},
  });

  record(response, revalidate);
  const etag = headerValue(response, 'etag');
  if (etag) {
    matchEtags[path] = etag;
  }

  if (!detail && response.status === 200) {
    let body = null;
    try {
      body = response.json();
    } catch (error) {
      // Not JSON: the check below fails it.
    }
    const rows = body && Array.isArray(body.data) ? body.data : null;
    check(response, { 'matches 200 has a data array': () => rows !== null });
    if (rows !== null) {
      for (const row of rows) {
        if (row && row.id !== undefined) {
          matchIds.push(row.id);
        }
      }
      if (matchIds.length > 50) {
        matchIds = matchIds.slice(-50);
      }
    }
  }
}

function metricValues(data, name) {
  const metric = data.metrics[name];
  return metric ? metric.values : {};
}

function thresholds(data) {
  const result = {};
  for (const [name, metric] of Object.entries(data.metrics)) {
    if (metric.thresholds) {
      result[name] = Object.fromEntries(Object.entries(metric.thresholds).map(([rule, state]) => [rule, Boolean(state.ok)]));
    }
  }
  return result;
}

function latency(data, name) {
  const v = metricValues(data, name);
  return {
    p50_ms: v['med'] ?? null,
    p95_ms: v['p(95)'] ?? null,
    p99_ms: v['p(99)'] ?? null,
    avg_ms: v['avg'] ?? null,
    max_ms: v['max'] ?? null,
  };
}

export function handleSummary(data) {
  const total = metricValues(data, 'http_reqs').count || 0;
  const hits = metricValues(data, 'cache_hit_requests').count || 0;
  const misses = metricValues(data, 'cache_miss_requests').count || 0;

  const report = {
    generated_at: new Date().toISOString(),
    host: HOST,
    live_rps: LIVE_RPS,
    matches_rps: MATCHES_RPS,
    duration: DURATION,
    revalidate_share: REVALIDATE_SHARE,
    cache_tags: 'request-side: first fetch of a URL per minute per VU = cache:miss, every repeat = cache:hit (the API sends no cache response header)',
    checks_passed: metricValues(data, 'checks').rate ?? null,
    totals: {
      requests: total,
      error_rate: metricValues(data, 'http_req_failed').rate || 0,
      not_modified_304: metricValues(data, 'etag_304_requests').count || 0,
      rate_limited_429: metricValues(data, 'rate_limited_429_requests').count || 0,
      cache_hit_share: hits + misses === 0 ? 0 : hits / (hits + misses),
      cache_hit_requests: hits,
      cache_miss_requests: misses,
    },
    latency_ms: {
      all: latency(data, 'http_req_duration'),
      cache_hit: latency(data, 'http_req_duration{cache:hit}'),
      cache_miss: latency(data, 'http_req_duration{cache:miss}'),
      live: latency(data, 'http_req_duration{scenario:live}'),
      matches: latency(data, 'http_req_duration{scenario:matches}'),
    },
    thresholds: thresholds(data),
  };

  const text = [
    `host ${report.host}  rate live=${LIVE_RPS}/s matches=${MATCHES_RPS}/s  ${DURATION}`,
    `requests ${report.totals.requests}  errors ${(report.totals.error_rate * 100).toFixed(2)}%  429s ${report.totals.rate_limited_429}  304s ${report.totals.not_modified_304}  cache hit ${(report.totals.cache_hit_share * 100).toFixed(1)}%`,
    `all     p50 ${report.latency_ms.all.p50_ms} ms  p95 ${report.latency_ms.all.p95_ms} ms  p99 ${report.latency_ms.all.p99_ms} ms`,
    `hit     p95 ${report.latency_ms.cache_hit.p95_ms} ms (target < 150)`,
    `miss    p95 ${report.latency_ms.cache_miss.p95_ms} ms (target < 400)`,
    `live    p95 ${report.latency_ms.live.p95_ms} ms (target < 150, every response)`,
    `matches p95 ${report.latency_ms.matches.p95_ms} ms (target < 400)`,
    ...Object.entries(report.thresholds).map(
      ([name, rules]) => `${name} ${Object.entries(rules).map(([rule, ok]) => `${rule} ${ok ? 'PASS' : 'FAIL'}`).join(' ')}`,
    ),
    'full JSON written to loadtest-summary.json',
  ].join('\n');

  return {
    stdout: `${text}\n`,
    'loadtest-summary.json': JSON.stringify(report, null, 2),
  };
}
