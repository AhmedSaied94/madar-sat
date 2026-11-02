import { zodResolver } from '@hookform/resolvers/zod';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { Controller, useForm, type Resolver } from 'react-hook-form';
import { z } from 'zod';

import { createSatellite, patchSatellite, useGetSatellite } from '../../api/generated/admin';
import type { AdminSatellite, Frequency, SatelliteCreate, SatellitePatch } from '../../api/generated/admin.schemas';
import {
  createSatelliteBody,
  createSatelliteBodyOrbitalPositionMaxOne,
  createSatelliteBodyReceptionUrlRegExpOne,
  createSatelliteBodySlugRegExp,
} from '../../api/generated/admin.zod';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { FrequencyField, type FrequencyValue } from '../../components/FrequencyField/FrequencyField';
import { LogoField } from '../../components/LogoField/LogoField';
import { useToast } from '../../components/Toast/Toast';
import { common, copyForErrorCode, logoPreview, satellites as copy, toast as toastCopy, validation } from '../../i18n/ar';
import { editorConflict, type ConflictField, type EditorConflict } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import '../../lib/validation';

// A7's editor (admin board "Satellites"): the two names, the orbital position stored as "east
// positive", the best and worst frequency, the reception clip and the logo. The position, the
// frequencies, the https-only reception link and the slug are the fields the app and the API read,
// so they are validated here by the created body's own Zod schema (constitution VIII), and a stale
// save opens the conflict dialog instead of overwriting (A-R1-2).

const emptyFrequency = (): FrequencyValue => ({ mhz: '', pol: 'H', sr: '' });

const toValue = (frequency: Frequency | null): FrequencyValue =>
  frequency === null ? emptyFrequency() : { mhz: String(frequency.mhz), pol: frequency.pol, sr: String(frequency.sr) };

export function frequencyBody(value: FrequencyValue): Frequency {
  return { mhz: Number(value.mhz), pol: value.pol, sr: Number(value.sr) };
}

export const frequencyFilled = (value: FrequencyValue): boolean => value.mhz !== '' && value.sr !== '';

/** A slug the API accepts, derived from the English name (the field the board doesn't show). */
export function slugOf(nameEn: string): string {
  return nameEn
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

const frequencyShape = z.object({
  mhz: z.string(),
  pol: z.enum(['H', 'V', 'L', 'R']),
  sr: z.string(),
});

const formSchema = z
  .object({
    nameAr: createSatelliteBody.shape.name_ar.trim().min(1, validation.required),
    nameEn: createSatelliteBody.shape.name_en
      .trim()
      .min(1, validation.required)
      // The API derives nothing here: the slug it stores must be a slug, and it comes from this name.
      .refine((value) => createSatelliteBodySlugRegExp.test(slugOf(value)), validation.invalid),
    degree: z
      .string()
      .refine((value) => value.trim() === '' || Number.isFinite(Number(value)), validation.number)
      .refine(
        (value) => value.trim() === '' || Math.abs(Number(value)) <= createSatelliteBodyOrbitalPositionMaxOne,
        validation.position,
      ),
    direction: z.enum(['E', 'W']),
    best: frequencyShape,
    hasBest: z.boolean(),
    worst: frequencyShape,
    hasWorst: z.boolean(),
    receptionUrl: z
      .string()
      .refine(
        (value) => value.trim() === '' || createSatelliteBodyReceptionUrlRegExpOne.test(value.trim()),
        copy.editor.receptionInvalid,
      ),
    logoAssetId: z.number().nullable(),
    logoUrl: z.string().nullable(),
  })
  .superRefine((draft, ctx) => {
    // Ticked «أقوى تردد» with half a tuning would save as "no frequency" silently.
    if (draft.hasBest && !frequencyFilled(draft.best)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['best', 'mhz'], message: validation.frequencyRequired });
    }
    if (draft.hasWorst && !frequencyFilled(draft.worst)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['worst', 'mhz'], message: validation.frequencyRequired });
    }
  });

export type SatelliteDraft = z.infer<typeof formSchema>;

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

  const form = useForm<SatelliteDraft>({
    resolver: zodResolver(formSchema) as Resolver<SatelliteDraft>,
    defaultValues: emptyDraft(),
    mode: 'onSubmit',
  });
  const { register, handleSubmit, formState, watch, reset, setValue, control } = form;

  const [baseline, setBaseline] = useState<SatelliteDraft>(emptyDraft);
  /** The version the baseline was read at; it never follows the live refetch. */
  const [baselineEtag, setBaselineEtag] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<EditorConflict<SatelliteDraft> | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const seeded = useRef<string | null>(null);

  const draft = watch();
  const server = detail.data?.data;

  const adopt = useCallback(
    (next: SatelliteDraft, etag: string | null) => {
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
    if (satelliteId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      adopt(emptyDraft(), null);
      setSaveError(null);
      return;
    }
    if (!server || seeded.current === `sat-${satelliteId}`) return;
    seeded.current = `sat-${satelliteId}`;
    adopt(fromSatellite(server), etagOf(detail.data));
    setSaveError(null);
  }, [open, satelliteId, server, detail.data, adopt]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);
  const frequencyText = (value: FrequencyValue): string | null =>
    frequencyFilled(value) ? `${value.mhz} ${value.pol} ${value.sr}` : null;

  const fields: readonly ConflictField<SatelliteDraft>[] = [
    { key: 'nameAr', label: copy.editor.nameAr, text: (value) => (value.nameAr.trim() === '' ? null : value.nameAr.trim()) },
    { key: 'nameEn', label: copy.editor.nameEn, text: (value) => (value.nameEn.trim() === '' ? null : value.nameEn.trim()) },
    { key: 'orbitalPosition', label: copy.editor.position, text: (value) => formatPosition(orbitalPosition(value)) },
    {
      key: 'best',
      label: copy.editor.bestFrequency,
      text: (value) => (value.hasBest ? frequencyText(value.best) : null),
    },
    {
      key: 'worst',
      label: copy.editor.worstFrequency,
      text: (value) => (value.hasWorst ? frequencyText(value.worst) : null),
    },
    { key: 'receptionUrl', label: copy.editor.reception, text: (value) => (value.receptionUrl.trim() === '' ? null : value.receptionUrl.trim()) },
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

  async function submit(parsed: SatelliteDraft): Promise<void> {
    if (conflict) return;
    setSaveError(null);
    const position = orbitalPosition(parsed);
    const best = parsed.hasBest && frequencyFilled(parsed.best) ? frequencyBody(parsed.best) : null;
    const worst = parsed.hasWorst && frequencyFilled(parsed.worst) ? frequencyBody(parsed.worst) : null;

    setBusy(true);
    try {
      if (satelliteId === null) {
        const body: SatelliteCreate = {
          name_ar: parsed.nameAr,
          name_en: parsed.nameEn,
          slug: slugOf(parsed.nameEn),
        };
        if (position !== null) body.orbital_position = position;
        if (best) body.best_frequency = best;
        if (worst) body.worst_frequency = worst;
        if (parsed.receptionUrl.trim() !== '') body.reception_url = parsed.receptionUrl.trim();
        if (parsed.logoAssetId !== null) body.logo_asset_id = parsed.logoAssetId;
        await createSatellite(body);
      } else {
        const body: SatellitePatch = {};
        if (parsed.nameAr !== baseline.nameAr) body.name_ar = parsed.nameAr;
        if (parsed.nameEn !== baseline.nameEn) body.name_en = parsed.nameEn;
        if (JSON.stringify({ p: position }) !== JSON.stringify({ p: orbitalPosition(baseline) })) {
          body.orbital_position = position;
        }
        if (JSON.stringify(best) !== JSON.stringify(baselineFrequency(baseline.hasBest, baseline.best))) {
          body.best_frequency = best;
        }
        if (JSON.stringify(worst) !== JSON.stringify(baselineFrequency(baseline.hasWorst, baseline.worst))) {
          body.worst_frequency = worst;
        }
        if (parsed.receptionUrl !== baseline.receptionUrl) {
          body.reception_url = parsed.receptionUrl.trim() === '' ? null : parsed.receptionUrl.trim();
        }
        if (parsed.logoAssetId !== baseline.logoAssetId) body.logo_asset_id = parsed.logoAssetId;
        if (Object.keys(body).length === 0) {
          onClose();
          return;
        }
        await patchSatellite(satelliteId, body, { headers: baselineEtag ? { 'If-Match': baselineEtag } : {} });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict' && satelliteId !== null) await openConflict(failure);
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
    setConflict(editorConflict(failure, fields, baseline, fromSatellite(current), etagOf(refreshed.data)));
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
        onSave={() => void handleSubmit(submit)()}
        onClose={requestClose}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={copy.editor.nameAr} error={formState.errors.nameAr?.message} {...register('nameAr')} />
          <Field label={copy.editor.nameEn} ltr error={formState.errors.nameEn?.message} {...register('nameEn')} />
        </div>

        <fieldset className="flex flex-col gap-2">
          <legend className="text-caption font-semibold text-text-secondary">{copy.editor.position}</legend>
          <div className="flex items-center gap-2">
            <Controller
              control={control}
              name="degree"
              render={({ field, fieldState }) => (
                <Field
                  label={copy.editor.degree}
                  ltr
                  mono
                  name={field.name}
                  ref={field.ref}
                  value={field.value}
                  onBlur={field.onBlur}
                  error={fieldState.error?.message}
                  // Only digits and the decimal point reach the draft, so «7..5» can be refused instead
                  // of quietly stored as no position at all.
                  onChange={(event) => field.onChange(event.target.value.replace(/[^0-9.]/g, ''))}
                />
              )}
            />
            <div role="radiogroup" aria-label={copy.editor.position} className="flex flex-none gap-1 rounded-lg bg-bg p-1">
              {(['E', 'W'] as const).map((direction) => (
                <button
                  key={direction}
                  type="button"
                  role="radio"
                  aria-checked={draft.direction === direction}
                  onClick={() => setValue('direction', direction, { shouldDirty: true })}
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
              onChange={(event) => setValue('hasBest', event.target.checked, { shouldDirty: true })}
              className="size-4 accent-accent"
            />
            {copy.editor.bestFrequency}
          </label>
          {draft.hasBest ? (
            <FrequencyField
              label={copy.editor.bestFrequency}
              icon="signal"
              value={draft.best}
              onChange={(best) => setValue('best', best, { shouldDirty: true })}
              error={formState.errors.best?.mhz?.message}
            />
          ) : null}
        </div>

        <div className="flex flex-col gap-2 rounded-lg bg-bg p-3">
          <label className="text-label flex items-center gap-2 text-text-primary">
            <input
              type="checkbox"
              checked={draft.hasWorst}
              onChange={(event) => setValue('hasWorst', event.target.checked, { shouldDirty: true })}
              className="size-4 accent-accent"
            />
            {copy.editor.worstFrequency}
          </label>
          {draft.hasWorst ? (
            <FrequencyField
              label={copy.editor.worstFrequency}
              icon="signal"
              value={draft.worst}
              onChange={(worst) => setValue('worst', worst, { shouldDirty: true })}
              error={formState.errors.worst?.mhz?.message}
            />
          ) : null}
        </div>

        <Field
          label={copy.editor.reception}
          ltr
          error={formState.errors.receptionUrl?.message}
          hint={copy.editor.receptionHint}
          {...register('receptionUrl')}
        />

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
        subject={draft.nameAr}
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: '' }}
        changes={conflict?.changes ?? []}
        onReload={() => {
          if (!conflict) return;
          adopt(conflict.theirs, conflict.etag);
          seeded.current = `sat-${satelliteId ?? 'new'}`;
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

function baselineFrequency(has: boolean, value: FrequencyValue): Frequency | null {
  return has && frequencyFilled(value) ? frequencyBody(value) : null;
}
