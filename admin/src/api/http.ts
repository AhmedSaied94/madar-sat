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
  deleteSatelliteResponse,
  deleteTeamResponse,
  getChannelResponse,
  getCommentatorResponse,
  getCompetitionResponse,
  getMatchResponse,
  getSatelliteResponse,
  getTeamResponse,
  healthEndpointResponse,
  listBroadcastPresetsResponse,
  listChannelsResponse,
  listCommentatorsResponse,
  listCompetitionsResponse,
  listHiddenChannelNamesResponse,
  listMatchesResponse,
  listSatellitesResponse,
  listSourcesResponse,
  listTeamsResponse,
  loginResponse,
  logoutResponse,
  meResponse,
  patchChannelResponse,
  patchCommentatorResponse,
  patchCompetitionResponse,
  patchMatchResponse,
  patchSatelliteResponse,
  patchTeamResponse,
  refreshResponse,
  removeHiddenChannelNameResponse,
  uploadMediaResponse,
} from './generated/admin.zod';

export const NETWORK_ERROR = 'network_error';
export const INVALID_RESPONSE = 'invalid_response';

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
const responseSchemas: Readonly<Record<string, z.ZodTypeAny>> = {
  'POST /admin/api/auth/login': loginResponse,
  'POST /admin/api/auth/logout': logoutResponse,
  'POST /admin/api/auth/refresh': refreshResponse,
  'GET /admin/api/auth/me': meResponse,
  'GET /admin/api/healthz': healthEndpointResponse,
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
  'POST /admin/api/satellites': patchSatelliteResponse,
  'GET /admin/api/satellites/{}': getSatelliteResponse,
  'PATCH /admin/api/satellites/{}': patchSatelliteResponse,
  'DELETE /admin/api/satellites/{}': deleteSatelliteResponse,
  'GET /admin/api/sources': listSourcesResponse,
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
  const response = await http.request<unknown>({
    method: 'POST',
    url: REFRESH_URL,
    headers: csrf ? { [CSRF_HEADER]: csrf } : {},
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
  refreshInFlight ??= refreshOnce()
    .catch((error: unknown) => {
      accessToken = null;
      handlers.onExpired?.();
      throw error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
    })
    .finally(() => {
      refreshInFlight = null;
    });
  return refreshInFlight;
}

/** Ends the session server-side (it clears both cookies); the caller drops the in-memory one. */
export async function endSession(): Promise<void> {
  const csrf = csrfCookie();
  accessToken = null;
  await http.request({ method: 'POST', url: LOGOUT_URL, headers: csrf ? { [CSRF_HEADER]: csrf } : {} }).catch(() => undefined);
}

/**
 * An entity's `ETag` from a `GET` (contract: single-entity reads carry it). A3 has no per-row version
 * in the list, so a bulk action reads each selected match's version before sending `If-Match` items.
 */
export async function getEntityEtag(url: string): Promise<string> {
  const response = await http.get<unknown>(url).catch((error: unknown) => {
    throw toApiError(error);
  });
  const etag = response.headers.etag;
  if (typeof etag !== 'string' || etag === '') throw new ApiError(INVALID_RESPONSE, response.status);
  return etag;
}

/**
 * Dev builds only: `?mock=<example>` asks Prism for that named example of the spec (research R15).
 * Only operations that declare the example get the header; Prism also needs the example's status.
 */
function mockPreferHeader(method: string, url: string): Record<string, string> {
  if (!import.meta.env.DEV) return {};
  const example = new URLSearchParams(window.location.search).get('mock');
  const operation = `${method} ${url}`;
  const status = example ? __MOCK_EXAMPLE_STATUSES__[operation]?.[example] : undefined;
  return example && status ? { Prefer: `code=${status}, example=${example}` } : {};
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
    // The schema was generated from the same operation as T, so the parsed body has T's shape.
    return body.data as T;
  } catch (error) {
    const apiError = toApiError(error);
    // An expired token is refreshed once, shared by every waiting request, then the call retries once.
    if (!retried && apiError.code === 'token_expired' && url !== REFRESH_URL) {
      try {
        await refreshSession();
      } catch {
        throw apiError;
      }
      return requestWithRetry<T>(config, options, method, url, schema, true);
    }
    throw apiError;
  }
}
