import { zodResolver } from '@hookform/resolvers/zod';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { useForm, type Resolver } from 'react-hook-form';
import { z } from 'zod';

import { createTeam, patchTeam, useGetTeam } from '../../api/generated/admin';
import type { AdminTeam, TeamCreate, TeamPatch } from '../../api/generated/admin.schemas';
import { createTeamBody } from '../../api/generated/admin.zod';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { LogoField } from '../../components/LogoField/LogoField';
import { useToast } from '../../components/Toast/Toast';
import { common, copyForErrorCode, logoPreview, teams as copy, toast as toastCopy, validation } from '../../i18n/ar';
import { editorConflict, type ConflictField, type EditorConflict } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import '../../lib/validation';
import { useCompetitionOptions } from './queries';

// A5's editor (admin board "Teams"): name, logo, main and other competitions, stadium and country.
// Aliases have no field in D2's admin contract yet, so they are not invented here; the external ids
// stay read-only, as the board has them. The form validates through the same Zod schema the API
// enforces (constitution VIII), and each save is one PATCH under the version — and the ETag — the
// editor loaded, so a stale copy gets a 409 and the conflict dialog instead of overwriting (A-R1-2).

const formSchema = z.object({
  name: createTeamBody.shape.name.trim().min(1, validation.required),
  primaryCompetitionId: z.string(),
  competitionIds: z.array(z.number()),
  stadium: z.string(),
  country: z.string(),
  logoAssetId: z.number().nullable(),
  logoUrl: z.string().nullable(),
});

type TeamDraft = z.infer<typeof formSchema>;

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

interface TeamEditorProps {
  /** `null` creates a team; a number edits that one. */
  teamId: number | null;
  open: boolean;
  onClose: () => void;
  /** Prefills the name of a new team, for A13's «جديد». */
  initialName?: string;
  /** Hands the new team's id back, so A13 can bind the queued name to it. */
  onCreated?: (teamId: number) => void;
}

export function TeamEditor({ teamId, open, onClose, initialName, onCreated }: TeamEditorProps): ReactElement {
  const detail = useGetTeam(teamId ?? 0, {
    query: { enabled: open && teamId !== null, structuralSharing: false },
  });
  const competitions = useCompetitionOptions();
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const form = useForm<TeamDraft>({
    resolver: zodResolver(formSchema) as Resolver<TeamDraft>,
    defaultValues: emptyDraft(),
    mode: 'onSubmit',
  });
  const { register, handleSubmit, formState, watch, reset, setValue } = form;

  const [baseline, setBaseline] = useState<TeamDraft>(emptyDraft);
  /** The version the baseline was read at. It travels with the draft, never from the live refetch. */
  const [baselineEtag, setBaselineEtag] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<EditorConflict<TeamDraft> | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const draft = watch();
  const serverTeam = detail.data?.data;

  const adopt = useCallback(
    (next: TeamDraft, etag: string | null) => {
      setBaseline(next);
      setBaselineEtag(etag);
      reset(next);
    },
    [reset],
  );

  useEffect(() => {
    if (!open) {
      seeded.current = null;
      return;
    }
    if (teamId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      adopt({ ...emptyDraft(), name: initialName ?? '' }, null);
      setSaveError(null);
      return;
    }
    if (!serverTeam || seeded.current === `team-${teamId}`) return;
    seeded.current = `team-${teamId}`;
    adopt(fromTeam(serverTeam), etagOf(detail.data));
    setSaveError(null);
  }, [open, teamId, serverTeam, detail.data, adopt, initialName]);

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
    const current = form.getValues('competitionIds');
    setValue(
      'competitionIds',
      current.includes(id) ? current.filter((candidate) => candidate !== id) : [...current, id],
      { shouldDirty: true },
    );
  }

  async function uploadLogo(file: File): Promise<void> {
    setBusy(true);
    setSaveError(null);
    try {
      const asset = await uploadAsset(file, 'image');
      setValue('logoAssetId', asset.id, { shouldDirty: true });
      setValue('logoUrl', asset.url, { shouldDirty: true });
    } catch (error) {
      setSaveError(copyForErrorCode(error instanceof ApiError ? error.code : NETWORK_ERROR));
    } finally {
      setBusy(false);
    }
  }

  async function submit(parsed: TeamDraft): Promise<void> {
    // A open conflict is answered in its dialog: nothing is re-sent from behind it.
    if (conflict) return;
    setSaveError(null);
    setBusy(true);
    try {
      if (teamId === null) {
        const body: TeamCreate = { name: parsed.name };
        if (parsed.primaryCompetitionId !== '') body.primary_competition_id = Number(parsed.primaryCompetitionId);
        if (parsed.competitionIds.length > 0) body.competition_ids = parsed.competitionIds;
        if (parsed.stadium.trim() !== '') body.stadium = parsed.stadium.trim();
        if (parsed.country.trim() !== '') body.country = parsed.country.trim();
        if (parsed.logoAssetId !== null) body.logo_asset_id = parsed.logoAssetId;
        const created = await createTeam(body);
        if (created.data) onCreated?.(created.data.id);
      } else {
        const body = buildTeamPatch(parsed, baseline);
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchTeam(teamId, body, { headers: baselineEtag ? { 'If-Match': baselineEtag } : {} });
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
    setConflict(editorConflict(failure, fields, baseline, fromTeam(current), etagOf(refreshed.data)));
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
        onSave={() => void handleSubmit(submit)()}
        onClose={requestClose}
      >
        <Field
          label={copy.editor.name}
          error={formState.errors.name?.message}
          {...register('name')}
        />
        <Field label={copy.editor.stadium} {...register('stadium')} />
        <Field label={copy.editor.country} ltr {...register('country')} />

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.editor.primary}</span>
          <select
            aria-label={copy.editor.primary}
            value={draft.primaryCompetitionId}
            onChange={(event) => setValue('primaryCompetitionId', event.target.value, { shouldDirty: true })}
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

        <LogoField
          label={copy.editor.logo}
          darkLabel={logoPreview.onDark}
          lightLabel={logoPreview.onLight}
          uploadLabel={copy.editor.logoUpload}
          url={draft.logoUrl}
          onUpload={(file) => void uploadLogo(file)}
        />

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
          adopt(conflict.theirs, conflict.etag);
          seeded.current = `team-${teamId ?? 'new'}`;
          setConflict(null);
          setSaveError(null);
        }}
        onDiscard={() => {
          reset(baseline);
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
