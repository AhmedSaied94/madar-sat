import { defineConfig } from 'orval';

// The admin client is generated from Lane B1's contract and never edited by hand (FR-031).
// operationIds look like `login_admin_api_auth_login_post`; the part before `_admin_api_`
// names the hooks and schemas (`useLogin`, `loginResponse`).
const ADMIN_SPEC = '../backend/openapi/admin.json';

const operationName = (operation: { operationId?: string }, route: string, verb: string): string => {
  const base = operation.operationId?.split('_admin_api_')[0] ?? `${verb}_${route}`;
  return base.replace(/[_-]+([a-z0-9])/g, (_, letter: string) => letter.toUpperCase());
};

export default defineConfig({
  admin: {
    input: { target: ADMIN_SPEC },
    output: {
      target: 'src/api/generated/admin.ts',
      mode: 'split',
      client: 'react-query',
      httpClient: 'axios',
      clean: false,
      prettier: false,
      // MSW handlers for Vitest, built from the spec's named examples, one per declared status.
      // Orval writes them next to the client (src/api/generated/admin.msw.ts): it has no separate mock path.
      mock: { type: 'msw', useExamples: true, generateEachHttpStatus: true, delay: false },
      override: {
        operationName,
        mutator: { path: 'src/api/http.ts', name: 'adminHttp' },
        query: { useQuery: true, useMutation: true, signal: true },
      },
    },
  },
  adminZod: {
    input: { target: ADMIN_SPEC },
    output: {
      target: 'src/api/generated/admin.zod.ts',
      mode: 'single',
      client: 'zod',
      prettier: false,
      override: {
        operationName,
        zod: { generate: { param: true, query: true, header: true, body: true, response: true } },
      },
    },
  },
});
