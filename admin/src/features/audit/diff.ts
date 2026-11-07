import type { ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';

// An audit entry's `diff` exactly as stored, turned into the pairs `DiffView` shows (contract A17).
// New rows store `{"field": [old, new]}`; older shapes exist — `{"password": "changed"}` among them —
// and are shown raw on both sides rather than dropped or thrown on (FR-045, A-R2-7).

function raw(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

/** True for the `[old, new]` pair every field of a modern audit row holds. */
function isPair(value: unknown): value is [unknown, unknown] {
  return Array.isArray(value) && value.length === 2;
}

export function diffChanges(diff: Readonly<Record<string, unknown>>): ConflictChange[] {
  return Object.entries(diff).map(([field, value]) =>
    isPair(value)
      ? { field, label: field, before: raw(value[0]), after: raw(value[1]) }
      : { field, label: field, before: raw(value), after: raw(value) },
  );
}
