import { useEffect, useMemo, useRef, useState, type ReactElement } from 'react';

import { createSatellite, patchSatellite, useGetSatellite } from '../../api/generated/admin';
import type { AdminSatellite, Frequency, SatelliteCreate, SatellitePatch } from '../../api/generated/admin.schemas';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { FrequencyField, type FrequencyValue } from '../../components/FrequencyField/FrequencyField';
import { useToast } from '../../components/Toast/Toast';
import { common, copyForErrorCode, satellites as copy, toast as toastCopy } from '../../i18n/ar';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';

// A7's editor (admin board "Satellites"): the two names, the orbital position stored as "east
// positive", the best and worst frequency, the reception clip and the logo. The position, the
// frequencies and the https-only reception link are the fields the app reads, so they are validated
// here as the contract states them.

interface SatelliteDraft {
  nameAr: string;
  nameEn: string;
  degree: string;
  direction: 'E' | 'W';
  best: FrequencyValue;
  hasBest: boolean;
  worst: FrequencyValue;
  hasWorst: boolean;
  receptionUrl: string;
  logoAssetId: number | null;
  logoUrl: string | null;
}

const emptyFrequency = (): FrequencyValue => ({ mhz: '', pol: 'H', sr: '' });

const emptyDraft = (): SatelliteDraft => ({
  nameAr: '',
  nameEn: '',
  degree: '',
  direction: 'E',
  best: emptyFrequency(),
  hasBest: false,
  worst: emptyFrequency(),
  hasWorst: false,
  receptionUrl: '',
  logoAssetId: null,
  logoUrl: null,
});

const toValue = (frequency: Frequency | null): FrequencyValue =>
  frequency === null ? emptyFrequency() : { mhz: String(frequency.mhz), pol: frequency.pol, sr: String(frequency.sr) };

function fromSatellite(satellite: AdminSatellite): SatelliteDraft {
  const position = satellite.orbital_position;
  return {
    nameAr: satellite.name_ar,
    nameEn: satellite.name_en,
    degree: position === null ? '' : String(Math.abs(position)),
    direction: position !== null && position < 0 ? 'W' : 'E',
    best: toValue(satellite.best_frequency),
    hasBest: satellite.best_frequency !== null,
    worst: toValue(satellite.worst_frequency),
    hasWorst: satellite.worst_frequency !== null,
    receptionUrl: satellite.reception_url ?? '',
    logoAssetId: satellite.logo_asset_id,
    logoUrl: satellite.logo,
  };
}

/** The stored position: positive east, negative west, `null` when the editor typed nothing. */
export function orbitalPosition(draft: SatelliteDraft): number | null {
  if (draft.degree.trim() === '') return null;
  const degrees = Number(draft.degree);
  if (!Number.isFinite(degrees)) return null;
  return draft.direction === 'W' ? -degrees : degrees;
}

/** «7.0W», as the board's readout prints it. */
export function formatPosition(position: number | null): string | null {
  if (position === null) return null;
  return `${Math.abs(position).toFixed(1)}${position < 0 ? 'W' : 'E'}`;
}

export function frequencyBody(value: FrequencyValue): Frequency {
  return { mhz: Number(value.mhz), pol: value.pol, sr: Number(value.sr) };
}

const frequencyFilled = (value: FrequencyValue): boolean => value.mhz !== '' && value.sr !== '';

/** A slug the API accepts, derived from the English name (the field the board doesn't show). */
export function slugOf(nameEn: string): string {
  return nameEn
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

interface SatelliteEditorProps {
  satelliteId: number | null;
  open: boolean;
  onClose: () => void;
}

export function SatelliteEditor({ satelliteId, open, onClose }: SatelliteEditorProps): ReactElement {
  const detail = useGetSatellite(satelliteId ?? 0, {
    query: { enabled: open && satelliteId !== null, structuralSharing: false },
  });
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const [baseline, setBaseline] = useState<SatelliteDraft>(emptyDraft);
  const [draft, setDraft] = useState<SatelliteDraft>(emptyDraft);
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
    if (satelliteId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      const empty = emptyDraft();
      setBaseline(empty);
      setDraft(empty);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `sat-${satelliteId}`) return;
    seeded.current = `sat-${satelliteId}`;
    const loaded = fromSatellite(server);
    setBaseline(loaded);
    setDraft(loaded);
    setSaveError(null);
  }, [open, satelliteId, server]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);
  const receptionInvalid =
    draft.receptionUrl.trim() !== '' && !/^https:\/\/\S+$/u.test(draft.receptionUrl.trim());

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
    if (draft.nameAr.trim() === '' || draft.nameEn.trim() === '' || receptionInvalid) {
      setSaveError(copyForErrorCode('validation_error'));
      return;
    }
    const position = orbitalPosition(draft);
    const best = draft.hasBest && frequencyFilled(draft.best) ? frequencyBody(draft.best) : null;
    const worst = draft.hasWorst && frequencyFilled(draft.worst) ? frequencyBody(draft.worst) : null;

    setBusy(true);
    try {
      if (satelliteId === null) {
        const slug = slugOf(draft.nameEn);
        if (slug === '') {
          setSaveError(copyForErrorCode('validation_error'));
          return;
        }
        const body: SatelliteCreate = { name_ar: draft.nameAr.trim(), name_en: draft.nameEn.trim(), slug };
        if (position !== null) body.orbital_position = position;
        if (best) body.best_frequency = best;
        if (worst) body.worst_frequency = worst;
        if (draft.receptionUrl.trim() !== '') body.reception_url = draft.receptionUrl.trim();
        if (draft.logoAssetId !== null) body.logo_asset_id = draft.logoAssetId;
        await createSatellite(body);
      } else {
        const body: SatellitePatch = {};
        if (draft.nameAr !== baseline.nameAr) body.name_ar = draft.nameAr.trim();
        if (draft.nameEn !== baseline.nameEn) body.name_en = draft.nameEn.trim();
        if (JSON.stringify({ p: position }) !== JSON.stringify({ p: orbitalPosition(baseline) })) {
          body.orbital_position = position;
        }
        if (JSON.stringify(best) !== JSON.stringify(frequencyOrNull(baseline.hasBest, baseline.best))) {
          body.best_frequency = best;
        }
        if (JSON.stringify(worst) !== JSON.stringify(frequencyOrNull(baseline.hasWorst, baseline.worst))) {
          body.worst_frequency = worst;
        }
        if (draft.receptionUrl !== baseline.receptionUrl) {
          body.reception_url = draft.receptionUrl.trim() === '' ? null : draft.receptionUrl.trim();
        }
        if (draft.logoAssetId !== baseline.logoAssetId) body.logo_asset_id = draft.logoAssetId;
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchSatellite(satelliteId, body, { headers: serverEtag ? { 'If-Match': serverEtag } : {} });
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

  return (
    <>
      <EditorDrawer
        open={open}
        title={satelliteId === null ? copy.editor.newTitle : copy.editor.title}
        subtitle={
          satelliteId === null
            ? null
            : [server?.name_ar, formatPosition(server?.orbital_position ?? null)].filter(Boolean).join(' · ')
        }
        formLabel={satelliteId === null ? copy.editor.newTitle : copy.editor.title}
        saving={busy}
        saveError={saveError}
        onSave={() => void save()}
        onClose={requestClose}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Field
            label={copy.editor.nameAr}
            value={draft.nameAr}
            onChange={(event) => setDraft((current) => ({ ...current, nameAr: event.target.value }))}
          />
          <Field
            label={copy.editor.nameEn}
            value={draft.nameEn}
            onChange={(event) => setDraft((current) => ({ ...current, nameEn: event.target.value }))}
            ltr
          />
        </div>

        <fieldset className="flex flex-col gap-2">
          <legend className="text-caption font-semibold text-text-secondary">{copy.editor.position}</legend>
          <div className="flex items-center gap-2">
            <Field
              label={copy.editor.degree}
              value={draft.degree}
              onChange={(event) =>
                setDraft((current) => ({ ...current, degree: event.target.value.replace(/[^0-9.]/g, '') }))
              }
              ltr
              mono
            />
            <div role="radiogroup" aria-label={copy.editor.position} className="flex flex-none gap-1 rounded-lg bg-bg p-1">
              {(['E', 'W'] as const).map((direction) => (
                <button
                  key={direction}
                  type="button"
                  role="radio"
                  aria-checked={draft.direction === direction}
                  onClick={() => setDraft((current) => ({ ...current, direction }))}
                  className={`text-label size-12 rounded-sm font-mono font-semibold ${
                    draft.direction === direction
                      ? 'bg-text-primary text-text-on-inverse'
                      : 'text-text-secondary hover:bg-surface-2'
                  }`}
                >
                  {direction}
                </button>
              ))}
            </div>
          </div>
          <span className="text-caption text-text-tertiary">
            {copy.editor.positionHint(String(orbitalPosition(draft) ?? 0))}
          </span>
        </fieldset>

        <div className="flex flex-col gap-2 rounded-lg bg-bg p-3">
          <label className="text-label flex items-center gap-2 text-text-primary">
            <input
              type="checkbox"
              checked={draft.hasBest}
              onChange={(event) => setDraft((current) => ({ ...current, hasBest: event.target.checked }))}
              className="size-4 accent-accent"
            />
            {copy.editor.bestFrequency}
          </label>
          {draft.hasBest ? (
            <FrequencyField
              label={copy.editor.bestFrequency}
              icon="signal"
              value={draft.best}
              onChange={(best) => setDraft((current) => ({ ...current, best }))}
            />
          ) : null}
        </div>

        <div className="flex flex-col gap-2 rounded-lg bg-bg p-3">
          <label className="text-label flex items-center gap-2 text-text-primary">
            <input
              type="checkbox"
              checked={draft.hasWorst}
              onChange={(event) => setDraft((current) => ({ ...current, hasWorst: event.target.checked }))}
              className="size-4 accent-accent"
            />
            {copy.editor.worstFrequency}
          </label>
          {draft.hasWorst ? (
            <FrequencyField
              label={copy.editor.worstFrequency}
              icon="signal"
              value={draft.worst}
              onChange={(worst) => setDraft((current) => ({ ...current, worst }))}
            />
          ) : null}
        </div>

        <Field
          label={copy.editor.reception}
          value={draft.receptionUrl}
          onChange={(event) => setDraft((current) => ({ ...current, receptionUrl: event.target.value }))}
          ltr
          error={receptionInvalid ? copy.editor.receptionInvalid : undefined}
          hint={copy.editor.receptionHint}
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

function frequencyOrNull(has: boolean, value: FrequencyValue): Frequency | null {
  return has && frequencyFilled(value) ? frequencyBody(value) : null;
}
