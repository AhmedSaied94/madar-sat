import { useEffect, useRef, useState, type ReactElement } from 'react';

import { createCommentator, patchCommentator, useGetCommentator } from '../../api/generated/admin';
import type { AdminCommentator, CommentatorCreate, CommentatorPatch } from '../../api/generated/admin.schemas';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { useToast } from '../../components/Toast/Toast';
import { commentators as copy, copyForErrorCode, toast as toastCopy } from '../../i18n/ar';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';

// A10's editor: the name, the photo and the voice sample. Both media upload first and save as asset
// ids, so a lost save never leaves a half-written record.

interface CommentatorDraft {
  name: string;
  photoAssetId: number | null;
  photoUrl: string | null;
  audioAssetId: number | null;
  audioUrl: string | null;
}

const emptyDraft = (): CommentatorDraft => ({
  name: '',
  photoAssetId: null,
  photoUrl: null,
  audioAssetId: null,
  audioUrl: null,
});

const fromCommentator = (person: AdminCommentator): CommentatorDraft => ({
  name: person.name,
  photoAssetId: person.photo_asset_id,
  photoUrl: person.photo,
  audioAssetId: person.audio_asset_id,
  audioUrl: person.audio,
});

interface CommentatorEditorProps {
  commentatorId: number | null;
  open: boolean;
  onClose: () => void;
}

export function CommentatorEditor({ commentatorId, open, onClose }: CommentatorEditorProps): ReactElement {
  const detail = useGetCommentator(commentatorId ?? 0, {
    query: { enabled: open && commentatorId !== null, structuralSharing: false },
  });
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const [baseline, setBaseline] = useState<CommentatorDraft>(emptyDraft);
  const [draft, setDraft] = useState<CommentatorDraft>(emptyDraft);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const server = detail.data?.data;
  const serverEtag = etagOf(detail.data);

  useEffect(() => {
    if (!open) {
      seeded.current = null;
      return;
    }
    if (commentatorId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      const empty = emptyDraft();
      setBaseline(empty);
      setDraft(empty);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `commentator-${commentatorId}`) return;
    seeded.current = `commentator-${commentatorId}`;
    const loaded = fromCommentator(server);
    setBaseline(loaded);
    setDraft(loaded);
    setSaveError(null);
  }, [open, commentatorId, server]);

  async function upload(kind: 'image' | 'audio', file: File): Promise<void> {
    setBusy(true);
    setSaveError(null);
    try {
      const asset = await uploadAsset(file, kind);
      setDraft((current) =>
        kind === 'image'
          ? { ...current, photoAssetId: asset.id, photoUrl: asset.url }
          : { ...current, audioAssetId: asset.id, audioUrl: asset.url },
      );
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
      if (commentatorId === null) {
        const body: CommentatorCreate = { name: draft.name.trim() };
        if (draft.photoAssetId !== null) body.photo_asset_id = draft.photoAssetId;
        if (draft.audioAssetId !== null) body.audio_asset_id = draft.audioAssetId;
        await createCommentator(body);
      } else {
        const body: CommentatorPatch = {};
        if (draft.name !== baseline.name) body.name = draft.name.trim();
        if (draft.photoAssetId !== baseline.photoAssetId) body.photo_asset_id = draft.photoAssetId;
        if (draft.audioAssetId !== baseline.audioAssetId) body.audio_asset_id = draft.audioAssetId;
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchCommentator(commentatorId, body, { headers: serverEtag ? { 'If-Match': serverEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict') void detail.refetch();
    } finally {
      setBusy(false);
    }
  }

  const title = commentatorId === null ? copy.editor.newTitle : copy.editor.title;

  return (
    <EditorDrawer
      open={open}
      title={title}
      subtitle={commentatorId === null ? null : server?.name}
      formLabel={title}
      saving={busy}
      saveError={saveError}
      onSave={() => void save()}
      onClose={onClose}
    >
      <Field
        label={copy.editor.name}
        value={draft.name}
        onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
      />

      <div className="flex flex-col gap-2">
        <span className="text-caption font-semibold text-text-secondary">{copy.editor.photo}</span>
        <div className="flex items-center gap-3">
          <span className="flex size-12 items-center justify-center overflow-hidden rounded-pill bg-surface-3">
            {draft.photoUrl ? (
              <img src={draft.photoUrl} alt="" className="size-12 object-cover" />
            ) : (
              <span className="text-caption text-text-tertiary">—</span>
            )}
          </span>
          <label className="text-label inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-lg bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3">
            <input
              type="file"
              accept="image/png,image/jpeg,image/webp"
              className="sr-only"
              aria-label={copy.editor.photoUpload}
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) void upload('image', file);
              }}
            />
            {copy.editor.photoUpload}
          </label>
        </div>
      </div>

      <div className="flex flex-col gap-2">
        <span className="text-caption font-semibold text-text-secondary">{copy.editor.audio}</span>
        <div className="flex flex-wrap items-center gap-3">
          <label className="text-label inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-lg bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3">
            <input
              type="file"
              accept="audio/mpeg,audio/mp4,audio/ogg,audio/wav"
              className="sr-only"
              aria-label={copy.editor.audioUpload}
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) void upload('audio', file);
              }}
            />
            {copy.editor.audioUpload}
          </label>
          {draft.audioUrl ? (
            <bdi dir="ltr" className="text-micro truncate font-mono text-text-tertiary">
              {draft.audioUrl.split('/').at(-1)}
            </bdi>
          ) : null}
        </div>
      </div>
    </EditorDrawer>
  );
}
