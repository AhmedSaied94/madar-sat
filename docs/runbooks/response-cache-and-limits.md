# Response cache and rate limits

What the public API caches, for how long, how to turn the cache off, and how the `/v1` limits work — including what a carrier-grade NAT false positive looks like. Background: system-design §6.3.2, constitution V and VI, research R10–R11, and `backend/app/api/cache.py` and `backend/app/api/ratelimit.py`.

## The response cache

The cache key is the response's own weak `ETag`, which already holds the route, the normalized query, the dataset versions the route reads, `MEDIA_BASE_URL` and the contract version. The serialized envelope is stored at `rc:<etag>` and served as is on a hit, with the same `ETag`/`Cache-Control`/`Vary` headers. Nothing is ever deleted by key scan: a write bumps a dataset version (`dataset_versions`), so the next request computes a different tag and misses. The old key expires on its own TTL.

| Route | TTL |
| --- | --- |
| `/v1/matches` | 60 s |
| `/v1/matches/{id}`, `/v1/live` | 15 s |
| `/v1/satellites`, `/v1/satellites/{id}/channels`, `/v1/channels/{id}` | 300 s (5 min) |
| `/v1/teams`, `/v1/teams/{id}`, `/v1/competitions`, `/v1/competitions/{id}` | 300 s / 3600 s (1 h for competitions) |
| `/v1/rights-holders*`, `/v1/commentators*` | 3600 s / 300 s |
| `/v1/devices*` | never cached: `Cache-Control: no-store`, no `ETag` |

Rules the code keeps:

- A body over `RESPONSE_CACHE_MAX_BYTES` (default 512 KB) is not stored; the route still answers normally.
- A Redis error is a miss, logged as `cache_lookup_failed` / `cache_store_failed`; a cache outage never becomes a 5xx.
- An editor's save bumps a version, so the admin edit → client ≤ 60 s promise holds without deleting anything.
- `304` behaviour is unchanged: `If-None-Match` matching the computed tag is answered before the route runs.

Log lines on the `api-public` service: `cache_hit`, `cache_miss`, `cache_skip_large`, `cache_lookup_failed`, `cache_store_failed`.

### Turn it off

In VPS-1's `/srv/madar/.env`:

```text
RESPONSE_CACHE_ENABLED=false
```

Then `dc up -d --force-recreate api-public` and check `curl -fsS http://127.0.0.1:8000/healthz`. Every read then goes to the database; the ETags and 304s stay exactly the same. Turn it back on the same way. A size change is `RESPONSE_CACHE_MAX_BYTES` (bytes) and needs the same restart.

## The rate limits

A dependency on every public router only (`app/api/ratelimit.py`); the admin app has none. `/healthz` is exempt. The window is two fixed buckets, weighted across the minute boundary.

| Bucket | Key | Default |
| --- | --- | --- |
| Device, when `Authorization: Device <token>` belongs to a live device | `rl:d:<first 16 hex of sha256(token)>:<minute>` | 120 / min |
| Everything else, by trusted client IP | `rl:ip:<ip>:<minute>` | 600 / min |
| `POST /v1/devices`, per IP | `rl:reg:<ip>:<10-minute slot>` | 30 / 10 min |

Over a limit: `429` with `Retry-After: <s>` and the envelope `{"error": {"code": "rate_limited"}, "meta": {"retry_after_s": <s>}}`.

Why a token counts only when it is live: a client could otherwise send a fresh made-up token on every request and get a fresh bucket. `dv:<sha256(token)>` caches "this hash is a live device" for 10 minutes (60 s for an unknown one), filled from one indexed `devices.token_hash` lookup; `app/devices/service.py` deletes it on rotation and deletion, so a revoked token stops counting as valid at once. Redis down → every request is allowed (logged as `ratelimit_unavailable`).

The values are settings, not contract. To change one, edit VPS-1's `/srv/madar/.env` and recreate `api-public`:

```text
RATE_LIMIT_DEVICE_PER_MIN=120
RATE_LIMIT_IP_PER_MIN=600
RATE_LIMIT_REGISTER_PER_10MIN=30
```

### A CGNAT false positive

Many phones behind one carrier IP share the per-IP bucket only when they send **no valid device token**; the app sends its token on every `/v1` request once it has registered, so phones are counted apart. A false positive looks like this:

- a burst of `429 rate_limited` from a few IPs in the `api-public` log (`api_error request_id=… code=rate_limited`), with normal traffic between them;
- the client is an app build that has not registered yet (no token), or a script/proxy without one.

Raise `RATE_LIMIT_IP_PER_MIN` for that window (for example to 1200), recreate `api-public`, and watch. If it repeats every day at the same hour, look for a client that never registers: the fix is the client, not a higher limit. Do not remove the IP bucket: it is what stops a token-spraying client.
