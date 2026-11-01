import { useEffect, useMemo, useRef, useState, type ReactElement } from 'react';

import { createCompetition, patchCompetition, useGetCompetition } from '../../api/generated/admin';
import type { AdminCompetition, CompetitionCreate, CompetitionPatch } from '../../api/generated/admin.schemas';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { useToast } from '../../components/Toast/Toast';
import { common, competitions as copy, copyForErrorCode, toast as toastCopy } from '../../i18n/ar';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';

// A6's editor. Aliases have no field in D2's contract yet (recorded follow-up), so the drawer edits
// what the API has: the name and the logo.

interface CompetitionDraft {
  name: string;
  logoAssetId: number | null;
  logoUrl: string | null;
}

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
}

export function CompetitionEditor({ competitionId, open, onClose }: CompetitionEditorProps): ReactElement {
  const detail = useGetCompetition(competitionId ?? 0, {
    query: { enabled: open && competitionId !== null, structuralSharing: false },
  });
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const [baseline, setBaseline] = useState<CompetitionDraft>(emptyDraft);
  const [draft, setDraft] = useState<CompetitionDraft>(emptyDraft);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const server = detail.data?.data;
  const serverEtag = etagOf(detail.data);

  useEffect(() => {
    if (!open) {
      seeded.current = null;
      return;
    }
    if (competitionId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      const empty = emptyDraft();
      setBaseline(empty);
      setDraft(empty);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `competition-${competitionId}`) return;
    seeded.current = `competition-${competitionId}`;
    const loaded = fromCompetition(server);
    setBaseline(loaded);
    setDraft(loaded);
    setSaveError(null);
  }, [open, competitionId, server]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);

  function requestClose(): void {
    if (dirty) setLeaving(true);
    else onClose();
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
      if (competitionId === null) {
        const body: CompetitionCreate = { name: draft.name.trim() };
        if (draft.logoAssetId !== null) body.logo_asset_id = draft.logoAssetId;
        await createCompetition(body);
      } else {
        const body: CompetitionPatch = {};
        if (draft.name !== baseline.name) body.name = draft.name.trim();
        if (draft.logoAssetId !== baseline.logoAssetId) body.logo_asset_id = draft.logoAssetId;
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchCompetition(competitionId, body, { headers: serverEtag ? { 'If-Match': serverEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      // A stale copy is refetched so the next save is made against the version that exists.
      if (failure.code === 'edit_conflict') void detail.refetch();
    } finally {
      setBusy(false);
    }
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
        onSave={() => void save()}
        onClose={requestClose}
      >
        <Field
          label={copy.editor.name}
          value={draft.name}
          onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
        />

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
      </EditorDrawer>

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
