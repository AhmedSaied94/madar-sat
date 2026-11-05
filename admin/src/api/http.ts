// The axios mutator behind the Orval client (src/api/generated). This file is hand-written; the rest is generated.
//
// - Same origin: the admin spec's paths already start with /admin/api, and the admin app is served
//   from the same wg0 host (Vite proxies /admin/api to Prism in dev).
// - Cookies travel with every call (the refresh and CSRF cookies of contracts/admin-auth-v1.md).
// - Every response body is parsed with the Zod schema Orval generated for its operation.
// - Failures become an ApiError carrying the envelope's error.code and meta; error.message is dropped.
import axios, { type AxiosRequestConfig } from 'axios';
import { z } from 'zod';

import type { ErrorBody, Session } from './generated/admin.schemas';
import {
  addHiddenChannelNameResponse,
  bulkResponse,
  deleteChannelResponse,
  deleteCommentatorResponse,
  deleteCompetitionResponse,
  deleteRightsHolderResponse,
  deleteSatelliteResponse,
  deleteTeamResponse,
  getChannelResponse,
  getCommentatorResponse,
  getCompetitionResponse,
  getDashboardResponse,
  getImportRunRawResponse,
  getImportRunResponse,
  getMatchResponse,
  getRightsHolderResponse,
  getSatelliteResponse,
  getTeamResponse,
  healthEndpointResponse,
  ignoreNameResponse,
  listBroadcastPresetsResponse,
  listChannelsResponse,
  listCommentatorsResponse,
  listCompetitionsResponse,
  listHiddenChannelNamesResponse,
  listMatchesResponse,
  listNamesResponse,
  listRightsHoldersResponse,
  listSatellitesResponse,
  listSourcesResponse,
  listSourceRunsResponse,
  listTeamsResponse,
  loginResponse,
  logoutResponse,
  mapNameResponse,
  meResponse,
  orderCompetitionsResponse,
  orderSatellitesResponse,
  patchChannelResponse,
  patchCommentatorResponse,
  patchCompetitionResponse,
  patchMatchResponse,
  patchRightsHolderResponse,
  patchSatelliteResponse,
  patchTeamResponse,
  pauseSourceResponse,
  refreshResponse,
  removeHiddenChannelNameResponse,
  reorderRightsHoldersResponse,
  resumeSourceResponse,
  uploadMediaResponse,
} from './generated/admin.zod';

export const NETWORK_ERROR = 'network_error';
export const INVALID_RESPONSE = 'invalid_response';

/**
 * The `ETag` a response carried, kept on its envelope (A-R1-2). Every write and read goes through this
 * mutator, so the version travels with the body the UI already holds instead of a second `GET`.
 */
const RESPONSE_ETAG: unique symbol = Symbol('madar.responseEtag');

/** The `ETag` of the response whose envelope this is, or null when it carried none. */
export function etagOf(envelope: unknown): string | null {
  if (typeof envelope !== 'object' || envelope === null) return null;
  const value = (envelope as Record<symbol, unknown>)[RESPONSE_ETAG];
  return typeof value === 'string' && value !== '' ? value : null;
}

function withEtag<T>(body: T, etag: string | null): T {
  if (typeof body === 'object' && body !== null) {
    Object.defineProperty(body, RESPONSE_ETAG, { value: etag, configurable: true });
  }
  return body;
}

export class ApiError extends Error {
  override readonly name = 'ApiError';

  constructor(
    readonly code: string,
    readonly status: number | null,
    readonly meta: Readonly<Record<string, unknown>> = {},
  ) {
    // The code, never the server's message, so nothing can leak it into the UI.
    super(code);
  }
}

/** Orval types every hook's error with this. */
export type ErrorType<_Body> = ApiError;

const errorEnvelope = z.object({
  success: z.literal(false),
  error: z.object({ code: z.string(), message: z.string() }) satisfies z.ZodType<ErrorBody>,
  meta: z.record(z.string(), z.unknown()).default({}),
});

// Keyed by "<METHOD> <path>", with `{}` standing for a path parameter (`/admin/api/matches/{}`).
// A request without a schema here fails loudly instead of skipping validation.

// Orval emits no response schema for `POST /sources/{name}/run` (a 202 with a tiny body), so the
// envelope is spelled out here; it is the last hand-written entry.
const sourceRunQueuedResponse = z.object({
  success: z.literal(true),
  data: z.object({ queued: z.boolean() }).nullable(),
  error: z.literal(null),
  meta: z.record(z.string(), z.unknown()).default({}),
});

const responseSchemas: Readonly<Record<string, z.ZodTypeAny>> = {
  'POST /admin/api/auth/login': loginResponse,
  'POST /admin/api/auth/logout': logoutResponse,
  'POST /admin/api/auth/refresh': refreshResponse,
  'GET /admin/api/auth/me': meResponse,
  'GET /admin/api/healthz': healthEndpointResponse,
  'GET /admin/api/dashboard': getDashboardResponse,
  'GET /admin/api/broadcast-presets': listBroadcastPresetsResponse,
  'GET /admin/api/channels': listChannelsResponse,
  // Orval emits no response schema for a 201-only operation; a create answers with the same
  // `Envelope_Admin<Entity>_` body as the entity's PATCH (checked against the spec).
  'POST /admin/api/channels': patchChannelResponse,
  'GET /admin/api/channels/{}': getChannelResponse,
  'PATCH /admin/api/channels/{}': patchChannelResponse,
  'DELETE /admin/api/channels/{}': deleteChannelResponse,
  'GET /admin/api/commentators': listCommentatorsResponse,
  'POST /admin/api/commentators': patchCommentatorResponse,
  'GET /admin/api/commentators/{}': getCommentatorResponse,
  'PATCH /admin/api/commentators/{}': patchCommentatorResponse,
  'DELETE /admin/api/commentators/{}': deleteCommentatorResponse,
  'GET /admin/api/competitions': listCompetitionsResponse,
  'PUT /admin/api/competitions/order': orderCompetitionsResponse,
  'POST /admin/api/competitions': patchCompetitionResponse,
  'GET /admin/api/competitions/{}': getCompetitionResponse,
  'PATCH /admin/api/competitions/{}': patchCompetitionResponse,
  'DELETE /admin/api/competitions/{}': deleteCompetitionResponse,
  'GET /admin/api/hidden-channel-names': listHiddenChannelNamesResponse,
  'POST /admin/api/hidden-channel-names': addHiddenChannelNameResponse,
  'DELETE /admin/api/hidden-channel-names/{}': removeHiddenChannelNameResponse,
  'GET /admin/api/matches': listMatchesResponse,
  'POST /admin/api/matches': patchMatchResponse,
  'POST /admin/api/matches/bulk': bulkResponse,
  'GET /admin/api/matches/{}': getMatchResponse,
  'PATCH /admin/api/matches/{}': patchMatchResponse,
  'POST /admin/api/media': uploadMediaResponse,
  'GET /admin/api/satellites': listSatellitesResponse,
  'PUT /admin/api/satellites/order': orderSatellitesResponse,
  'POST /admin/api/satellites': patchSatelliteResponse,
  'GET /admin/api/satellites/{}': getSatelliteResponse,
  'PATCH /admin/api/satellites/{}': patchSatelliteResponse,
  'DELETE /admin/api/satellites/{}': deleteSatelliteResponse,
  'GET /admin/api/sources': listSourcesResponse,
  'POST /admin/api/sources/{}/run': sourceRunQueuedResponse,
  'POST /admin/api/sources/{}/pause': pauseSourceResponse,
  'POST /admin/api/sources/{}/resume': resumeSourceResponse,
  'GET /admin/api/sources/{}/runs': listSourceRunsResponse,
  'GET /admin/api/import-runs/{}': getImportRunResponse,
  'GET /admin/api/import-runs/{}/raw': getImportRunRawResponse,
  // D5's queue (A13): the list comes back as the same `UnresolvedNameRow` the two writes answer with.
  'GET /admin/api/unresolved-names': listNamesResponse,
  'POST /admin/api/unresolved-names/{}/map': mapNameResponse,
  'POST /admin/api/unresolved-names/{}/ignore': ignoreNameResponse,
  // D5's A9. A create answers `201` with the `Envelope<AdminRightsHolder>` body that PATCH returns.
  'GET /admin/api/rights-holders': listRightsHoldersResponse,
  'POST /admin/api/rights-holders': patchRightsHolderResponse,
  'POST /admin/api/rights-holders/reorder': reorderRightsHoldersResponse,
  'GET /admin/api/rights-holders/{}': getRightsHolderResponse,
  'PATCH /admin/api/rights-holders/{}': patchRightsHolderResponse,
  'DELETE /admin/api/rights-holders/{}': deleteRightsHolderResponse,
  'GET /admin/api/teams': listTeamsResponse,
  'POST /admin/api/teams': patchTeamResponse,
  'GET /admin/api/teams/{}': getTeamResponse,
  'PATCH /admin/api/teams/{}': patchTeamResponse,
  'DELETE /admin/api/teams/{}': deleteTeamResponse,
};

/** True when `url` matches a `<METHOD> <path>` key, with `{}` matching one path segment. */
function pathMatches(template: string, url: string): boolean {
  const expected = template.split('/');
  const actual = url.split('?')[0]?.split('/') ?? [];
  return expected.length === actual.length && expected.every((part, index) => part === '{}' || part === actual[index]);
}

function schemaFor(method: string, url: string): z.ZodTypeAny | undefined {
  for (const [key, schema] of Object.entries(responseSchemas)) {
    const space = key.indexOf(' ');
    if (key.slice(0, space) === method && pathMatches(key.slice(space + 1), url)) return schema;
  }
  return undefined;
}

export const http = axios.create({ withCredentials: true });

// --- Session (research R24, FR-034) -------------------------------------------------------------
// The access token lives in this module's memory only, never in storage or a JS-readable cookie.
// A `401 token_expired` triggers one shared refresh for every request waiting on it, then one retry;
// a refresh that fails drops the token and reports the session expired, which sends the editor to A1.

const CSRF_COOKIE = 'madar_csrf';
const CSRF_HEADER = 'X-CSRF-Token';
const REFRESH_URL = '/admin/api/auth/refresh';
const LOGOUT_URL = '/admin/api/auth/logout';
const MUTATING = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

let accessToken: string | null = null;
let refreshInFlight: Promise<Session> | null = null;
let handlers: { onRefreshed?: (session: Session) => void; onExpired?: () => void } = {};

/** Records the in-memory access token (`null` clears it). */
export function setAccessToken(token: string | null): void {
  accessToken = token;
}

export function getAccessToken(): string | null {
  return accessToken;
}

/** Lets the session provider follow a refresh done behind its back, and learn when it expired. */
export function bindSession(next: { onRefreshed?: (session: Session) => void; onExpired?: () => void }): void {
  handlers = next;
}

function csrfCookie(): string | null {
  const prefix = `${CSRF_COOKIE}=`;
  const part = document.cookie.split('; ').find((cookie) => cookie.startsWith(prefix));
  return part ? decodeURIComponent(part.slice(prefix.length)) : null;
}

function sessionHeaders(method: string): Record<string, string> {
  const headers: Record<string, string> = {};
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
  // Refresh and logout must echo the CSRF cookie of contracts/admin-auth-v1.md; so must every write.
  const csrf = MUTATING.has(method) ? csrfCookie() : null;
  if (csrf) headers[CSRF_HEADER] = csrf;
  return headers;
}

async function refreshOnce(): Promise<Session> {
  const csrf = csrfCookie();
  const response = await http
    .request<unknown>({
      method: 'POST',
      url: REFRESH_URL,
      headers: csrf ? { [CSRF_HEADER]: csrf } : {},
    })
    // A refusal is an `ApiError` with its status, so only a 401/403 ends the session (A-R1-19).
    .catch((error: unknown) => {
      throw toApiError(error);
    });
  const body = refreshResponse.safeParse(response.data);
  if (!body.success) throw new ApiError(INVALID_RESPONSE, response.status);
  const session = body.data.data as Session;
  accessToken = session.access_token;
  handlers.onRefreshed?.(session);
  return session;
}

/** One refresh at a time: every caller that arrived while it ran awaits the same promise. */
export function refreshSession(): Promise<Session> {
  refreshInFlight ??= refreshWithRetry()
    .catch((error: unknown) => {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      // Only a definitive refusal ends the session (A-R1-19): a blip during a refresh must not sign
      // the editor out of A4 and throw away unsaved work.
      if (failure.status === 401 || failure.status === 403) {
        accessToken = null;
        handlers.onExpired?.();
      }
      throw failure;
    })
    .finally(() => {
      refreshInFlight = null;
    });
  return refreshInFlight;
}

/** A refresh whose network failed is tried once more before the editor hears about it. */
async function refreshWithRetry(): Promise<Session> {
  const attempts = 2;
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await refreshOnce();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      if (failure.code === NETWORK_ERROR && attempt < attempts) continue;
      throw failure;
    }
  }
}

/** Ends the session server-side (it clears both cookies); the caller drops the in-memory one. */
export async function endSession(): Promise<void> {
  const csrf = csrfCookie();
  accessToken = null;
  await http.request({ method: 'POST', url: LOGOUT_URL, headers: csrf ? { [CSRF_HEADER]: csrf } : {} }).catch(() => undefined);
}

/**
 * Dev builds only: `?mock=<example>` asks Prism for that named example of the spec (research R15).
 * The example is looked up by the operation's template (`PATCH /admin/api/matches/{}`), because the
 * spec never declares a literal id, so a page on `/matches/48213` can still ask for `edit_conflict`.
 */
function mockPreferHeader(method: string, url: string): Record<string, string> {
  if (!import.meta.env.DEV) return {};
  const example = new URLSearchParams(window.location.search).get('mock');
  const operation = operationTemplate(method, url);
  const status = example && operation ? __MOCK_EXAMPLE_STATUSES__[operation]?.[example] : undefined;
  return example && status ? { Prefer: `code=${status}, example=${example}` } : {};
}

/** The `<METHOD> <path>` template of a request, with `{}` for each path parameter, if one is known. */
export function operationTemplate(method: string, url: string): string | undefined {
  for (const key of Object.keys(responseSchemas)) {
    const space = key.indexOf(' ');
    if (key.slice(0, space) === method && pathMatches(key.slice(space + 1), url)) return key;
  }
  return undefined;
}

function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;
  if (axios.isAxiosError(error)) {
    if (!error.response) return new ApiError(NETWORK_ERROR, null);
    const envelope = errorEnvelope.safeParse(error.response.data);
    return envelope.success
      ? new ApiError(envelope.data.error.code, error.response.status, envelope.data.meta)
      : new ApiError(INVALID_RESPONSE, error.response.status);
  }
  return new ApiError(INVALID_RESPONSE, null);
}

export async function adminHttp<T>(config: AxiosRequestConfig, options?: AxiosRequestConfig): Promise<T> {
  const method = (config.method ?? 'GET').toUpperCase();
  const url = config.url ?? '';
  const schema = schemaFor(method, url);
  if (!schema) {
    throw new Error(`adminHttp: no response schema for ${method} ${url}; add it to responseSchemas`);
  }

  return requestWithRetry<T>(config, options, method, url, schema, false);
}

async function requestWithRetry<T>(
  config: AxiosRequestConfig,
  options: AxiosRequestConfig | undefined,
  method: string,
  url: string,
  schema: z.ZodTypeAny,
  retried: boolean,
): Promise<T> {
  try {
    const response = await http.request<unknown>({
      ...config,
      ...options,
      headers: {
        ...mockPreferHeader(method, url),
        ...sessionHeaders(method),
        ...config.headers,
        ...options?.headers,
      },
    });
    const body = schema.safeParse(response.data);
    if (!body.success) throw new ApiError(INVALID_RESPONSE, response.status);
    const etag = response.headers.etag;
    // The schema was generated from the same operation as T, so the parsed body has T's shape.
    return withEtag(body.data as T, typeof etag === 'string' ? etag : null);
  } catch (error) {
    const apiError = toApiError(error);
    // An expired token is refreshed once, shared by every waiting request, then the call retries once.
    if (!retried && apiError.code === 'token_expired' && url !== REFRESH_URL) {
      try {
        await refreshSession();
      } catch (refreshError) {
        // A definitive refusal is reported as itself (`refresh_invalid`), not as the 401 that led here;
        // a blip keeps the original error and the session (A-R1-19).
        const failure = refreshError instanceof ApiError ? refreshError : apiError;
        throw failure.status === 401 || failure.status === 403 ? failure : apiError;
      }
      return requestWithRetry<T>(config, options, method, url, schema, true);
    }
    throw apiError;
  }
}
