import type { ReactElement } from 'react';

import { editor as copy } from '../../../i18n/ar';
import type { EditorBroadcast } from '../MatchEditor';

// A4's "البث اليدوي": two broadcaster slots beside the channel links. An empty label clears the slot.
interface BroadcastSlotsProps {
  broadcasts: readonly EditorBroadcast[];
  commentators: readonly { id: number; name: string }[];
  onChange: (next: EditorBroadcast[]) => void;
}

export function BroadcastSlots({ broadcasts, commentators, onChange }: BroadcastSlotsProps): ReactElement {
  const at = (slot: 1 | 2): EditorBroadcast =>
    broadcasts.find((broadcast) => broadcast.slot === slot) ?? { slot, label: '', commentatorId: null };

  function update(slot: 1 | 2, patch: Partial<EditorBroadcast>): void {
    const current = at(slot);
    const next = { ...current, ...patch };
    const others = broadcasts.filter((broadcast) => broadcast.slot !== slot);
    onChange([...others, next].sort((a, b) => a.slot - b.slot));
  }

  return (
    <section aria-label={copy.manualBroadcast} className="flex flex-col gap-4 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <h2 className="text-label font-semibold text-text-primary">{copy.manualBroadcast}</h2>

      {([1, 2] as const).map((slot) => {
        const broadcast = at(slot);
        const labelId = `broadcast-${slot}`;
        return (
          <div key={slot} className="flex flex-wrap items-end gap-3">
            <label htmlFor={labelId} className="flex min-w-0 flex-1 flex-col gap-2">
              <span className="text-caption font-semibold text-text-secondary">
                {slot === 1 ? copy.slot1 : copy.slot2}
              </span>
              <input
                id={labelId}
                type="text"
                dir="ltr"
                placeholder={copy.pickFromList}
                value={broadcast.label}
                onChange={(event) => update(slot, { label: event.target.value })}
                className="text-body h-12 min-w-0 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
              />
            </label>

            <label className="flex min-w-0 flex-col gap-2">
              <span className="text-caption font-semibold text-text-secondary">{copy.commentator(slot)}</span>
              <select
                aria-label={`${copy.manualBroadcast} ${copy.commentator(slot)}`}
                value={broadcast.commentatorId ?? ''}
                onChange={(event) =>
                  update(slot, { commentatorId: event.target.value === '' ? null : Number(event.target.value) })
                }
                className="text-body h-12 min-w-0 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
              >
                <option value="">{copy.none}</option>
                {commentators.map((person) => (
                  <option key={person.id} value={person.id}>
                    {person.name}
                  </option>
                ))}
              </select>
            </label>
          </div>
        );
      })}
    </section>
  );
}
