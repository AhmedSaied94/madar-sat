import { zodResolver } from '@hookform/resolvers/zod';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { useForm, type Resolver } from 'react-hook-form';
import { z } from 'zod';

import { createCompetition, patchCompetition, useGetCompetition } from '../../api/generated/admin';
import type { AdminCompetition, CompetitionCreate, CompetitionPatch } from '../../api/generated/admin.schemas';
import { createCompetitionBody } from '../../api/generated/admin.zod';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { LogoField } from '../../components/LogoField/LogoField';
import { useToast } from '../../components/Toast/Toast';
import { common, competitions as copy, copyForErrorCode, logoPreview, toast as toastCopy, validation } from '../../i18n/ar';
import { editorConflict, type ConflictField, type EditorConflict } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import '../../lib/validation';

// A6's editor. Aliases have no field in D2's contract yet (recorded follow-up), so the drawer edits
// what the API has: the name and the logo. The form validates through the created body's Zod schema
// (constitution VIII) and saves under the ETag it loaded, so a stale copy opens the conflict dialog
// instead of overwriting the other editor's save (A-R1-2).

const formSchema = z.object({
  name: createCompetitionBody.shape.name.trim().min(1, validation.required),
  logoAssetId: z.number().nullable(),
  logoUrl: z.string().nullable(),
});

type CompetitionDraft = z.infer<typeof formSchema>;

const emptyDraft = (): CompetitionDraft => ({ name: '', logoAssetId: null, logoUrl: null });

const fromCompetition = (competition: AdminCompetition): CompetitionDraft => ({
  name: competition.name,
  logoAssetId: competition.logo_asset_id,
  logoUrl: competition.logo,
});

interface CompetitionEditorProps {
  competitionId: number | null;
  open: boolean;
  onClose: () => void;
  /** Prefills the name of a new competition, for A13's «جديد». */
  initialName?: string;
  /** Hands the new competition's id back, so A13 can bind the queued name to it. */
  onCreated?: (competitionId: number) => void;
}

export function CompetitionEditor({ competitionId, open, onClose, initialName, onCreated }: CompetitionEditorProps): ReactElement {
  const detail = useGetCompetition(competitionId ?? 0, {
    query: { enabled: open && competitionId !== null, structuralSharing: false },
  });
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const form = useForm<CompetitionDraft>({
    resolver: zodResolver(formSchema) as Resolver<CompetitionDraft>,
    defaultValues: emptyDraft(),
    mode: 'onSubmit',
  });
  const { register, handleSubmit, formState, watch, reset, setValue } = form;

  const [baseline, setBaseline] = useState<CompetitionDraft>(emptyDraft);
  /** The version the baseline was read at; it never follows the live refetch. */
  const [baselineEtag, setBaselineEtag] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<EditorConflict<CompetitionDraft> | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const draft = watch();
  const server = detail.data?.data;

  const adopt = useCallback(
    (next: CompetitionDraft, etag: string | null) => {
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
    if (competitionId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      adopt({ ...emptyDraft(), name: initialName ?? '' }, null);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `competition-${competitionId}`) return;
    seeded.current = `competition-${competitionId}`;
    adopt(fromCompetition(server), etagOf(detail.data));
    setSaveError(null);
  }, [open, competitionId, server, detail.data, adopt, initialName]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);

  const fields: readonly ConflictField<CompetitionDraft>[] = [
    { key: 'name', label: copy.editor.name, text: (value) => (value.name.trim() === '' ? null : value.name.trim()) },
    { key: 'logoAssetId', label: copy.editor.logo, text: (value) => value.logoUrl },
  ];

  function requestClose(): void {
    if (dirty) setLeaving(true);
    else onClose();
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

  async function submit(parsed: CompetitionDraft): Promise<void> {
    if (conflict) return;
    setSaveError(null);
    setBusy(true);
    try {
      if (competitionId === null) {
        const body: CompetitionCreate = { name: parsed.name };
        if (parsed.logoAssetId !== null) body.logo_asset_id = parsed.logoAssetId;
        const created = await createCompetition(body);
        if (created.data) onCreated?.(created.data.id);
      } else {
        const body: CompetitionPatch = {};
        if (parsed.name !== baseline.name) body.name = parsed.name;
        if (parsed.logoAssetId !== baseline.logoAssetId) body.logo_asset_id = parsed.logoAssetId;
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchCompetition(competitionId, body, { headers: baselineEtag ? { 'If-Match': baselineEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict' && competitionId !== null) await openConflict(failure);
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
    setConflict(editorConflict(failure, fields, baseline, fromCompetition(current), etagOf(refreshed.data)));
  }

  return (
    <>
      <EditorDrawer
        open={open}
        title={competitionId === null ? copy.editor.newTitle : copy.editor.title}
        subtitle={competitionId === null ? null : server?.name}
        formLabel={competitionId === null ? copy.editor.newTitle : copy.editor.title}
        saving={busy}
        saveError={saveError}
        onSave={() => void handleSubmit(submit)()}
        onClose={requestClose}
      >
        <Field label={copy.editor.name} error={formState.errors.name?.message} {...register('name')} />

        <LogoField
          label={copy.editor.logo}
          darkLabel={logoPreview.onDark}
          lightLabel={logoPreview.onLight}
          uploadLabel={copy.editor.logoUpload}
          url={draft.logoUrl}
          onUpload={(file) => void uploadLogo(file)}
        />
      </EditorDrawer>

      <ConflictDialog
        open={conflict !== null}
        subject={draft.name}
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: '' }}
        changes={conflict?.changes ?? []}
        onReload={() => {
          if (!conflict) return;
          adopt(conflict.theirs, conflict.etag);
          seeded.current = `competition-${competitionId ?? 'new'}`;
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
