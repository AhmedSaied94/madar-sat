// The axios mutator behind the Orval client (src/api/generated). This file is hand-written; the rest is generated.
//
// - Same origin: the admin spec's paths already start with /admin/api, and the admin app is served
//   from the same wg0 host (Vite proxies /admin/api to Prism in dev).
// - Cookies travel with every call (the refresh and CSRF cookies of contracts/admin-auth-v1.md).
// - Every response body is parsed with the Zod schema Orval generated for its operation.
// - Failures become an ApiError carrying the envelope's error.code and meta; error.message is dropped.
import axios, { type AxiosRequestConfig } from 'axios';
import { z } from 'zod';

import type { ErrorBody } from './generated/admin.schemas';
import { healthEndpointResponse, loginResponse, logoutResponse, meResponse, refreshResponse } from './generated/admin.zod';

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

// Keyed by "<METHOD> <path>". A request without a schema here fails loudly instead of skipping validation.
const responseSchemas: Readonly<Record<string, z.ZodTypeAny>> = {
  'POST /admin/api/auth/login': loginResponse,
  'POST /admin/api/auth/logout': logoutResponse,
  'POST /admin/api/auth/refresh': refreshResponse,
  'GET /admin/api/auth/me': meResponse,
  'GET /admin/api/healthz': healthEndpointResponse,
};

export const http = axios.create({ withCredentials: true });

/**
 * Dev builds only: `?mock=<example>` asks Prism for that named example of the spec (research R15).
 * Only operations that declare the example get the header; Prism also needs the example's status.
 */
function mockPreferHeader(operation: string): Record<string, string> {
  if (!import.meta.env.DEV) return {};
  const example = new URLSearchParams(window.location.search).get('mock');
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
  const operation = `${(config.method ?? 'GET').toUpperCase()} ${config.url ?? ''}`;
  const schema = responseSchemas[operation];
  if (!schema) {
    throw new Error(`adminHttp: no response schema for ${operation}; add it to responseSchemas`);
  }

  try {
    const response = await http.request<unknown>({
      ...config,
      ...options,
      headers: { ...mockPreferHeader(operation), ...config.headers, ...options?.headers },
    });
    const body = schema.safeParse(response.data);
    if (!body.success) throw new ApiError(INVALID_RESPONSE, response.status);
    // The schema was generated from the same operation as T, so the parsed body has T's shape.
    return body.data as T;
  } catch (error) {
    throw toApiError(error);
  }
}
