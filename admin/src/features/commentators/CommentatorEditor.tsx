import { zodResolver } from '@hookform/resolvers/zod';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { useForm, type Resolver } from 'react-hook-form';
import { z } from 'zod';

import { createCommentator, patchCommentator, useGetCommentator } from '../../api/generated/admin';
import type { AdminCommentator, CommentatorCreate, CommentatorPatch } from '../../api/generated/admin.schemas';
import { createCommentatorBody } from '../../api/generated/admin.zod';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { useToast } from '../../components/Toast/Toast';
import { commentators as copy, common, copyForErrorCode, toast as toastCopy, validation } from '../../i18n/ar';
import { editorConflict, type ConflictField, type EditorConflict } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import '../../lib/validation';

// A10's editor: the name, the photo and the voice sample. Both media upload first and save as asset
// ids, so a lost save never leaves a half-written record. The name validates through the created
// body's Zod schema, and a stale save opens the conflict dialog under the version it loaded (A-R1-2).

const formSchema = z.object({
  name: createCommentatorBody.shape.name.trim().min(1, validation.required),
  photoAssetId: z.number().nullable(),
  photoUrl: z.string().nullable(),
  audioAssetId: z.number().nullable(),
  audioUrl: z.string().nullable(),
});

type CommentatorDraft = z.infer<typeof formSchema>;

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

  const form = useForm<CommentatorDraft>({
    resolver: zodResolver(formSchema) as Resolver<CommentatorDraft>,
    defaultValues: emptyDraft(),
    mode: 'onSubmit',
  });
  const { register, handleSubmit, formState, watch, reset, setValue } = form;

  const [baseline, setBaseline] = useState<CommentatorDraft>(emptyDraft);
  /** The version the baseline was read at; it never follows the live refetch. */
  const [baselineEtag, setBaselineEtag] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<EditorConflict<CommentatorDraft> | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const draft = watch();
  const server = detail.data?.data;

  const adopt = useCallback(
    (next: CommentatorDraft, etag: string | null) => {
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
    if (commentatorId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      adopt(emptyDraft(), null);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `commentator-${commentatorId}`) return;
    seeded.current = `commentator-${commentatorId}`;
    adopt(fromCommentator(server), etagOf(detail.data));
    setSaveError(null);
  }, [open, commentatorId, server, detail.data, adopt]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);

  const fields: readonly ConflictField<CommentatorDraft>[] = [
    { key: 'name', label: copy.editor.name, text: (value) => (value.name.trim() === '' ? null : value.name.trim()) },
    { key: 'photoAssetId', label: copy.editor.photo, text: (value) => value.photoUrl },
    { key: 'audioAssetId', label: copy.editor.audio, text: (value) => value.audioUrl },
  ];

  function requestClose(): void {
    if (dirty) setLeaving(true);
    else onClose();
  }

  async function upload(kind: 'image' | 'audio', file: File): Promise<void> {
    setBusy(true);
    setSaveError(null);
    try {
      const asset = await uploadAsset(file, kind);
      if (kind === 'image') {
        setValue('photoAssetId', asset.id, { shouldDirty: true });
        setValue('photoUrl', asset.url, { shouldDirty: true });
      } else {
        setValue('audioAssetId', asset.id, { shouldDirty: true });
        setValue('audioUrl', asset.url, { shouldDirty: true });
      }
    } catch (error) {
      setSaveError(copyForErrorCode(error instanceof ApiError ? error.code : NETWORK_ERROR));
    } finally {
      setBusy(false);
    }
  }

  async function submit(parsed: CommentatorDraft): Promise<void> {
    if (conflict) return;
    setSaveError(null);
    setBusy(true);
    try {
      if (commentatorId === null) {
        const body: CommentatorCreate = { name: parsed.name };
        if (parsed.photoAssetId !== null) body.photo_asset_id = parsed.photoAssetId;
        if (parsed.audioAssetId !== null) body.audio_asset_id = parsed.audioAssetId;
        await createCommentator(body);
      } else {
        const body: CommentatorPatch = {};
        if (parsed.name !== baseline.name) body.name = parsed.name;
        if (parsed.photoAssetId !== baseline.photoAssetId) body.photo_asset_id = parsed.photoAssetId;
        if (parsed.audioAssetId !== baseline.audioAssetId) body.audio_asset_id = parsed.audioAssetId;
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchCommentator(commentatorId, body, { headers: baselineEtag ? { 'If-Match': baselineEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict' && commentatorId !== null) await openConflict(failure);
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
    setConflict(editorConflict(failure, fields, baseline, fromCommentator(current), etagOf(refreshed.data)));
  }

  const title = commentatorId === null ? copy.editor.newTitle : copy.editor.title;

  return (
    <>
      <EditorDrawer
        open={open}
        title={title}
        subtitle={commentatorId === null ? null : server?.name}
        formLabel={title}
        saving={busy}
        saveError={saveError}
        onSave={() => void handleSubmit(submit)()}
        onClose={requestClose}
      >
        <Field label={copy.editor.name} error={formState.errors.name?.message} {...register('name')} />

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
            <label className="text-label inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-lg bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3 has-[:focus-visible]:outline has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-focus-ring">
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
            <label className="text-label inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-lg bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3 has-[:focus-visible]:outline has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-focus-ring">
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

      <ConflictDialog
        open={conflict !== null}
        subject={draft.name}
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: '' }}
        changes={conflict?.changes ?? []}
        onReload={() => {
          if (!conflict) return;
          adopt(conflict.theirs, conflict.etag);
          seeded.current = `commentator-${commentatorId ?? 'new'}`;
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
