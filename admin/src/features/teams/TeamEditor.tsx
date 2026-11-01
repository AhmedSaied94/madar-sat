import { useEffect, useMemo, useRef, useState, type ReactElement } from 'react';

import { createTeam, patchTeam, useGetTeam } from '../../api/generated/admin';
import type { AdminTeam, TeamCreate, TeamPatch } from '../../api/generated/admin.schemas';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConflictDialog, type ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { useToast } from '../../components/Toast/Toast';
import { common, copyForErrorCode, teams as copy, toast as toastCopy } from '../../i18n/ar';
import { conflictParty, diffDrafts, type ConflictField } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { useCompetitionOptions } from './queries';

// A5's editor (admin board "Teams"): name, logo, main and other competitions, stadium and country.
// Aliases have no field in D2's admin contract yet, so they are not invented here; the external ids
// stay read-only, as the board has them. Each save is one PATCH under the version the editor loaded.

interface TeamDraft {
  name: string;
  primaryCompetitionId: string;
  competitionIds: number[];
  stadium: string;
  country: string;
  logoAssetId: number | null;
  logoUrl: string | null;
}

const emptyDraft = (): TeamDraft => ({
  name: '',
  primaryCompetitionId: '',
  competitionIds: [],
  stadium: '',
  country: '',
  logoAssetId: null,
  logoUrl: null,
});

function fromTeam(team: AdminTeam): TeamDraft {
  return {
    name: team.name,
    primaryCompetitionId: team.primary_competition_id === null ? '' : String(team.primary_competition_id),
    competitionIds: team.competition_ids,
    stadium: team.stadium ?? '',
    country: team.country ?? '',
    logoAssetId: team.logo_asset_id,
    logoUrl: team.logo,
  };
}

const orNull = (value: string): string | null => (value.trim() === '' ? null : value.trim());

export function buildTeamPatch(draft: TeamDraft, original: TeamDraft): TeamPatch {
  const patch: TeamPatch = {};
  if (draft.name !== original.name) patch.name = draft.name.trim();
  if (draft.stadium !== original.stadium) patch.stadium = orNull(draft.stadium);
  if (draft.country !== original.country) patch.country = orNull(draft.country);
  if (draft.logoAssetId !== original.logoAssetId) patch.logo_asset_id = draft.logoAssetId;
  if (draft.primaryCompetitionId !== original.primaryCompetitionId) {
    patch.primary_competition_id = draft.primaryCompetitionId === '' ? null : Number(draft.primaryCompetitionId);
  }
  if (draft.competitionIds.join(',') !== original.competitionIds.join(',')) {
    patch.competition_ids = draft.competitionIds;
  }
  return patch;
}

interface ConflictState {
  changedBy: ReturnType<typeof conflictParty>;
  changes: ConflictChange[];
  theirs: TeamDraft;
  etag: string | null;
}

interface TeamEditorProps {
  /** `null` creates a team; a number edits that one. */
  teamId: number | null;
  open: boolean;
  onClose: () => void;
}

export function TeamEditor({ teamId, open, onClose }: TeamEditorProps): ReactElement {
  const detail = useGetTeam(teamId ?? 0, {
    query: { enabled: open && teamId !== null, structuralSharing: false },
  });
  const competitions = useCompetitionOptions();
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const [baseline, setBaseline] = useState<TeamDraft>(emptyDraft);
  const [draft, setDraft] = useState<TeamDraft>(emptyDraft);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<ConflictState | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const serverTeam = detail.data?.data;
  const serverEtag = etagOf(detail.data);

  useEffect(() => {
    if (!open) {
      seeded.current = null;
      return;
    }
    if (teamId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      const empty = emptyDraft();
      setBaseline(empty);
      setDraft(empty);
      setSaveError(null);
      return;
    }
    if (!serverTeam || seeded.current === `team-${teamId}`) return;
    seeded.current = `team-${teamId}`;
    const loaded = fromTeam(serverTeam);
    setBaseline(loaded);
    setDraft(loaded);
    setSaveError(null);
  }, [open, teamId, serverTeam]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);
  const competitionName = (id: string | number): string =>
    competitions.find((competition) => String(competition.id) === String(id))?.name ?? String(id);

  const fields: readonly ConflictField<TeamDraft>[] = [
    { key: 'name', label: copy.editor.name, text: (value) => orNull(value.name) },
    {
      key: 'primaryCompetitionId',
      label: copy.editor.primary,
      text: (value) => (value.primaryCompetitionId === '' ? null : competitionName(value.primaryCompetitionId)),
    },
    {
      key: 'competitionIds',
      label: copy.editor.competitions,
      text: (value) =>
        value.competitionIds.length === 0 ? null : value.competitionIds.map(competitionName).join('، '),
    },
    { key: 'stadium', label: copy.editor.stadium, text: (value) => orNull(value.stadium) },
    { key: 'country', label: copy.editor.country, text: (value) => orNull(value.country) },
    { key: 'logoAssetId', label: copy.editor.logo, text: (value) => value.logoUrl },
  ];

  function requestClose(): void {
    if (dirty) setLeaving(true);
    else onClose();
  }

  function toggleCompetition(id: number): void {
    setDraft((current) => ({
      ...current,
      competitionIds: current.competitionIds.includes(id)
        ? current.competitionIds.filter((candidate) => candidate !== id)
        : [...current.competitionIds, id],
    }));
  }

  async function uploadLogo(file: File): Promise<void> {
    setBusy(true);
    setSaveError(null);
    try {
      const asset = await uploadAsset(file, 'image');
      setDraft((current) => ({ ...current, logoAssetId: asset.id, logoUrl: asset.url }));
    } catch (error) {
      setSaveError(copyForErrorCode(error instanceof ApiError ? error.code : NETWORK_ERROR));
    } finally {
      setBusy(false);
    }
  }

  async function save(): Promise<void> {
    setSaveError(null);
    if (draft.name.trim() === '') {
      setSaveError(copyForErrorCode('validation_error'));
      return;
    }
    setBusy(true);
    try {
      if (teamId === null) {
        const body: TeamCreate = { name: draft.name.trim() };
        if (draft.primaryCompetitionId !== '') body.primary_competition_id = Number(draft.primaryCompetitionId);
        if (draft.competitionIds.length > 0) body.competition_ids = draft.competitionIds;
        if (draft.stadium.trim() !== '') body.stadium = draft.stadium.trim();
        if (draft.country.trim() !== '') body.country = draft.country.trim();
        if (draft.logoAssetId !== null) body.logo_asset_id = draft.logoAssetId;
        await createTeam(body);
      } else {
        const body = buildTeamPatch(draft, baseline);
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchTeam(teamId, body, { headers: serverEtag ? { 'If-Match': serverEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict' && teamId !== null) await openConflict(failure);
    } finally {
      setBusy(false);
    }
  }

  async function openConflict(failure: ApiError): Promise<void> {
    const refreshed = await detail.refetch();
    const current = refreshed.data?.data;
    if (!current) {
      setSaveError(copyForErrorCode(refreshed.error?.code ?? failure.code));
      return;
    }
    const theirs = fromTeam(current);
    setConflict({
      changedBy: conflictParty(failure.meta),
      changes: diffDrafts(fields, baseline, theirs),
      theirs,
      etag: etagOf(refreshed.data),
    });
  }

  return (
    <>
      <EditorDrawer
        open={open}
        title={teamId === null ? copy.editor.newTitle : copy.editor.title}
        subtitle={teamId === null ? null : serverTeam?.name}
        formLabel={teamId === null ? copy.editor.newTitle : copy.editor.title}
        saving={busy || detail.isFetching}
        saveError={saveError}
        onSave={() => void save()}
        onClose={requestClose}
      >
        <Field
          label={copy.editor.name}
          value={draft.name}
          onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
        />
        <Field
          label={copy.editor.stadium}
          value={draft.stadium}
          onChange={(event) => setDraft((current) => ({ ...current, stadium: event.target.value }))}
        />
        <Field
          label={copy.editor.country}
          value={draft.country}
          onChange={(event) => setDraft((current) => ({ ...current, country: event.target.value }))}
          ltr
        />

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.editor.primary}</span>
          <select
            aria-label={copy.editor.primary}
            value={draft.primaryCompetitionId}
            onChange={(event) => setDraft((current) => ({ ...current, primaryCompetitionId: event.target.value }))}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          >
            <option value="">{copy.editor.noCompetition}</option>
            {competitions.map((competition) => (
              <option key={competition.id} value={competition.id}>
                {competition.name}
              </option>
            ))}
          </select>
        </label>

        <fieldset className="flex flex-col">
          <legend className="text-caption mb-2 font-semibold text-text-secondary">{copy.editor.competitions}</legend>
          <div className="flex flex-col gap-1 overflow-y-auto rounded-lg bg-bg p-3">
            {competitions.map((competition) => (
              <label key={competition.id} className="text-label flex items-center gap-2 text-text-primary">
                <input
                  type="checkbox"
                  checked={draft.competitionIds.includes(competition.id)}
                  onChange={() => toggleCompetition(competition.id)}
                  className="size-4 accent-accent"
                />
                {competition.name}
              </label>
            ))}
          </div>
        </fieldset>

        <div className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.editor.logo}</span>
          <div className="flex items-center gap-3">
            <span className="flex size-12 items-center justify-center overflow-hidden rounded-lg bg-bg ring-1 ring-inset ring-divider">
              {draft.logoUrl ? (
                <img src={draft.logoUrl} alt="" className="size-12 object-contain" />
              ) : (
                <span className="text-caption text-text-tertiary">—</span>
              )}
            </span>
            <label className="text-label inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-lg bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3">
              <input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                className="sr-only"
                aria-label={copy.editor.logoUpload}
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  if (file) void uploadLogo(file);
                }}
              />
              {copy.editor.logoUpload}
            </label>
          </div>
        </div>

        {teamId !== null && serverTeam ? (
          <div className="flex flex-col gap-2">
            <span className="text-caption font-semibold text-text-secondary">{copy.editor.externalIds}</span>
            <div className="flex flex-wrap gap-2">
              {serverTeam.external_ids.length === 0 ? (
                <span className="text-caption text-text-tertiary">—</span>
              ) : (
                serverTeam.external_ids.map((external) => (
                  <span
                    key={`${external.source}-${external.external_id}`}
                    dir="ltr"
                    className="text-micro rounded-xs bg-surface-2 px-2 py-1 font-mono text-text-secondary ring-1 ring-inset ring-divider"
                  >
                    {external.source} {external.external_id}
                  </span>
                ))
              )}
            </div>
            <span className="text-caption text-text-tertiary">{copy.editor.externalHint}</span>
          </div>
        ) : null}
      </EditorDrawer>

      <ConflictDialog
        open={conflict !== null}
        subject={draft.name}
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: '' }}
        changes={conflict?.changes ?? []}
        onReload={() => {
          if (!conflict) return;
          setDraft(conflict.theirs);
          setBaseline(conflict.theirs);
          seeded.current = `team-${teamId ?? 'new'}`;
          setConflict(null);
          setSaveError(null);
        }}
        onDiscard={() => {
          setDraft(baseline);
          setConflict(null);
          setSaveError(null);
        }}
        onDismiss={() => setConflict(null)}
      />

      <ConfirmDialog
        open={leaving}
        title={common.unsaved}
        body={copy.editor.unsavedBody}
        confirmLabel={common.leave}
        cancelLabel={common.stay}
        destructive
        onConfirm={() => {
          setLeaving(false);
          onClose();
        }}
        onCancel={() => setLeaving(false)}
      />
    </>
  );
}
