import { useEffect, useMemo, useRef, useState, type ReactElement } from 'react';

import { createChannel, patchChannel, useGetChannel } from '../../api/generated/admin';
import type {
  Access,
  AdminChannel,
  Category,
  ChannelCreate,
  ChannelItem,
  ChannelPatch,
  Kind,
} from '../../api/generated/admin.schemas';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { FrequencyField, type FrequencyValue } from '../../components/FrequencyField/FrequencyField';
import { useToast } from '../../components/Toast/Toast';
import { channels as copy, common, copyForErrorCode, toast as toastCopy } from '../../i18n/ar';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { useSatelliteOptions } from './queries';

// A8's editor drawer: every field of PB A8 — matching and display name, carriage (frequency or a
// platform without a satellite), access, category, country, "shown on match pages" and the logo.
// Completing a placeholder (one the importer created) is this same form: set the carriage and turn
// "shown on match pages" on, and the save clears `placeholder_source` server-side.

export interface ChannelDraft {
  name: string;
  displayName: string;
  kind: Kind;
  satelliteId: string;
  hasFrequency: boolean;
  frequency: FrequencyValue;
  access: Access;
  provider: string;
  packageName: string;
  category: Category;
  country: string;
  showInMatch: boolean;
  logoAssetId: number | null;
  logoUrl: string | null;
}

export const emptyChannelDraft = (): ChannelDraft => ({
  name: '',
  displayName: '',
  kind: 'satellite',
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

const frequencyValue = (frequency: { mhz: number; pol: FrequencyValue['pol']; sr: number } | null): FrequencyValue =>
  frequency === null ? { mhz: '', pol: 'H', sr: '' } : { mhz: String(frequency.mhz), pol: frequency.pol, sr: String(frequency.sr) };

function draftOf(channel: AdminChannel | ChannelItem): ChannelDraft {
  return {
    name: channel.name,
    displayName: channel.display_name ?? '',
    kind: channel.kind,
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
  return { ...draftOf(row), kind: 'satellite', satelliteId: '', hasFrequency: false, frequency: { mhz: '', pol: 'H', sr: '' } };
}

const orNull = (value: string): string | null => (value.trim() === '' ? null : value.trim());

function carriage(draft: ChannelDraft): Pick<ChannelCreate, 'kind' | 'satellite_id' | 'frequency'> {
  if (draft.kind === 'platform') return { kind: 'platform', satellite_id: null, frequency: null };
  return {
    kind: draft.kind,
    satellite_id: draft.satelliteId === '' ? null : Number(draft.satelliteId),
    frequency: draft.hasFrequency && draft.frequency.mhz !== '' && draft.frequency.sr !== ''
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

  const nextCarriage = carriage(draft);
  const beforeCarriage = carriage(original);
  // `ChannelPatch` carries no `kind` (recorded contract gap: B1 adds it), so the carriage a save can
  // change is the satellite and the frequency; the kind only travels on a create.
  if ((nextCarriage.satellite_id ?? null) !== (beforeCarriage.satellite_id ?? null)) {
    patch.satellite_id = nextCarriage.satellite_id ?? null;
  }
  if (JSON.stringify(nextCarriage.frequency) !== JSON.stringify(beforeCarriage.frequency)) {
    patch.frequency = nextCarriage.frequency ?? null;
  }
  return patch;
}

/** What the form must refuse before it sends: a carriage the API would reject anyway. */
export function carriageError(draft: ChannelDraft): boolean {
  if (draft.name.trim() === '') return true;
  if (draft.kind === 'platform') return false;
  if (draft.satelliteId === '') return true;
  if (draft.showInMatch && !(draft.hasFrequency && draft.frequency.mhz !== '' && draft.frequency.sr !== '')) return true;
  return false;
}

interface ChannelEditorProps {
  channelId: number | null;
  open: boolean;
  /** The row «إضافة على قمر آخر» copies; only used when `channelId` is null. */
  seed?: ChannelDraft | null;
  onClose: () => void;
}

export function ChannelEditor({ channelId, open, seed = null, onClose }: ChannelEditorProps): ReactElement {
  const detail = useGetChannel(channelId ?? 0, {
    query: { enabled: open && channelId !== null, structuralSharing: false },
  });
  const satellites = useSatelliteOptions();
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const [baseline, setBaseline] = useState<ChannelDraft>(emptyChannelDraft);
  const [draft, setDraft] = useState<ChannelDraft>(emptyChannelDraft);
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
    if (channelId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      const start = seed ?? emptyChannelDraft();
      setBaseline(emptyChannelDraft());
      setDraft(start);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `channel-${channelId}`) return;
    seeded.current = `channel-${channelId}`;
    const loaded = draftOf(server);
    setBaseline(loaded);
    setDraft(loaded);
    setSaveError(null);
  }, [open, channelId, server, seed]);

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
    if (carriageError(draft)) {
      setSaveError(copyForErrorCode('validation_error'));
      return;
    }
    setBusy(true);
    try {
      if (channelId === null) {
        const body: ChannelCreate = { ...carriage(draft), name: draft.name.trim() };
        body.access = draft.access;
        body.category = draft.category;
        if (draft.displayName.trim() !== '') body.display_name = draft.displayName.trim();
        if (draft.provider.trim() !== '') body.provider = draft.provider.trim();
        if (draft.packageName.trim() !== '') body.package = draft.packageName.trim();
        if (draft.country.trim() !== '') body.country = draft.country.trim();
        body.show_in_match = draft.showInMatch;
        if (draft.logoAssetId !== null) body.logo_asset_id = draft.logoAssetId;
        await createChannel(body);
      } else {
        const body = buildChannelPatch(draft, baseline);
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchChannel(channelId, body, { headers: serverEtag ? { 'If-Match': serverEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict') void detail.refetch();
    } finally {
      setBusy(false);
    }
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
        onSave={() => void save()}
        onClose={requestClose}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Field
            label={copy.editor.matchName}
            value={draft.name}
            onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
            ltr
          />
          <Field
            label={copy.editor.displayName}
            value={draft.displayName}
            onChange={(event) => setDraft((current) => ({ ...current, displayName: event.target.value }))}
            ltr
          />
        </div>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.editor.satellite}</span>
          <select
            aria-label={copy.editor.satellite}
            value={draft.kind === 'platform' ? '' : draft.satelliteId}
            onChange={(event) => {
              const value = event.target.value;
              setDraft((current) =>
                value === ''
                  ? { ...current, kind: 'platform', satelliteId: '', hasFrequency: false }
                  : { ...current, kind: 'satellite', satelliteId: value, hasFrequency: true },
              );
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
        </label>

        {draft.kind === 'satellite' ? (
          <FrequencyField
            label={copy.editor.frequency}
            value={draft.frequency}
            onChange={(frequency) => setDraft((current) => ({ ...current, frequency, hasFrequency: true }))}
            hint={copy.editor.frequencyHint}
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
                  onClick={() => setDraft((current) => ({ ...current, access }))}
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
                <Field
                  label={copy.editor.provider}
                  value={draft.provider}
                  onChange={(event) => setDraft((current) => ({ ...current, provider: event.target.value }))}
                  ltr
                />
                <Field
                  label={copy.editor.package}
                  value={draft.packageName}
                  onChange={(event) => setDraft((current) => ({ ...current, packageName: event.target.value }))}
                />
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
              onChange={(event) =>
                setDraft((current) => ({ ...current, category: event.target.value as Category }))
              }
              className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
            >
              <option value="sports">{copy.sports}</option>
              <option value="entertainment">{copy.entertainment}</option>
            </select>
          </label>
          <Field
            label={copy.editor.country}
            value={draft.country}
            onChange={(event) => setDraft((current) => ({ ...current, country: event.target.value }))}
            ltr
          />
        </div>

        <label className="text-label flex items-center gap-3 rounded-lg bg-bg px-3 py-2 text-text-primary">
          <input
            type="checkbox"
            checked={draft.showInMatch}
            onChange={(event) => setDraft((current) => ({ ...current, showInMatch: event.target.checked }))}
            className="size-4 accent-accent"
          />
          {copy.editor.showInMatch}
        </label>

        <div className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.editor.logo}</span>
          <div className="flex items-center gap-3">
            <span className="flex size-12 items-center justify-center overflow-hidden rounded-lg bg-bg ring-1 ring-inset ring-divider">
              {draft.logoUrl ? <img src={draft.logoUrl} alt="" className="size-8 object-contain" /> : <span className="text-caption text-text-tertiary">—</span>}
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
