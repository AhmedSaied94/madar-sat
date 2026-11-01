import type { ConflictChange } from '../components/ConfirmDialog/ConflictDialog';

// The shared part of every record editor's `409 edit_conflict` flow: which visible fields differ, and
// who saved first. Nothing here re-sends a save; the editor decides what to adopt.

export interface ConflictField<Draft> {
  /** The API field name, printed as the diff's mono key. */
  key: keyof Draft & string;
  label: string;
  /** The field as the editor shows it; `null` when the field is empty. */
  text: (draft: Draft) => string | null;
}

export function diffDrafts<Draft>(
  fields: readonly ConflictField<Draft>[],
  before: Draft,
  after: Draft,
): ConflictChange[] {
  return fields.flatMap(({ key, label, text }) => {
    const from = text(before);
    const to = text(after);
    return from === to ? [] : [{ field: key, label, before: from, after: to }];
  });
}

/** `meta.changed_by` / `meta.changed_at` as the conflict dialog shows them; unknown values stay empty. */
export function conflictParty(meta: Readonly<Record<string, unknown>>): {
  kind: 'admin' | 'source';
  name: string;
  at: string;
} {
  const changedBy = meta['changed_by'];
  const party = typeof changedBy === 'object' && changedBy !== null ? (changedBy as Record<string, unknown>) : {};
  const at = meta['changed_at'];
  return {
    kind: party['kind'] === 'source' ? 'source' : 'admin',
    name: typeof party['name'] === 'string' ? party['name'] : '',
    at: typeof at === 'string' ? at : '',
  };
}
