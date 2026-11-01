import { HttpResponse, http as mswHttp } from 'msw';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { server } from '../test/server';
import { adminHttp, ApiError, bindSession, etagOf, getAccessToken, operationTemplate, setAccessToken } from './http';

// The mutator's own rules (T095): the CSRF header, one shared refresh behind two expired requests,
// a refresh that fails, and a body that does not match its Zod schema.

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const errorBody = (code: string): Record<string, unknown> => ({
  success: false,
  data: null,
  error: { code, message: 'x' },
  meta: {},
});

const sessionBody = {
  access_token: 'fresh',
  token_type: 'Bearer',
  expires_in: 900,
  admin: { id: 1, email: 'editor@example.com', name: 'محرر', role: 'editor' },
};

const bulk = () => adminHttp<unknown>({ method: 'POST', url: '/admin/api/matches/bulk', data: { action: 'remove_channels', items: [] } });

beforeEach(() => {
  setAccessToken(null);
  bindSession({});
  document.cookie = 'madar_csrf=; Max-Age=0';
});

afterEach(() => {
  document.cookie = 'madar_csrf=; Max-Age=0';
});

describe('adminHttp', () => {
  it('sends the CSRF cookie value in X-CSRF-Token on a mutating request, and the bearer token', async () => {
    document.cookie = 'madar_csrf=csrf-abc';
    setAccessToken('token-1');
    let seen: { csrf: string | null; auth: string | null } | null = null;

    server.use(
      mswHttp.post('*/admin/api/matches/bulk', ({ request }) => {
        seen = { csrf: request.headers.get('X-CSRF-Token'), auth: request.headers.get('Authorization') };
        return HttpResponse.json(envelope({ updated: [] }));
      }),
    );

    await bulk();

    expect(seen).toEqual({ csrf: 'csrf-abc', auth: 'Bearer token-1' });
  });

  it('bis: leaves the CSRF header off a read', async () => {
    document.cookie = 'madar_csrf=csrf-abc';
    let seen: string | null = 'unset';

    server.use(
      mswHttp.get('*/admin/api/sources', ({ request }) => {
        seen = request.headers.get('X-CSRF-Token');
        return HttpResponse.json(envelope([{
            name: 'ysscores',
            kind: 'scraper',
            is_enabled: true,
            breaker: 'closed',
            breaker_opened_at: null,
            consecutive_failures: 0,
            paused: false,
            last_success_at: null,
            last_run: null,
            items_24h: [],
            error_rate_24h: null,
            running: false,
          }]));
      }),
    );

    await adminHttp({ method: 'GET', url: '/admin/api/sources' });

    expect(seen).toBeNull();
  });

  it('refreshes once for two parallel requests that expire, then retries both', async () => {
    setAccessToken('expired');
    let refreshes = 0;

    server.use(
      mswHttp.post('*/admin/api/auth/refresh', () => {
        refreshes += 1;
        return HttpResponse.json(envelope(sessionBody));
      }),
      mswHttp.post('*/admin/api/matches/bulk', ({ request }) =>
        request.headers.get('Authorization') === 'Bearer fresh'
          ? HttpResponse.json(envelope({ updated: [{ id: 1, etag: '"a"' }] }))
          : HttpResponse.json(errorBody('token_expired'), { status: 401 }),
      ),
    );

    const [first, second] = await Promise.all([bulk(), bulk()]);

    expect(refreshes).toBe(1);
    expect(first).toEqual(envelope({ updated: [{ id: 1, etag: '"a"' }] }));
    expect(second).toEqual(envelope({ updated: [{ id: 1, etag: '"a"' }] }));
    expect(getAccessToken()).toBe('fresh');
  });

  it('retries only once, so a second 401 is not a loop', async () => {
    setAccessToken('expired');
    let refreshes = 0;
    let calls = 0;

    server.use(
      mswHttp.post('*/admin/api/auth/refresh', () => {
        refreshes += 1;
        return HttpResponse.json(envelope(sessionBody));
      }),
      mswHttp.post('*/admin/api/matches/bulk', () => {
        calls += 1;
        return HttpResponse.json(errorBody('token_expired'), { status: 401 });
      }),
    );

    await expect(bulk()).rejects.toMatchObject({ code: 'token_expired' });
    expect(refreshes).toBe(1);
    expect(calls).toBe(2);
  });

  it('clears the token and reports the refusal when the refresh is refused', async () => {
    setAccessToken('expired');
    const onExpired = vi.fn();
    bindSession({ onExpired });

    server.use(
      mswHttp.post('*/admin/api/auth/refresh', () => HttpResponse.json(errorBody('refresh_invalid'), { status: 401 })),
      mswHttp.post('*/admin/api/matches/bulk', () => HttpResponse.json(errorBody('token_expired'), { status: 401 })),
    );

    // The refusal is reported as itself, not as the 401 that led to it (A-R1-19).
    await expect(bulk()).rejects.toMatchObject({ code: 'refresh_invalid' });
    expect(getAccessToken()).toBeNull();
    expect(onExpired).toHaveBeenCalledTimes(1);
  });

  it('keeps the session when the refresh only fails on the network', async () => {
    setAccessToken('expired');
    const onExpired = vi.fn();
    bindSession({ onExpired });
    let refreshes = 0;

    server.use(
      mswHttp.post('*/admin/api/auth/refresh', () => {
        refreshes += 1;
        return HttpResponse.error();
      }),
      mswHttp.post('*/admin/api/matches/bulk', () => HttpResponse.json(errorBody('token_expired'), { status: 401 })),
    );

    await expect(bulk()).rejects.toMatchObject({ code: 'token_expired' });
    // The refresh is tried once more before the editor hears about it, and nobody is signed out.
    expect(refreshes).toBe(2);
    expect(getAccessToken()).toBe('expired');
    expect(onExpired).not.toHaveBeenCalled();
  });

  it('carries the response ETag on the envelope it returns', async () => {
    server.use(
      mswHttp.get('*/admin/api/sources', () =>
        HttpResponse.json(envelope([{
            name: 'ysscores',
            kind: 'scraper',
            is_enabled: true,
            breaker: 'closed',
            breaker_opened_at: null,
            consecutive_failures: 0,
            paused: false,
            last_success_at: null,
            last_run: null,
            items_24h: [],
            error_rate_24h: null,
            running: false,
          }]), {
          headers: { ETag: '"v7"' },
        }),
      ),
    );

    const body = await adminHttp<Record<string, unknown>>({ method: 'GET', url: '/admin/api/sources' });

    expect(etagOf(body)).toBe('"v7"');
    expect(etagOf({ success: true })).toBeNull();
  });

  it('matches a literal id to the operation template Prism names its examples by', () => {
    // `?mock=edit_conflict` on `/matches/48213` must find `PATCH /admin/api/matches/{}` (A-R1-17).
    expect(operationTemplate('PATCH', '/admin/api/matches/48213')).toBe('PATCH /admin/api/matches/{}');
    expect(operationTemplate('GET', '/admin/api/matches')).toBe('GET /admin/api/matches');
    expect(operationTemplate('GET', '/admin/api/unknown/1')).toBeUndefined();
  });

  it('sends the Prefer header for a named example on an operation with a path parameter', async () => {
    // The spec keys its examples by `{match_id}` and the mutator by `{}`; the dev map normalises the
    // spec's path, so a page at `/matches/48213?mock=edit_conflict` really asks Prism for that example (A-R2-4).
    window.history.replaceState({}, '', '/matches/48213?mock=edit_conflict');
    let prefer: string | null = null;

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', ({ request }) => {
        prefer = request.headers.get('Prefer');
        return HttpResponse.json(errorBody('edit_conflict'), { status: 409 });
      }),
    );

    try {
      await adminHttp({ method: 'PATCH', url: '/admin/api/matches/48213' }).catch(() => undefined);
    } finally {
      window.history.replaceState({}, '', '/');
    }

    expect(prefer).toBe('code=409, example=edit_conflict');
  });

  it('rejects a body that fails its Zod schema instead of passing it through', async () => {
    server.use(
      mswHttp.get('*/admin/api/sources', () =>
        HttpResponse.json({ success: true, data: { not: 'a list' }, error: null, meta: {} }),
      ),
    );

    await expect(adminHttp({ method: 'GET', url: '/admin/api/sources' })).rejects.toMatchObject({
      code: 'invalid_response',
    });
  });

  it('turns an error envelope into an ApiError carrying its code and meta', async () => {
    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'something long and internal' },
            meta: { current_etag: '"b"', changed_by: { kind: 'admin', name: 'سارة' } },
          },
          { status: 409 },
        ),
      ),
    );

    const failure = await adminHttp({ method: 'PATCH', url: '/admin/api/matches/48213' }).catch((error: unknown) => error);

    expect(failure).toBeInstanceOf(ApiError);
    expect(failure).toMatchObject({ code: 'edit_conflict', status: 409, meta: { current_etag: '"b"' } });
  });
});
