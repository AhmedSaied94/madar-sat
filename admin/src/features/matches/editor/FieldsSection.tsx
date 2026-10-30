import type { ReactElement } from 'react';

import { Icon } from '../../../components/Icon/Icon';
import { TeamPicker } from '../TeamPicker';
import { cairoWallTimeToUtc, formatCairoTime } from '../../../lib/cairoTime';
import { editor as copy } from '../../../i18n/ar';
import type { EditorState } from '../MatchEditor';

// A4's "الفريقان والموعد": both teams, the Cairo kickoff and the competition. A locked field says so,
// because an importer will not change it — the editor still can (data-model, locked_fields).
interface EditorSectionsProps {
  state: EditorState;
  competitions: readonly { id: number; name: string }[];
  lockedFields: readonly string[];
  onChange: (next: Partial<EditorState>) => void;
}

function LockBadge({ locked }: { locked: boolean }): ReactElement | null {
  return locked ? (
    <span className="ms-auto inline-flex text-postponed" title={copy.lockedHint}>
      <Icon name="lock" size="sm" label={copy.lockedHint} />
    </span>
  ) : null;
}

export function EditorSections({ state, competitions, lockedFields, onChange }: EditorSectionsProps): ReactElement {
  const utc = state.date !== '' && state.time !== '' ? cairoWallTimeToUtc(`${state.date}T${state.time}`) : null;

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
        <label className="flex flex-col gap-2">
          <span className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
            {copy.date}
            <LockBadge locked={lockedFields.includes('match_date')} />
          </span>
          <input
            type="date"
            value={state.date}
            disabled={state.timeTbd}
            onChange={(event) => onChange({ date: event.target.value })}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          />
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
            {copy.time}
            <LockBadge locked={lockedFields.includes('kickoff_at')} />
          </span>
          <input
            type="time"
            aria-label={`${copy.time} ${copy.cairoNote}`}
            value={state.time}
            disabled={state.timeTbd}
            onChange={(event) => onChange({ time: event.target.value })}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          />
        </label>

        <p className="text-caption text-text-tertiary">
          {copy.cairoNote}
          {utc ? ` · ${copy.savedAs(formatCairoTime(utc))}` : null}
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
            <LockBadge locked={lockedFields.includes('competition_id')} />
          </span>
          <select
            aria-label={copy.competition}
            value={state.competitionId}
            onChange={(event) => onChange({ competitionId: event.target.value })}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          >
            <option value="">—</option>
            {competitions.map((competition) => (
              <option key={competition.id} value={competition.id}>
                {competition.name}
              </option>
            ))}
          </select>
        </label>

        <label className="flex min-w-0 flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.stage}</span>
          <input
            type="text"
            value={state.stage}
            onChange={(event) => onChange({ stage: event.target.value })}
            className="text-body h-12 min-w-0 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          />
        </label>

        <label className="flex min-w-0 flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.stadium}</span>
          <input
            type="text"
            value={state.stadium}
            onChange={(event) => onChange({ stadium: event.target.value })}
            className="text-body h-12 min-w-0 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          />
        </label>
      </div>
    </section>
  );
}
