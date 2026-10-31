import { clsx } from 'clsx';
import type { ReactElement } from 'react';

import { formatUtcTime, cairoWallTimeToUtc } from '../../../lib/cairoTime';
import { Field } from '../../../components/Field/Field';
import { Icon } from '../../../components/Icon/Icon';
import { TeamPicker } from '../TeamPicker';
import { editor as copy } from '../../../i18n/ar';
import type { EditorState } from '../MatchEditor';

// A4's "الفريقان والموعد": both teams, the Cairo kickoff and the competition. A locked field says so,
// because an importer will not change it — the editor still can (data-model, locked_fields).
// Every input is the shared `Field`, so focus, error, locked and disabled look the same as the rest
// of the admin (A-R1-10).
interface EditorSectionsProps {
  state: EditorState;
  competitions: readonly { id: number; name: string }[];
  lockedFields: readonly string[];
  onChange: (next: Partial<EditorState>) => void;
}

export function EditorSections({ state, competitions, lockedFields, onChange }: EditorSectionsProps): ReactElement {
  const utc = state.date !== '' && state.time !== '' ? cairoWallTimeToUtc(`${state.date}T${state.time}`) : null;
  const locked = (field: string): boolean => lockedFields.includes(field);

  return (
    <section aria-label={copy.teamsAndTime} className="flex flex-col gap-4 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <h2 className="text-label font-semibold text-text-primary">{copy.teamsAndTime}</h2>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <TeamPicker
          label={copy.homeTeam}
          teamId={state.home.teamId}
          name={state.home.name}
          onChange={(value) => onChange({ home: value })}
        />
        <TeamPicker
          label={copy.awayTeam}
          teamId={state.away.teamId}
          name={state.away.name}
          onChange={(value) => onChange({ away: value })}
        />
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <Field
            label={copy.date}
            type="date"
            locked={locked('match_date')}
            // A time to be confirmed still has a day, and the day stays editable: only the clock is
            // unknown (A-R1-4).
            value={state.date}
            onChange={(event) => onChange({ date: event.target.value })}
          />
        </div>

        <div className="min-w-0">
          <Field
            label={`${copy.time} ${copy.cairoNote}`}
            type="time"
            ltr
            locked={locked('kickoff_at')}
            value={state.time}
            disabled={state.timeTbd}
            onChange={(event) => onChange({ time: event.target.value })}
          />
        </div>

        <p className="text-caption text-text-tertiary">
          {copy.cairoNote}
          {utc ? ` · ${copy.savedAs(formatUtcTime(utc))}` : null}
        </p>

        <label className="text-label flex items-center gap-2 text-text-secondary">
          <input
            type="checkbox"
            checked={state.timeTbd}
            onChange={(event) => onChange({ timeTbd: event.target.checked })}
            className="size-4 accent-accent"
          />
          {copy.timeTbd}
        </label>
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <label className="flex min-w-0 flex-1 flex-col gap-2">
          <span className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
            {copy.competition}
            {locked('competition_id') ? (
              <span className="inline-flex text-postponed">
                <Icon name="lock" size="sm" label={copy.lockedHint} />
              </span>
            ) : null}
          </span>
          <select
            aria-label={copy.competition}
            data-state={locked('competition_id') ? 'locked' : 'default'}
            value={state.competitionId}
            onChange={(event) => onChange({ competitionId: event.target.value })}
            className={clsx(
              'text-body h-12 rounded-md px-3 ring-1 ring-inset',
              locked('competition_id') ? 'bg-postponed-container ring-postponed' : 'bg-bg ring-divider-strong',
              'text-text-primary',
            )}
          >
            <option value="">—</option>
            {competitions.map((competition) => (
              <option key={competition.id} value={competition.id}>
                {competition.name}
              </option>
            ))}
          </select>
        </label>

        <div className="flex min-w-0 flex-1 flex-col">
          <Field
            label={copy.stage}
            locked={locked('competition_stage')}
            value={state.stage}
            onChange={(event) => onChange({ stage: event.target.value })}
          />
        </div>

        <div className="flex min-w-0 flex-1 flex-col">
          <Field
            label={copy.stadium}
            locked={locked('stadium')}
            value={state.stadium}
            onChange={(event) => onChange({ stadium: event.target.value })}
          />
        </div>
      </div>
    </section>
  );
}
