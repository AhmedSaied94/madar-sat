import { zodResolver } from '@hookform/resolvers/zod';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { Controller, useForm, type Resolver } from 'react-hook-form';
import { z } from 'zod';

import { createChannel, patchChannel, useGetChannel } from '../../api/generated/admin';
import type {
  Access,
  AdminChannel,
  Category,
  ChannelCreate,
  ChannelItem,
  ChannelPatch,
} from '../../api/generated/admin.schemas';
import { createChannelBody } from '../../api/generated/admin.zod';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { FrequencyField, type FrequencyValue } from '../../components/FrequencyField/FrequencyField';
import { LogoField } from '../../components/LogoField/LogoField';
import { useToast } from '../../components/Toast/Toast';
import { channels as copy, common, copyForErrorCode, logoPreview, toast as toastCopy, validation } from '../../i18n/ar';
import { editorConflict, type ConflictField, type EditorConflict } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import '../../lib/validation';
import { useSatelliteOptions } from './queries';

// A8's editor drawer: every field of PB A8 — matching and display name, carriage (frequency or a
// platform without a satellite), access, category, country, "shown on match pages" and the logo.
// Completing a placeholder (one the importer created) is this same form: set the carriage and turn
// "shown on match pages" on, and the save clears `placeholder_source` server-side. A placeholder is a
// `platform` channel: choosing a satellite and a frequency sends `kind: 'satellite'` with them, in one
// PATCH, and the API turns it into a satellite channel (A-R1-5). The form validates through the created
// body's Zod schema (constitution VIII), and a stale save opens the conflict dialog instead of
// overwriting the other editor's change (A-R1-2).

const carriage = z.object({
  mhz: z.string(),
  pol: z.enum(['H', 'V', 'L', 'R']),
  sr: z.string(),
});

const formSchema = z
  .object({
    name: createChannelBody.shape.name.trim().min(1, validation.required),
    displayName: z.string(),
    kind: z.enum(['satellite', 'terrestrial', 'platform']),
    /** The channel was a `platform` when it was loaded: moving it onto a satellite has to say where to tune. */
    fromPlatform: z.boolean(),
    satelliteId: z.string(),
    hasFrequency: z.boolean(),
    frequency: carriage,
    access: z.enum(['free', 'encrypted']),
    provider: z.string(),
    packageName: z.string(),
    category: z.enum(['sports', 'entertainment']),
    country: z.string(),
    showInMatch: z.boolean(),
    logoAssetId: z.number().nullable(),
    logoUrl: z.string().nullable(),
  })
  .superRefine((draft, ctx) => {
    // What the API refuses anyway (``ck_channels_kind_fields``): say it on the field, once. A platform
    // carries no satellite and needs no frequency to be shown on match pages.
    if (draft.kind === 'platform') return;
    if (draft.satelliteId === '') {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['satelliteId'], message: validation.satelliteRequired });
    }
    if (draft.hasFrequency && carriageFilled(draft.frequency)) return;
    // A platform moved onto a satellite is refused without a frequency (`422 required`), shown or not.
    if (draft.fromPlatform) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['frequency', 'mhz'], message: validation.frequencyRequiredOnSatellite });
    } else if (draft.showInMatch) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['frequency', 'mhz'], message: validation.frequencyRequired });
    }
  });

export type ChannelDraft = z.infer<typeof formSchema>;

export const emptyChannelDraft = (): ChannelDraft => ({
  name: '',
  displayName: '',
  kind: 'satellite',
  fromPlatform: false,
  satelliteId: '',
  hasFrequency: false,
  frequency: { mhz: '', pol: 'H', sr: '' },
  access: 'free',
  provider: '',
  packageName: '',
  category: 'sports',
  country: '',
  showInMatch: true,
  logoAssetId: null,
  logoUrl: null,
});

const carriageFilled = (value: FrequencyValue): boolean => value.mhz !== '' && value.sr !== '';

const frequencyValue = (
  frequency: { mhz: number; pol: FrequencyValue['pol']; sr: number } | null,
): FrequencyValue =>
  frequency === null
    ? { mhz: '', pol: 'H', sr: '' }
    : { mhz: String(frequency.mhz), pol: frequency.pol, sr: String(frequency.sr) };

function draftOf(channel: AdminChannel | ChannelItem): ChannelDraft {
  return {
    name: channel.name,
    displayName: channel.display_name ?? '',
    kind: channel.kind,
    fromPlatform: channel.kind === 'platform',
    satelliteId: channel.satellite_id === null ? '' : String(channel.satellite_id),
    hasFrequency: channel.frequency !== null,
    frequency: frequencyValue(channel.frequency),
    access: channel.access ?? 'free',
    provider: channel.provider ?? '',
    packageName: channel.package ?? '',
    category: channel.category ?? 'sports',
    country: channel.country ?? '',
    showInMatch: channel.show_in_match,
    logoAssetId: channel.logo_asset_id,
    logoUrl: channel.logo,
  };
}

/** «إضافة على قمر آخر»: the same channel's fields, with the carriage left for the new satellite. */
export function draftOnAnotherSatellite(row: ChannelItem): ChannelDraft {
  return {
    ...draftOf(row),
    kind: 'satellite',
    fromPlatform: false,
    satelliteId: '',
    hasFrequency: false,
    frequency: { mhz: '', pol: 'H', sr: '' },
  };
}

const orNull = (value: string): string | null => (value.trim() === '' ? null : value.trim());

function carriageBody(draft: ChannelDraft): Pick<ChannelCreate, 'kind' | 'satellite_id' | 'frequency'> {
  if (draft.kind === 'platform') return { kind: 'platform', satellite_id: null, frequency: null };
  return {
    kind: draft.kind,
    satellite_id: draft.satelliteId === '' ? null : Number(draft.satelliteId),
    frequency:
      draft.hasFrequency && carriageFilled(draft.frequency)
        ? { mhz: Number(draft.frequency.mhz), pol: draft.frequency.pol, sr: Number(draft.frequency.sr) }
        : null,
  };
}

export function buildChannelPatch(draft: ChannelDraft, original: ChannelDraft): ChannelPatch {
  const patch: ChannelPatch = {};
  if (draft.name !== original.name) patch.name = draft.name.trim();
  if (draft.displayName !== original.displayName) patch.display_name = orNull(draft.displayName);
  if (draft.access !== original.access) patch.access = draft.access;
  if (draft.provider !== original.provider) patch.provider = orNull(draft.provider);
  if (draft.packageName !== original.packageName) patch.package = orNull(draft.packageName);
  if (draft.category !== original.category) patch.category = draft.category;
  if (draft.country !== original.country) patch.country = orNull(draft.country);
  if (draft.showInMatch !== original.showInMatch) patch.show_in_match = draft.showInMatch;
  if (draft.logoAssetId !== original.logoAssetId) patch.logo_asset_id = draft.logoAssetId;

  // A platform placeholder completed as a satellite channel: the kind goes with the satellite and the
  // frequency below, and so does the access, which an importer leaves null (the draft shows "free", so
  // the diff above cannot see it, and the API refuses a satellite channel with no access).
  if (original.kind === 'platform' && draft.kind !== 'platform') {
    patch.kind = draft.kind;
    patch.access = draft.access;
  }

  const nextCarriage = carriageBody(draft);
  const beforeCarriage = carriageBody(original);
  if ((nextCarriage.satellite_id ?? null) !== (beforeCarriage.satellite_id ?? null)) {
    patch.satellite_id = nextCarriage.satellite_id ?? null;
  }
  if (JSON.stringify(nextCarriage.frequency) !== JSON.stringify(beforeCarriage.frequency)) {
    patch.frequency = nextCarriage.frequency ?? null;
  }
  return patch;
}

interface ChannelEditorProps {
  channelId: number | null;
  open: boolean;
  /** The row «إضافة على قمر آخر» copies; only used when `channelId` is null. */
  seed?: ChannelDraft | null;
  /** Prefills the name of a new channel, for A13's «جديد». */
  initialName?: string;
  /** Hands the new channel's id back, so A13 can bind the queued name to it. */
  onCreated?: (channelId: number) => void;
  onClose: () => void;
}

export function ChannelEditor({
  channelId,
  open,
  seed = null,
  initialName,
  onCreated,
  onClose,
}: ChannelEditorProps): ReactElement {
  const detail = useGetChannel(channelId ?? 0, {
    query: { enabled: open && channelId !== null, structuralSharing: false },
  });
  const satellites = useSatelliteOptions();
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const form = useForm<ChannelDraft>({
    resolver: zodResolver(formSchema) as Resolver<ChannelDraft>,
    defaultValues: emptyChannelDraft(),
    mode: 'onSubmit',
  });
  const { register, handleSubmit, formState, watch, reset, setValue, control } = form;

  const [baseline, setBaseline] = useState<ChannelDraft>(emptyChannelDraft);
  /** The version the baseline was read at; it never follows the live refetch. */
  const [baselineEtag, setBaselineEtag] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<EditorConflict<ChannelDraft> | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const draft = watch();
  const server = detail.data?.data;

  const adopt = useCallback(
    (next: ChannelDraft, etag: string | null) => {
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
    if (channelId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      const start = seed ?? { ...emptyChannelDraft(), name: initialName ?? '' };
      setBaseline(emptyChannelDraft());
      setBaselineEtag(null);
      reset(start);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `channel-${channelId}`) return;
    seeded.current = `channel-${channelId}`;
    adopt(draftOf(server), etagOf(detail.data));
    setSaveError(null);
  }, [open, channelId, server, seed, detail.data, adopt, reset, initialName]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);

  const fields: readonly ConflictField<ChannelDraft>[] = [
    { key: 'name', label: copy.editor.matchName, text: (value) => (value.name.trim() === '' ? null : value.name.trim()) },
    { key: 'display_name', label: copy.editor.displayName, text: (value) => orNull(value.displayName) },
    {
      key: 'satellite_id',
      label: copy.editor.satellite,
      text: (value) =>
        value.kind === 'platform'
          ? null
          : (satellites.find((satellite) => String(satellite.id) === value.satelliteId)?.name_ar ??
            value.satelliteId),
    },
    {
      key: 'frequency',
      label: copy.editor.frequency,
      text: (value) =>
        value.hasFrequency && carriageFilled(value.frequency)
          ? `${value.frequency.mhz} ${value.frequency.pol} ${value.frequency.sr}`
          : null,
    },
    { key: 'access', label: copy.editor.access, text: (value) => (value.access === 'free' ? copy.free : copy.encrypted) },
    { key: 'provider', label: copy.editor.provider, text: (value) => orNull(value.provider) },
    { key: 'package', label: copy.editor.package, text: (value) => orNull(value.packageName) },
    { key: 'category', label: copy.editor.category, text: (value) => (value.category === 'sports' ? copy.sports : copy.entertainment) },
    { key: 'country', label: copy.editor.country, text: (value) => orNull(value.country) },
    {
      key: 'show_in_match',
      label: copy.editor.showInMatch,
      text: (value) => (value.showInMatch ? copy.yes : copy.no),
    },
    { key: 'logo_asset_id', label: copy.editor.logo, text: (value) => value.logoUrl },
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

  async function submit(parsed: ChannelDraft): Promise<void> {
    if (conflict) return;
    setSaveError(null);
    setBusy(true);
    try {
      if (channelId === null) {
        const body: ChannelCreate = { ...carriageBody(parsed), name: parsed.name };
        body.access = parsed.access;
        body.category = parsed.category;
        if (parsed.displayName.trim() !== '') body.display_name = parsed.displayName.trim();
        if (parsed.provider.trim() !== '') body.provider = parsed.provider.trim();
        if (parsed.packageName.trim() !== '') body.package = parsed.packageName.trim();
        if (parsed.country.trim() !== '') body.country = parsed.country.trim();
        body.show_in_match = parsed.showInMatch;
        if (parsed.logoAssetId !== null) body.logo_asset_id = parsed.logoAssetId;
        const created = await createChannel(body);
        if (created.data) onCreated?.(created.data.id);
      } else {
        const body = buildChannelPatch(parsed, baseline);
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchChannel(channelId, body, { headers: baselineEtag ? { 'If-Match': baselineEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict' && channelId !== null) await openConflict(failure);
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
    setConflict(editorConflict(failure, fields, baseline, draftOf(current), etagOf(refreshed.data)));
  }

  const title = channelId === null ? copy.editor.newTitle : copy.editor.title;

  return (
    <>
      <EditorDrawer
        open={open}
        title={title}
        subtitle={channelId === null ? null : server?.name}
        formLabel={title}
        saving={busy}
        saveError={saveError}
        onSave={() => void handleSubmit(submit)()}
        onClose={requestClose}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={copy.editor.matchName} ltr error={formState.errors.name?.message} {...register('name')} />
          <Field label={copy.editor.displayName} ltr {...register('displayName')} />
        </div>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.editor.satellite}</span>
          <select
            aria-label={copy.editor.satellite}
            value={draft.kind === 'platform' ? '' : draft.satelliteId}
            onChange={(event) => {
              const value = event.target.value;
              if (value === '') {
                setValue('kind', 'platform', { shouldDirty: true });
                setValue('satelliteId', '', { shouldDirty: true });
                setValue('hasFrequency', false, { shouldDirty: true });
              } else {
                setValue('kind', 'satellite', { shouldDirty: true });
                setValue('satelliteId', value, { shouldDirty: true });
                setValue('hasFrequency', true, { shouldDirty: true });
              }
            }}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          >
            <option value="">{copy.noSatellite}</option>
            {satellites.map((satellite) => (
              <option key={satellite.id} value={satellite.id}>
                {satellite.name_ar}
              </option>
            ))}
          </select>
          {formState.errors.satelliteId ? (
            <span className="text-caption text-error">{formState.errors.satelliteId.message}</span>
          ) : null}
        </label>

        {draft.kind === 'satellite' ? (
          <Controller
            control={control}
            name="frequency"
            render={({ field }) => (
              <FrequencyField
                label={copy.editor.frequency}
                value={field.value}
                onChange={(frequency) => {
                  field.onChange(frequency);
                  setValue('hasFrequency', true, { shouldDirty: true });
                }}
                error={formState.errors.frequency?.mhz?.message}
                hint={copy.editor.frequencyHint}
              />
            )}
          />
        ) : null}

        <fieldset className="flex flex-col gap-2">
          <legend className="text-caption font-semibold text-text-secondary">{copy.editor.access}</legend>
          <div className="flex flex-wrap items-center gap-2">
            <div role="radiogroup" aria-label={copy.editor.access} className="flex gap-1 rounded-lg bg-bg p-1">
              {(['free', 'encrypted'] as const).map((access) => (
                <button
                  key={access}
                  type="button"
                  role="radio"
                  aria-checked={draft.access === access}
                  onClick={() => setValue('access', access as Access, { shouldDirty: true })}
                  className={`text-caption h-8 rounded-sm px-3 font-semibold ${
                    draft.access === access
                      ? 'bg-text-primary text-text-on-inverse'
                      : 'text-text-secondary hover:bg-surface-2'
                  }`}
                >
                  {access === 'free' ? copy.free : copy.encrypted}
                </button>
              ))}
            </div>
            {draft.access === 'encrypted' ? (
              <>
                <Field label={copy.editor.provider} ltr {...register('provider')} />
                <Field label={copy.editor.package} {...register('packageName')} />
              </>
            ) : null}
          </div>
        </fieldset>

        <div className="grid gap-4 sm:grid-cols-2">
          <label className="flex flex-col gap-2">
            <span className="text-caption font-semibold text-text-secondary">{copy.editor.category}</span>
            <select
              aria-label={copy.editor.category}
              value={draft.category}
              onChange={(event) => setValue('category', event.target.value as Category, { shouldDirty: true })}
              className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
            >
              <option value="sports">{copy.sports}</option>
              <option value="entertainment">{copy.entertainment}</option>
            </select>
          </label>
          <Field label={copy.editor.country} ltr {...register('country')} />
        </div>

        <label className="text-label flex items-center gap-3 rounded-lg bg-bg px-3 py-2 text-text-primary">
          <input
            type="checkbox"
            checked={draft.showInMatch}
            onChange={(event) => setValue('showInMatch', event.target.checked, { shouldDirty: true })}
            className="size-4 accent-accent"
          />
          {copy.editor.showInMatch}
        </label>

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
          seeded.current = `channel-${channelId ?? 'new'}`;
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
