import { useId, useMemo, type ReactElement } from 'react';

import { useListBroadcastPresets } from '../../../api/generated/admin';
import { editor as copy } from '../../../i18n/ar';
import type { EditorBroadcast } from '../MatchEditor';

// A4's "البث اليدوي": two broadcaster slots beside the channel links. Each slot offers the broadcast
// presets, and choosing one carries its logo asset, so a later edit never clears it (A-R1-8). An empty
// label clears the slot.
interface BroadcastSlotsProps {
  broadcasts: readonly EditorBroadcast[];
  commentators: readonly { id: number; name: string }[];
  onChange: (next: EditorBroadcast[]) => void;
}

export function BroadcastSlots({ broadcasts, commentators, onChange }: BroadcastSlotsProps): ReactElement {
  const listId = useId();
  const { data } = useListBroadcastPresets();
  const presets = useMemo(() => data?.data ?? [], [data]);

  const at = (slot: 1 | 2): EditorBroadcast =>
    broadcasts.find((broadcast) => broadcast.slot === slot) ?? {
      slot,
      label: '',
      logoAssetId: null,
      commentatorId: null,
    };

  function update(slot: 1 | 2, patch: Partial<EditorBroadcast>): void {
    const current = at(slot);
    const next = { ...current, ...patch };
    const others = broadcasts.filter((broadcast) => broadcast.slot !== slot);
    onChange([...others, next].sort((a, b) => a.slot - b.slot));
  }

  /** A preset's name is the label; its logo travels with the slot, so the API keeps it. Typing a label
   *  keeps the slot's existing logo instead of silently clearing it (A-R1-8). */
  function choosePreset(slot: 1 | 2, value: string): void {
    const preset = presets.find((candidate) => candidate.name === value);
    if (preset) {
      update(slot, { label: preset.name, logoAssetId: preset.id });
      return;
    }
    update(slot, { label: value, logoAssetId: value === '' ? null : at(slot).logoAssetId });
  }

  return (
    <section aria-label={copy.manualBroadcast} className="flex flex-col gap-4 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <h2 className="text-label font-semibold text-text-primary">{copy.manualBroadcast}</h2>

      <datalist id={`${listId}-presets`}>
        {presets.map((preset) => (
          <option key={preset.id} value={preset.name} />
        ))}
      </datalist>

      {([1, 2] as const).map((slot) => {
        const broadcast = at(slot);
        const labelId = `${listId}-broadcast-${slot}`;
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
                list={`${listId}-presets`}
                placeholder={copy.pickFromList}
                value={broadcast.label}
                onChange={(event) => choosePreset(slot, event.target.value)}
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
