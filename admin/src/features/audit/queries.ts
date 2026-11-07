import { useGetAuditEntry, useListAuditEntries } from '../../api/generated/admin';
import type { ListAuditEntriesParams } from '../../api/generated/admin.schemas';

// A17's reads: the log with its cursor, and one entry's `diff` and linked outbox row.

export function useAuditLog(params: ListAuditEntriesParams, enabled = true) {
  return useListAuditEntries(params, { query: { enabled } });
}

export function useAuditEntry(id: number | null) {
  return useGetAuditEntry(id ?? 0, { query: { enabled: id !== null, structuralSharing: false } });
}
