import { setupServer } from 'msw/node';

// One MSW server for the whole run. Tests add their handlers with `server.use(...)`.
export const server = setupServer();
