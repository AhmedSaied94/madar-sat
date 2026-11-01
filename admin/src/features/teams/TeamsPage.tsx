import { useState, type ReactElement } from 'react';

import type { ListTeamsParams, TeamItem } from '../../api/generated/admin.schemas';
import { DataTable, type DataTableColumn } from '../../components/DataTable/DataTable';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { clsx } from 'clsx';
import { copyForErrorCode, teams as copy } from '../../i18n/ar';
import { TeamEditor } from './TeamEditor';
import { useCompetitionOptions, useTeams } from './queries';

// A5 (admin board "Teams"): the team list with its three filters, and the record editor beside it.
// There is no merge tool today, so the table has no bulk bar (spec US4 scenario 2).

const ALL = '';

export function TeamsPage(): ReactElement {
  const [query, setQuery] = useState('');
  const [competitionId, setCompetitionId] = useState(ALL);
  const [missingLogo, setMissingLogo] = useState(false);
  const [editing, setEditing] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);

  const params: ListTeamsParams = {
    q: query.trim() === '' ? null : query.trim(),
    competition_id: competitionId === ALL ? null : Number(competitionId),
    missing_logo: missingLogo ? true : null,
    limit: 100,
  };
  const { data, isPending, isError, error, refetch } = useTeams(params);
  const competitions = useCompetitionOptions();

  const rows = data?.data ?? [];
  const missingLogoCount = rows.filter((row) => row.logo === null).length;

  const columns: readonly DataTableColumn<TeamItem>[] = [
    {
      id: 'team',
      header: copy.columns.team,
      cell: (row) => (
        <span className="flex items-center gap-2">
          {row.logo ? (
            <img src={row.logo} alt="" className="size-6 rounded-pill bg-surface-2 object-contain" />
          ) : (
            <span
              aria-hidden="true"
              className="text-micro flex size-6 flex-none items-center justify-center rounded-pill bg-surface-3 font-semibold text-text-secondary"
            >
              {row.name.slice(0, 1)}
            </span>
          )}
          <bdi className="text-label text-text-primary">{row.name}</bdi>
        </span>
      ),
      sortValue: (row) => row.name,
    },
    {
      id: 'primary',
      header: copy.columns.primary,
      cell: (row) => row.primary_competition?.name ?? <span className="text-caption text-text-tertiary">—</span>,
    },
    {
      id: 'competitions',
      header: copy.columns.competitions,
      cell: (row) =>
        row.competitions.length === 0 ? (
          <span className="text-caption text-text-tertiary">—</span>
        ) : (
          <span className="flex flex-wrap gap-1">
            {row.competitions.map((competition) => (
              <span key={competition.id} className="text-micro rounded-xs bg-surface-2 px-2 py-1 text-text-secondary">
                {competition.name}
              </span>
            ))}
          </span>
        ),
    },
    {
      id: 'country',
      header: copy.columns.country,
      cell: (row) =>
        row.country === null ? (
          <span className="text-caption text-text-tertiary">—</span>
        ) : (
          <bdi dir="ltr" className="text-label text-text-secondary">
            {row.country}
          </bdi>
        ),
    },
  ];

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle(rows.length, missingLogoCount)}</p>
        </div>
        <span className="flex-1" />
        <button
          type="button"
          onClick={() => setCreating(true)}
          className={clsx(
            'text-label inline-flex h-12 items-center gap-2 rounded-lg bg-accent px-3 font-semibold text-on-accent',
            focusRing,
          )}
        >
          <Icon name="plus" size="sm" />
          {copy.add}
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <label className="flex h-8 min-w-0 items-center gap-2 rounded-lg bg-surface-1 px-3 ring-1 ring-inset ring-divider">
          <Icon name="search" size="md" className="text-text-tertiary" />
          <input
            type="search"
            aria-label={copy.search}
            placeholder={copy.search}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="text-caption min-w-0 flex-1 bg-transparent text-text-primary outline-none placeholder:text-text-tertiary"
          />
        </label>

        <select
          aria-label={copy.competitionFilter}
          value={competitionId}
          onChange={(event) => setCompetitionId(event.target.value)}
          className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
        >
          <option value={ALL}>{`${copy.competitionFilter}: ${copy.all}`}</option>
          {competitions.map((competition) => (
            <option key={competition.id} value={competition.id}>
              {competition.name}
            </option>
          ))}
        </select>

        <button
          type="button"
          aria-pressed={missingLogo}
          onClick={() => setMissingLogo((current) => !current)}
          className={clsx(
            'text-caption inline-flex h-8 items-center gap-2 rounded-md px-3 font-semibold ring-1 ring-inset',
            missingLogo ? 'bg-accent-container text-accent-text ring-accent' : 'bg-surface-1 text-text-secondary ring-divider',
            focusRing,
          )}
        >
          <Icon name="image" size="sm" />
          {copy.missingLogoOnly}
        </button>

        <span className="text-caption text-text-tertiary">{copy.searchHint}</span>
      </div>

      <div className="min-w-0 overflow-x-auto rounded-xl bg-surface-1 ring-1 ring-inset ring-divider">
        <DataTable
          label={copy.title}
          columns={columns}
          rows={rows}
          rowKey={(row) => String(row.id)}
          rowActions={(row) => (
            <button
              type="button"
              aria-label={`${copy.columns.edit} ${row.name}`}
              onClick={() => setEditing(row.id)}
              className={`inline-flex size-8 items-center justify-center rounded-sm text-text-secondary hover:bg-surface-3 ${focusRing}`}
            >
              <Icon name="edit" size="sm" />
            </button>
          )}
          onEdit={(row) => setEditing(row.id)}
          loading={isPending}
          emptyMessage={isError ? copyForErrorCode(error?.code ?? '') : copy.editor.empty}
        />
      </div>

      {isError ? (
        <button
          type="button"
          onClick={() => void refetch()}
          className={`text-caption self-start font-semibold text-accent-text ${focusRing}`}
        >
          {copyForErrorCode(error?.code ?? '')}
        </button>
      ) : null}

      <TeamEditor teamId={editing} open={editing !== null} onClose={() => setEditing(null)} />
      <TeamEditor teamId={null} open={creating} onClose={() => setCreating(false)} />
    </div>
  );
}
