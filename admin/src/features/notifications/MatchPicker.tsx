import { clsx } from 'clsx';
import { useMemo, useState, type ReactElement } from 'react';

import { useListMatches } from '../../api/generated/admin';
import type { AdminMatchRow } from '../../api/generated/admin.schemas';
import { Button } from '../../components/Button/Button';
import { Field } from '../../components/Field/Field';
import { Select } from '../../components/FormControls/FormControls';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { cairoDay, cairoDayBounds, formatCairoTime } from '../../lib/cairoTime';
import { common, copyForErrorCode, notifications as copy } from '../../i18n/ar';

// A15's match picker (contract admin-screens "Composer"): the composer needs two of them — one for the
// audience «متابعو هذه المباراة» and one for the deep link «يفتح» — so it is built once. Inline mode
// draws the list straight away (an audience is a choice, not a search); with a `trigger` it opens on
// the button, because the deep link is optional.
//
// A-R1-6: the list is scoped to one Cairo day (today first) or the list's whole window, every match of
// it is shown and searchable by team or competition, the pick is marked, and loading, empty and error
// each say what they are.

export interface PickedMatch {
  id: number;
  label: string;
  route: string;
}

interface MatchPickerProps {
  /** Shown as the button that opens the list. Left out for the inline audience picker. */
  trigger?: string;
  /** The match already picked, marked in the list. */
  selectedId?: number | null;
  onPick: (match: PickedMatch) => void;
}

const ALL_DAYS = 'all';
/** The list's window: yesterday and the six days after today, eight days (contract admin-api). */
const FIRST_OFFSET = -1;
const LAST_OFFSET = 6;
const LAST = '￿';

/** `YYYY-MM-DD`, `offset` calendar days from `day`. */
function shiftDay(day: string, offset: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) + offset * 86_400_000).toISOString().slice(0, 10);
}

function dayLabel(offset: number, day: string): string {
  if (offset === -1) return copy.composer.days.yesterday;
  if (offset === 0) return copy.composer.days.today;
  if (offset === 1) return copy.composer.days.tomorrow;
  return day;
}

const labelOf = (match: AdminMatchRow): string => `${match.home.name} × ${match.away.name}`;

export function MatchPicker({ trigger, selectedId = null, onPick }: MatchPickerProps): ReactElement {
  const [open, setOpen] = useState(trigger === undefined);
  const [query, setQuery] = useState('');
  // Today's Cairo day, fixed for the picker's life so the query key doesn't move under it.
  const today = useMemo(() => cairoDay(new Date().toISOString()), []);
  const [day, setDay] = useState(today);

  const dayOptions = useMemo(() => {
    const days: { value: string; label: string }[] = [];
    for (let offset = FIRST_OFFSET; offset <= LAST_OFFSET; offset += 1) {
      const value = shiftDay(today, offset);
      days.push({ value, label: dayLabel(offset, value) });
    }
    return [...days, { value: ALL_DAYS, label: copy.composer.days.all }];
  }, [today]);

  // Instants of Cairo midnights, as the list requires (admin-api; the bug fixed in 8773167).
  const range = useMemo(
    () =>
      day === ALL_DAYS
        ? {
            from: cairoDayBounds(shiftDay(today, FIRST_OFFSET)).from,
            to: cairoDayBounds(shiftDay(today, LAST_OFFSET)).to,
          }
        : cairoDayBounds(day),
    [day, today],
  );
  const list = useListMatches(range, { query: { enabled: open } });

  const all = list.data?.data;
  const matches = useMemo(() => {
    const needle = query.trim();
    const rows = [...(all ?? [])].sort((a, b) => (a.kickoff_at ?? LAST).localeCompare(b.kickoff_at ?? LAST));
    if (needle === '') return rows;
    return rows.filter((row) => [row.home.name, row.away.name, row.competition.name].some((name) => name.includes(needle)));
  }, [all, query]);
  const total = all?.length ?? 0;

  function pick(match: AdminMatchRow): void {
    onPick({ id: match.id, label: labelOf(match), route: `/match/${match.id}` });
    if (trigger !== undefined) setOpen(false);
  }

  return (
    <div className="flex min-w-0 flex-col gap-2">
      {trigger === undefined ? null : (
        <button
          type="button"
          aria-expanded={open}
          onClick={() => setOpen((current) => !current)}
          className={clsx(
            'text-label inline-flex h-8 items-center gap-2 self-start rounded-md bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3',
            focusRing,
          )}
        >
          <Icon name="ball" size="sm" />
          {trigger}
        </button>
      )}

      {open ? (
        <>
          <div className="flex flex-wrap items-end gap-2">
            <div className="min-w-0 flex-1">
              <Field
                label={copy.composer.searchMatch}
                type="search"
                value={query}
                leading={<Icon name="search" size="sm" />}
                onChange={(event) => setQuery(event.target.value)}
              />
            </div>
            <Select label={copy.composer.matchDay} value={day} options={dayOptions} onChange={setDay} />
          </div>

          {list.isPending ? (
            <p role="status" className="text-caption py-2 text-text-tertiary">
              {copy.composer.matchesLoading}
            </p>
          ) : list.isError ? (
            <div role="alert" className="flex flex-wrap items-center gap-2 py-2">
              <span className="text-caption min-w-0 flex-1 text-error">{copyForErrorCode(list.error?.code ?? '')}</span>
              <Button size="xs" variant="outline" onClick={() => void list.refetch()}>
                {common.retry}
              </Button>
            </div>
          ) : (
            <ul aria-label={copy.composer.chooseMatch} className="flex flex-col divide-y divide-divider">
              {matches.length === 0 ? (
                <li className="text-caption py-2 text-text-tertiary">
                  {total === 0 ? copy.composer.noMatchesDay : copy.composer.noMatchesSearch}
                </li>
              ) : (
                matches.map((match) => (
                  <MatchOption key={match.id} match={match} selected={match.id === selectedId} onPick={pick} />
                ))
              )}
            </ul>
          )}
        </>
      ) : null}
    </div>
  );
}

function MatchOption({
  match,
  selected,
  onPick,
}: {
  match: AdminMatchRow;
  selected: boolean;
  onPick: (match: AdminMatchRow) => void;
}): ReactElement {
  const when =
    match.kickoff_at === null || match.time_tbd ? match.match_date : `${match.match_date} ${formatCairoTime(match.kickoff_at)}`;
  return (
    <li>
      <button
        type="button"
        aria-pressed={selected}
        onClick={() => onPick(match)}
        className={clsx(
          'text-label flex w-full items-center gap-2 rounded-md p-2 text-start text-text-primary',
          selected ? 'bg-surface-2 font-semibold ring-1 ring-inset ring-divider-strong' : 'hover:bg-surface-2',
          focusRing,
        )}
      >
        {selected ? <Icon name="check" size="sm" /> : null}
        <bdi className="min-w-0 flex-1 truncate">{labelOf(match)}</bdi>
        <bdi className="text-micro truncate text-text-tertiary">{match.competition.name}</bdi>
        <bdi dir="ltr" className="text-micro font-mono tabular-nums text-text-tertiary">
          {when}
        </bdi>
      </button>
    </li>
  );
}
