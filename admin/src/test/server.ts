import { setupServer } from 'msw/node';

import { getMadarSatAdminAPIMock } from '../api/generated/admin.msw';

// One MSW server for the whole run: the Orval handlers answer every operation of the admin spec with
// its first named example, and a test overrides the operation it exercises with `server.use(...)`.
export const server = setupServer(...getMadarSatAdminAPIMock());
