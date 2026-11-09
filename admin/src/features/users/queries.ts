import { useListUsers } from '../../api/generated/admin';

// A16's read: the account list. It is small, so the endpoint has no cursor (contract admin-api).

export function useAdmins() {
  return useListUsers();
}
