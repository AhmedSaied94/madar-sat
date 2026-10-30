import { useId, useState, type ReactElement } from 'react';

import { useListTeams } from '../../api/generated/admin';
import type { TeamItem } from '../../api/generated/admin.schemas';
import { editor as copy } from '../../i18n/ar';

// A4's team picker: a team by id, or the name as text when the source's team is not in the database.
// Country, crest and competitions are on every option, so two teams with one name can be told apart.
interface TeamPickerProps {
  label: string;
  /** `team_id` when the row is linked, null for free text. */
  teamId: number | null;
  name: string;
  onChange: (value: { teamId: number | null; name: string }) => void;
}

export function TeamPicker({ label, teamId, name, onChange }: TeamPickerProps): ReactElement {
  const listId = useId();
  const [query, setQuery] = useState('');
  const { data } = useListTeams({ q: query.length >= 2 ? query : null, limit: 20 });
  const teams: readonly TeamItem[] = data?.data ?? [];

  function choose(value: string): void {
    const team = teams.find((candidate) => candidate.name === value);
    onChange(team ? { teamId: team.id, name: team.name } : { teamId: null, name: value });
  }

  return (
    <div className="flex min-w-0 flex-col gap-2">
      <label htmlFor={listId} className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
        {label}
        {teamId === null ? <span className="text-micro text-postponed">{copy.freeText}</span> : null}
      </label>
      <div className="flex items-center gap-2 rounded-md bg-bg px-3 ring-1 ring-inset ring-divider-strong focus-within:ring-2 focus-within:ring-focus-ring">
        {teamId !== null && name ? (
          <span
            aria-hidden="true"
            className="text-micro flex size-6 flex-none items-center justify-center rounded-pill bg-surface-2 font-mono text-text-secondary"
          >
            {name.slice(0, 1)}
          </span>
        ) : null}
        <input
          id={listId}
          list={`${listId}-options`}
          value={name}
          placeholder={copy.teamSearch}
          onChange={(event) => {
            setQuery(event.target.value);
            choose(event.target.value);
          }}
          className="text-body h-12 min-w-0 flex-1 bg-transparent text-text-primary outline-none placeholder:text-text-tertiary"
        />
        <datalist id={`${listId}-options`}>
          {teams.map((team) => (
            <option key={team.id} value={team.name}>
              {[team.country, ...team.competitions.map((competition) => competition.name)].filter(Boolean).join(' · ')}
            </option>
          ))}
        </datalist>
      </div>
    </div>
  );
}
