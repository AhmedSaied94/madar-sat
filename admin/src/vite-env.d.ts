/// <reference types="vite/client" />

/** Dev server only (vite.config.ts): the status of each named example, per "<METHOD> <path>". Empty in builds. */
declare const __MOCK_EXAMPLE_STATUSES__: Readonly<Record<string, Readonly<Record<string, number>>>>;
