import { clsx } from 'clsx';
import { useId, useMemo, useState, type KeyboardEvent, type ReactElement } from 'react';

import { useListTeams } from '../../api/generated/admin';
import type { TeamItem } from '../../api/generated/admin.schemas';
import { editor as copy } from '../../i18n/ar';

// A4's team picker: a combobox keyed by team id, or the name as text when the source's team is not in
// the database. Country, crest and competitions are on every option, so two teams with one name can be
// told apart — and choosing an option sets its id, never a name lookup (A-R1-6).
const OPTIONS_SHOWN = 5;

interface TeamPickerProps {
  label: string;
  /** `team_id` when the row is linked, null for free text. */
  teamId: number | null;
  name: string;
  onChange: (value: { teamId: number | null; name: string }) => void;
}

export function TeamPicker({ label, teamId, name, onChange }: TeamPickerProps): ReactElement {
  const inputId = useId();
  const listId = `${inputId}-list`;
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const { data } = useListTeams({ q: query.length >= 2 ? query : null, limit: 20 });
  const teams: readonly TeamItem[] = useMemo(() => data?.data ?? [], [data]);
  // The list shows five options, so the keyboard moves through those five and no further: Enter can
  // only pick a team the editor can see, and `aria-activedescendant` always names a rendered id (A-R2-8).
  const shown = teams.slice(0, OPTIONS_SHOWN);

  function type(value: string): void {
    setQuery(value);
    // Text that matches no option is the source's team name: free text, no id.
    onChange({ teamId: null, name: value });
    setActive(0); // a new query starts at its first option, never at a stale index (A-R2-8)
    setOpen(true);
  }

  function pick(team: TeamItem): void {
    onChange({ teamId: team.id, name: team.name });
    setQuery(team.name);
    setOpen(false);
  }

  /** Arrow keys, Enter and Escape work the list: a combobox that needs a mouse fails WCAG 2.1.1. */
  function onKeyDown(event: KeyboardEvent<HTMLInputElement>): void {
    if (event.key === 'Escape') {
      setOpen(false);
      return;
    }
    if (!open) {
      if (event.key === 'ArrowDown') {
        event.preventDefault();
        setOpen(true);
      }
      return;
    }
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setActive((current) => Math.min(current + 1, Math.max(shown.length - 1, 0)));
      return;
    }
    if (event.key === 'ArrowUp') {
      event.preventDefault();
      setActive((current) => Math.max(current - 1, 0));
      return;
    }
    if (event.key === 'Enter') {
      const team = shown[active];
      if (team) {
        event.preventDefault();
        pick(team);
      }
    }
  }

  return (
    <div className="relative flex min-w-0 flex-col gap-2">
      <label htmlFor={inputId} className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
        {label}
        {teamId === null && name !== '' ? <span className="text-micro text-postponed">{copy.freeText}</span> : null}
      </label>
      <div className="flex items-center gap-2 rounded-md bg-bg px-3 ring-1 ring-inset ring-divider-strong focus-within:ring-2 focus-within:ring-focus-ring">
        <input
          id={inputId}
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={open && shown[active] ? `${listId}-${shown[active].id}` : undefined}
          autoComplete="off"
          value={name}
          placeholder={copy.teamSearch}
          onChange={(event) => type(event.target.value)}
          onFocus={() => setOpen(true)}
          onBlur={() => setOpen(false)}
          onKeyDown={onKeyDown}
          className="text-body h-12 min-w-0 flex-1 bg-transparent text-text-primary outline-none placeholder:text-text-tertiary"
        />
      </div>

      {open && shown.length > 0 ? (
        <ul
          id={listId}
          role="listbox"
          className="absolute inset-x-0 top-full z-10 mt-1 overflow-y-auto rounded-md bg-surface-1 py-1 ring-1 ring-inset ring-divider"
        >
          {shown.map((team, index) => (
            <li
              key={team.id}
              id={`${listId}-${team.id}`}
              role="option"
              aria-selected={team.id === teamId}
              onMouseEnter={() => setActive(index)}
              // `mousedown` keeps focus in the input, so the click lands before the list closes.
              onMouseDown={(event) => {
                event.preventDefault();
                pick(team);
              }}
              className={clsx(
                'flex cursor-pointer items-center gap-2 px-3 py-2',
                index === active ? 'bg-surface-2' : 'hover:bg-surface-2',
              )}
            >
              {team.logo ? (
                <img src={team.logo} alt="" width={24} height={24} className="size-6 rounded-pill bg-surface-2 object-contain" />
              ) : (
                <span
                  aria-hidden="true"
                  className="text-micro flex size-6 flex-none items-center justify-center rounded-pill bg-surface-2 font-mono text-text-secondary"
                >
                  {team.name.slice(0, 1)}
                </span>
              )}
              <bdi className="text-label text-text-primary">{team.name}</bdi>
              <span className="text-micro min-w-0 truncate text-text-tertiary">
                {[team.country, ...team.competitions.map((competition) => competition.name)].filter(Boolean).join(' · ')}
              </span>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
