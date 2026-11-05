# Load test

The MVP launch gate needs proof that VPS-1 holds the launch load: `/v1/live` at 170 requests/s and
`/v1/matches` at 50 requests/s for ten minutes each, p95 under 150 ms on cache hits and under 400 ms
on misses, and fewer than 1 % errors (system-design §11, spec FR-002, research R2). This runbook is
the whole procedure: the generator's allowlist window, the run, the CPU sampling, and putting the
limiter back.

The script is [`backend/loadtest/mvp.js`](../../backend/loadtest/mvp.js). It runs on **VPS-2**, so
the result measures the API and Caddy and not your home uplink, and it uses **k6** in a pinned
container (`grafana/k6:2.3.0`, multi-arch, so the arm64 variant is what VPS-2 pulls). Nothing is
installed on the host.

## What the script does

| Scenario | Rate (default) | Requests |
| --- | --- | --- |
| `live` | `LIVE_RPS` = 170/s for `DURATION` = 10m | `GET /v1/live`; a share `REVALIDATE_SHARE` (default `0.5`) resends the last `ETag` as `If-None-Match` |
| `matches` | `MATCHES_RPS` = 50/s for `DURATION` | `GET /v1/matches?from=<day>T00:00:00Z&to=<day+1>T00:00:00Z` for one UTC day, today to +3, and about 10 % `GET /v1/matches/<id>` from ids already seen |

Both use `constant-arrival-rate`, so a slow response never lowers the load. Thresholds encode FR-002
and US1 AC1:

- `http_req_duration{cache:hit}` `p(95)<150` and `http_req_duration{cache:miss}` `p(95)<400`, over both scenarios;
- `http_req_duration{scenario:live}` `p(95)<150` over **every** `/v1/live` response, full `200`s
  included, and `http_req_duration{scenario:matches}` `p(95)<400`;
- `checks` `rate>0.99`: a `200` from `/v1/matches` must be the envelope with a `data` array;
- `http_req_failed<0.01`, with a response callback that accepts **only** `200` and `304`, so a `429`
  (the limiter answering the generator) fails the run instead of passing as a client error.

`k6 inspect` lists them without sending a request:

```bash
docker run --rm -i grafana/k6:2.3.0 inspect -e HOST=https://api.<VPS1_IP>.sslip.io - < backend/loadtest/mvp.js
```

The `cache` tag is **request-side**, because the API sends no cache response header: the first fetch
of a URL per minute (per k6 VU) is `cache:miss`, and every repeat, `304` or a full `200` from the
response cache, is `cache:hit`. Read it beside the API's own `cache_hit` / `cache_miss` lines, not
instead of them.

At the end, `handleSummary` prints a text block (requests, error share, `429` count, `304` share,
cache-hit share, p50/p95/p99, and each threshold as `PASS`/`FAIL`) and writes the same data as JSON to
`loadtest-summary.json` inside the container.

## 1. Confirm the address VPS-1 sees for VPS-2

Every VPS-1 command below runs in the "Working on VPS-1" shell
([deploy-and-rollback](deploy-and-rollback.md#working-on-vps-1)), which is `deploy` (`sudo -iu
deploy`, the user in the docker group). Commands run from your machine use `sudo -iu deploy docker
…` over the `madar-vps1` / `madar-vps2` SSH aliases. Note the limiter's current keys, then send one
request from VPS-2:

```bash
# VPS-1, as deploy
dc exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli --scan --pattern "rl:ip:*"'
```

```bash
# your machine
ssh madar-vps2 "curl -sS -o /dev/null -w '%{http_code}\n' https://api.<VPS1_IP>.sslip.io/v1/live"
```

Scan again on VPS-1: the new `rl:ip:<ip>:<minute>` key holds **VPS-2's public address** — that is the
value the allowlist needs. (Caddy keeps no access log here; the limiter's key is the record. Caddy's
`dc logs caddy` shows reloads and errors only.)

If the new key's address is the Docker bridge gateway (`172.30.0.1`), or every client shares one
address, the deploy is missing B2's `TRUSTED_PROXIES` and the fixed bridge subnet: stop and fix that
first, because the allowlist and every per-client bucket would be wrong.

## 2. Open the window

In VPS-1's `/srv/madar/.env` (mode 600, owner `deploy`), set the address from step 1. Leave every
other value alone:

```text
RATE_LIMIT_EXEMPT_IPS=203.0.113.7
```

Then recreate the public API and confirm the running container has the value. Check the effective
setting, not the log: the startup warning goes to stderr, which a plain `docker logs … | grep`
never sees.

```bash
# VPS-1, as deploy
dc up -d --force-recreate api-public
docker exec madar-api-public-1 sh -c 'test -n "$RATE_LIMIT_EXEMPT_IPS" && echo "OPEN: $RATE_LIMIT_EXEMPT_IPS" || { echo "still closed"; exit 1; }'
# OPEN: 203.0.113.7
docker logs --tail 50 madar-api-public-1 2>&1 | grep ratelimit.exempt_enabled   # the startup warning, for the report
```

(The "Working on VPS-1" shell exports `IMAGE_TAG`; without it Compose wants the unusable `none`
image.) `still closed` means the `.env` edit or the recreate didn't take: fix it before step 3.

The warning line lists the addresses. From now on every exempt request logs `ratelimit.exempt at
debug` and one `info` line per minute: that is the window's evidence for the report. The `api-admin`
app is untouched (no limiter), and `/healthz` is exempt either way.

## 3. Run it

Start the CPU and memory sample on VPS-1 first, in its own shell, so it covers the whole run:

```bash
# VPS-1, as deploy: every 10 s, UTC timestamps, both the API and Caddy
for _ in $(seq 1 60); do
  date -u +%FT%TZ
  docker stats --no-stream --format '{{.Name}} {{.CPUPerc}} {{.MemUsage}}' madar-api-public-1 madar-caddy-1
  sleep 10
done | tee /tmp/mvp-load-vps1.log
```

Then from the repository checkout on your machine, stream the script to VPS-2. Nothing has to be
copied there: the container reads the script from stdin.

```bash
ssh madar-vps2 \
  'sudo -iu deploy docker run --rm -i grafana/k6:2.3.0 run \
     -e HOST=https://api.<VPS1_IP>.sslip.io -e LIVE_RPS=170 -e MATCHES_RPS=50 \
     -e REVALIDATE_SHARE=0.5 -e DURATION=10m -' \
  < backend/loadtest/mvp.js | tee /tmp/mvp-load-k6.txt
```

Keep the printed block: it is what the report records. A non-zero exit means a threshold was crossed;
read the `FAIL` lines. `429` in the summary means the allowlist missed (wrong address, or
`api-public` was not recreated) — stop and go back to step 2.

## 4. Close the window

Back on VPS-1, empty the setting and recreate:

```bash
# in /srv/madar/.env
RATE_LIMIT_EXEMPT_IPS=
```

```bash
# VPS-1, as deploy
dc up -d --force-recreate api-public
docker exec madar-api-public-1 sh -c 'test -z "$RATE_LIMIT_EXEMPT_IPS" && echo closed || { echo "STILL OPEN: $RATE_LIMIT_EXEMPT_IPS"; exit 1; }'
# closed
```

`STILL OPEN` (exit 1) means the window is not closed: fix `.env` and recreate again before anything
else. From your machine the same check is
`ssh madar-vps1 "sudo -iu deploy docker exec madar-api-public-1 printenv RATE_LIMIT_EXEMPT_IPS"`,
which must print an empty line.

Leave it empty. An allowlisted address during normal traffic is a hole, and the security review
checks for one ([quickstart](../../specs/004-d04-mvp-launch/quickstart.md#lane-b1-client-ip-load-security)).

## 5. Prove the limit is back

From VPS-2, 700 requests in a row. The per-IP limit is 600/min, so the tail must be refused:

```bash
for _ in $(seq 1 700); do
  curl -s -o /dev/null -w '%{http_code}\n' https://api.<VPS1_IP>.sslip.io/v1/live
done | sort | uniq -c
```

Expect a few hundred `200`s, then `429`s in the same minute. All `200`s means the allowlist is still
open or the requests spread over more than a minute; re-run it now and check the timestamp of the
`rl:ip:` key.

## 6. Write the report

Create `docs/load-tests/<YYYY-MM-DD>-mvp.md` in the format of
[data-model.md](../../specs/004-d04-mvp-launch/data-model.md#load-report-docsload-testsdate-mvpmd-b1):
date, git SHA, API image tag, VPS-1 shape, the window's start and end (UTC), the k6 version and
command, then per scenario the rate, duration, requests, p50/p95/p99, error share, `429` count, `304`
share and cache-hit share, then VPS-1's CPU and memory from `/tmp/mvp-load-vps1.log`, pass or fail
per FR-002 target, and any fix and re-run.

## If a target fails

1. **`/v1/live` misses p95 or CPU saturates.** Resize VPS-1 if the allowance permits, which also sets
   `API_PUBLIC_WORKERS` ([provision-host.md](provision-host.md#resize-an-instance)), then re-run and
   keep both runs in the report. More workers on the same core won't help: the D4 run saturated it.
2. **`/v1/matches` misses on uncached reads.** The read path is Redis-cached with versioned keys; a
   miss there points at the database. Profile the by-day query with `EXPLAIN ANALYZE` before changing
   anything.
3. **Still failing.** Stop and tell the owner before taking system-design §11's contingency (Caddy
   answering `/v1/live` from a short-lived cache, which needs a custom Caddy image and is a B2
   change). Do not adopt it without a second measured run.

## The two settings this touches

| Variable | Where | Rule |
| --- | --- | --- |
| `RATE_LIMIT_EXEMPT_IPS` | VPS-1 `.env`, only during the window | Comma list of exact client IPs that skip the `/v1` limiter. Empty by default; a non-empty value warns at startup, and a bad value fails startup. |
| `TRUSTED_PROXIES` | VPS-1 `.env` (B2's Compose passes it) | Who may set `X-Forwarded-For`. `api-public`: `127.0.0.1,172.30.0.1`. `api-admin` keeps the default `10.8.0.1`. See [response-cache-and-limits](response-cache-and-limits.md#client-ip). |
