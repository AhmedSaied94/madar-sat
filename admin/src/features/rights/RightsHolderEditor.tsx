import { clsx } from 'clsx';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { useFieldArray, useForm } from 'react-hook-form';

import { createRightsHolder, patchRightsHolder, useGetRightsHolder } from '../../api/generated/admin';
import type {
  Access,
  AdminRightsHolder,
  Beam,
  RightsHolderCreate,
  RightsHolderPatch,
} from '../../api/generated/admin.schemas';
import { createRightsHolderBody } from '../../api/generated/admin.zod';
import { ApiError, NETWORK_ERROR, etagOf } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { FrequencyField, type FrequencyValue } from '../../components/FrequencyField/FrequencyField';
import { Icon } from '../../components/Icon/Icon';
import { LogoField } from '../../components/LogoField/LogoField';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { common, copyForErrorCode, logoPreview, rights as copy, toast as toastCopy } from '../../i18n/ar';
import { editorConflict, type ConflictField, type EditorConflict } from '../../lib/conflict';
import { uploadAsset } from '../../lib/media';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { useSatelliteOptions } from '../channels/queries';
import { useCompetitionOptions } from '../teams/queries';

// A9's editor (admin board "Rights", right pane): the name, the logo, the competitions it covers and
// its carriages, each with its satellites, access, beam, package and frequencies. The generated schema
// checks the body; the one-primary rule of `admin-api` §A9 is added on top, because no index enforces
// it. Each save goes under the version the form was seeded from, so a stale copy gets the conflict dialog.

/** One frequency as the editor holds it: the strings the fields carry, plus the primary mark. */
export interface FrequencyDraft extends FrequencyValue {
  primary: boolean;
}

export interface CarriageDraft {
  satelliteIds: number[];
  access: Access;
  beam: Beam | '';
  package: string;
  frequencies: FrequencyDraft[];
}

export interface RightsHolderDraft {
  name: string;
  logoAssetId: number | null;
  logoUrl: string | null;
  competitionIds: number[];
  carriages: CarriageDraft[];
}

/**
 * `admin-api` §A9: a carriage with frequencies has exactly one primary. The rest of the body is the
 * generated schema, unedited.
 */
export const rightsHolderBodySchema = createRightsHolderBody.superRefine((body, context) => {
  body.carriages.forEach((carriage, index) => {
    const primaries = carriage.frequencies.filter((frequency) => frequency.is_primary).length;
    if (carriage.frequencies.length > 0 && primaries !== 1) {
      context.addIssue({ code: 'custom', path: ['carriages', index], message: copy.primaryRequired });
    }
  });
});

export const emptyDraft = (): RightsHolderDraft => ({
  name: '',
  logoAssetId: null,
  logoUrl: null,
  competitionIds: [],
  carriages: [],
});

const emptyCarriage = (): CarriageDraft => ({
  satelliteIds: [],
  access: 'free',
  beam: '',
  package: '',
  frequencies: [],
});

const emptyFrequency = (): FrequencyDraft => ({ mhz: '', pol: 'H', sr: '', primary: false });

/** The record as the editor shows it. */
export function draftOf(holder: AdminRightsHolder): RightsHolderDraft {
  return {
    name: holder.name,
    logoAssetId: holder.logo_asset_id,
    logoUrl: holder.logo,
    competitionIds: [...holder.competition_ids],
    carriages: holder.carriages.map((carriage) => ({
      satelliteIds: [...carriage.satellite_ids],
      access: carriage.access,
      beam: carriage.beam ?? '',
      package: carriage.package ?? '',
      frequencies: carriage.frequencies.map((frequency) => ({
        mhz: String(frequency.frequency_mhz),
        pol: frequency.polarization,
        sr: String(frequency.symbol_rate),
        primary: frequency.is_primary,
      })),
    })),
  };
}

/**
 * The wire body: empty fields are left out, and the numbers are parsed from the fields. The logo goes
 * only when it differs from `savedLogoAssetId`, and `null` then clears it.
 */
export function bodyOf(draft: RightsHolderDraft, savedLogoAssetId: number | null): unknown {
  return {
    name: draft.name.trim(),
    ...(draft.logoAssetId === savedLogoAssetId ? {} : { logo_asset_id: draft.logoAssetId }),
    competition_ids: draft.competitionIds,
    carriages: draft.carriages.map((carriage) => ({
      access: carriage.access,
      beam: carriage.beam === '' ? null : carriage.beam,
      package: carriage.package.trim() === '' ? null : carriage.package.trim(),
      satellite_ids: carriage.satelliteIds,
      frequencies: carriage.frequencies.map((frequency) => ({
        frequency_mhz: Number(frequency.mhz),
        polarization: frequency.pol,
        symbol_rate: Number(frequency.sr),
        is_primary: frequency.primary,
      })),
    })),
  };
}

interface CheckboxChipsProps {
  legend: string;
  options: readonly { id: number; label: string }[];
  selected: readonly number[];
  onChange: (next: number[]) => void;
}

/** A multi-select of ids. An id with no option stays selected: only a click ever removes one. */
function CheckboxChips({ legend, options, selected, onChange }: CheckboxChipsProps): ReactElement {
  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="text-caption font-semibold text-text-secondary">{legend}</legend>
      <div className="flex flex-wrap gap-2">
        {options.map((option) => (
          <label
            key={option.id}
            className={clsx('text-caption flex items-center gap-2 rounded-md bg-surface-2 px-2 py-1', focusRing)}
          >
            <input
              type="checkbox"
              checked={selected.includes(option.id)}
              onChange={(event) =>
                onChange(
                  event.target.checked ? [...selected, option.id] : selected.filter((value) => value !== option.id),
                )
              }
              className="size-4 accent-accent"
            />
            <bdi className="text-text-primary">{option.label}</bdi>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

interface RightsHolderEditorProps {
  holderId: number | null;
  open: boolean;
  onClose: () => void;
}

export function RightsHolderEditor({ holderId, open, onClose }: RightsHolderEditorProps): ReactElement {
  const detail = useGetRightsHolder(holderId ?? 0, {
    query: { enabled: open && holderId !== null, structuralSharing: false },
  });
  const competitions = useCompetitionOptions();
  const satellites = useSatelliteOptions();
  const refresh = useRefreshAdmin();
  const toast = useToast();

  const form = useForm<RightsHolderDraft>({ defaultValues: emptyDraft(), mode: 'onSubmit' });
  const { register, control, handleSubmit, watch, reset, setValue } = form;
  const carriages = useFieldArray({ control, name: 'carriages' });
  const [baseline, setBaseline] = useState<RightsHolderDraft>(emptyDraft);
  /** The version the baseline was read at. It travels with the draft, never from the live refetch. */
  const [baselineEtag, setBaselineEtag] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<EditorConflict<RightsHolderDraft> | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [saving, setSaving] = useState(false);
  const seeded = useRef<string | null>(null);

  const draft = watch();
  const holder = detail.data?.data ?? null;

  const adopt = useCallback(
    (next: RightsHolderDraft, etag: string | null) => {
      setBaseline(next);
      setBaselineEtag(etag);
      reset(next);
    },
    [reset],
  );

  // The form is seeded once per opening: a detail refetch must never overwrite what is being typed.
  // A reopening waits for its read, because the cached copy may be the version this editor just replaced.
  useEffect(() => {
    if (!open) {
      seeded.current = null;
      return;
    }
    if (holderId === null) {
      if (seeded.current === 'new') return;
      seeded.current = 'new';
      adopt(emptyDraft(), null);
      setSaveError(null);
      return;
    }
    if (holder === null || detail.isFetching || seeded.current === `holder-${holderId}`) return;
    seeded.current = `holder-${holderId}`;
    adopt(draftOf(holder), etagOf(detail.data));
    setSaveError(null);
  }, [open, holderId, holder, detail.data, detail.isFetching, adopt]);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(baseline), [baseline, draft]);

  const satelliteName = (id: number): string =>
    satellites.find((satellite) => satellite.id === id)?.name_ar ?? String(id);
  const competitionName = (id: number): string =>
    competitions.find((competition) => competition.id === id)?.name ?? String(id);

  const fields: readonly ConflictField<RightsHolderDraft>[] = [
    { key: 'name', label: copy.name, text: (value) => (value.name.trim() === '' ? null : value.name.trim()) },
    { key: 'logo_asset_id', label: copy.logo, text: (value) => value.logoUrl },
    {
      key: 'competition_ids',
      label: copy.competitions,
      text: (value) => (value.competitionIds.length === 0 ? null : value.competitionIds.map(competitionName).join('، ')),
    },
    {
      key: 'carriages',
      label: copy.carriages,
      text: (value) =>
        value.carriages.length === 0
          ? null
          : value.carriages
              .map((carriage) =>
                [
                  carriage.satelliteIds.map(satelliteName).join('، '),
                  copy.access[carriage.access],
                  carriage.package,
                  ...carriage.frequencies.map((frequency) => `${frequency.mhz} ${frequency.pol} ${frequency.sr}`),
                ]
                  .filter((part) => part !== '')
                  .join(' · '),
              )
              .join(' / '),
    },
  ];

  function requestClose(): void {
    if (dirty) setLeaving(true);
    else onClose();
  }

  async function uploadLogo(file: File): Promise<void> {
    setSaving(true);
    setSaveError(null);
    try {
      const asset = await uploadAsset(file, 'image');
      setValue('logoAssetId', asset.id, { shouldDirty: true });
      setValue('logoUrl', asset.url, { shouldDirty: true });
    } catch (error) {
      setSaveError(copyForErrorCode(error instanceof ApiError ? error.code : NETWORK_ERROR));
    } finally {
      setSaving(false);
    }
  }

  function setFrequency(carriageIndex: number, frequencyIndex: number, next: FrequencyDraft): void {
    const current = draft.carriages[carriageIndex];
    if (!current) return;
    const frequencies = current.frequencies.map((frequency, index) =>
      index === frequencyIndex ? next : frequency,
    );
    setValue(`carriages.${carriageIndex}.frequencies`, frequencies, { shouldDirty: true });
  }

  function setPrimary(carriageIndex: number, frequencyIndex: number): void {
    const current = draft.carriages[carriageIndex];
    if (!current) return;
    const frequencies = current.frequencies.map((frequency, index) => ({
      ...frequency,
      primary: index === frequencyIndex,
    }));
    setValue(`carriages.${carriageIndex}.frequencies`, frequencies, { shouldDirty: true });
  }

  async function submit(values: RightsHolderDraft): Promise<void> {
    // An open conflict is answered in its dialog: nothing is re-sent from behind it.
    if (conflict) return;
    setSaveError(null);
    const parsed = rightsHolderBodySchema.safeParse(bodyOf(values, baseline.logoAssetId));
    if (!parsed.success) {
      setSaveError(parsed.error.issues[0]?.message ?? copy.primaryRequired);
      return;
    }
    setSaving(true);
    try {
      if (holderId === null) {
        await createRightsHolder(parsed.data as RightsHolderCreate);
      } else {
        await patchRightsHolder(holderId, parsed.data as RightsHolderPatch, {
          headers: baselineEtag ? { 'If-Match': baselineEtag } : {},
        });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setLeaving(false);
      onClose();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict' && holderId !== null) await openConflict(failure);
    } finally {
      setSaving(false);
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

  const title = holderId === null ? copy.createTitle : copy.editTitle(draft.name);

  return (
    <>
      <EditorDrawer
        open={open}
        title={title}
        subtitle={holderId === null ? null : copy.competitionCount(draft.competitionIds.length)}
        formLabel={title}
        saving={saving || detail.isFetching}
        saveError={saveError}
        onSave={() => void handleSubmit(submit)()}
        onClose={requestClose}
      >
        <div className="flex flex-col gap-4">
          <Field label={copy.name} ltr {...register('name')} />

          <LogoField
            label={copy.logo}
            darkLabel={logoPreview.onDark}
            lightLabel={logoPreview.onLight}
            uploadLabel={copy.logoUpload}
            url={draft.logoUrl}
            onUpload={(file) => void uploadLogo(file)}
            clearLabel={copy.logoRemove}
            onClear={() => {
              setValue('logoAssetId', null, { shouldDirty: true });
              setValue('logoUrl', null, { shouldDirty: true });
            }}
          />

          <CheckboxChips
            legend={copy.competitions}
            options={competitions.map((competition) => ({ id: competition.id, label: competition.name }))}
            selected={draft.competitionIds}
            onChange={(next) => setValue('competitionIds', next, { shouldDirty: true })}
          />

          <div className="flex flex-col gap-3">
            <span className="text-caption font-semibold text-text-secondary">{copy.carriages}</span>
            {carriages.fields.length === 0 ? (
              <span className="text-caption text-text-tertiary">{copy.noCarriages}</span>
            ) : null}

            {carriages.fields.map((field, carriageIndex) => {
              const carriage = draft.carriages[carriageIndex] ?? emptyCarriage();
              return (
                <div
                  key={field.id}
                  data-testid={`carriage-${carriageIndex}`}
                  className="flex flex-col gap-3 rounded-lg bg-bg p-3 ring-1 ring-inset ring-divider"
                >
                  <CheckboxChips
                    legend={copy.satellites}
                    options={satellites.map((satellite) => ({ id: satellite.id, label: satellite.name_ar }))}
                    selected={carriage.satelliteIds}
                    onChange={(next) => setValue(`carriages.${carriageIndex}.satelliteIds`, next, { shouldDirty: true })}
                  />

                  <div className="flex items-end gap-2">
                    <label className="flex flex-col gap-1">
                      <span className="text-caption text-text-secondary">{copy.accessLabel}</span>
                      <select
                        aria-label={copy.accessLabel}
                        value={carriage.access}
                        onChange={(event) =>
                          setValue(`carriages.${carriageIndex}.access`, event.target.value as Access, {
                            shouldDirty: true,
                          })
                        }
                        className={clsx('text-label h-12 rounded-md bg-surface-2 px-2 text-text-primary', focusRing)}
                      >
                        <option value="free">{copy.access['free']}</option>
                        <option value="encrypted">{copy.access['encrypted']}</option>
                      </select>
                    </label>

                    <label className="flex flex-col gap-1">
                      <span className="text-caption text-text-secondary">{copy.beamLabel}</span>
                      <select
                        aria-label={copy.beamLabel}
                        value={carriage.beam}
                        onChange={(event) =>
                          setValue(`carriages.${carriageIndex}.beam`, event.target.value as Beam | '', {
                            shouldDirty: true,
                          })
                        }
                        className={clsx('text-label h-12 rounded-md bg-surface-2 px-2 text-text-primary', focusRing)}
                      >
                        <option value="">—</option>
                        <option value="wide">{copy.beam['wide']}</option>
                        <option value="narrow">{copy.beam['narrow']}</option>
                      </select>
                    </label>

                    <Button
                      variant="danger"
                      size="xs"
                      aria-label={`${copy.removeCarriage} ${carriageIndex + 1}`}
                      onClick={() => carriages.remove(carriageIndex)}
                    >
                      <Icon name="trash" size="sm" />
                    </Button>
                  </div>

                  <Field label={copy.packageLabel} {...register(`carriages.${carriageIndex}.package`)} />

                  <div className="flex flex-col gap-2">
                    {carriage.frequencies.map((frequency, frequencyIndex) => (
                      <div key={frequencyIndex} className="flex items-end gap-2">
                        <div className="min-w-0 flex-1">
                          <FrequencyField
                            label={copy.frequency}
                            value={frequency}
                            onChange={(next) => setFrequency(carriageIndex, frequencyIndex, { ...frequency, ...next })}
                          />
                        </div>
                        <label className={clsx('text-caption flex items-center gap-2 p-2', focusRing)}>
                          <input
                            type="radio"
                            name={`primary-${carriageIndex}`}
                            aria-label={copy.primaryLabel}
                            checked={frequency.primary}
                            onChange={() => setPrimary(carriageIndex, frequencyIndex)}
                            className="size-4 accent-accent"
                          />
                          {copy.primary}
                        </label>
                        <Button
                          variant="ghost"
                          size="xs"
                          aria-label={`${copy.removeFrequency} ${frequencyIndex + 1}`}
                          onClick={() => {
                            const frequencies = carriage.frequencies.filter((_, index) => index !== frequencyIndex);
                            setValue(`carriages.${carriageIndex}.frequencies`, frequencies, { shouldDirty: true });
                          }}
                        >
                          <Icon name="trash" size="sm" />
                        </Button>
                      </div>
                    ))}
                    <Button
                      variant="ghost"
                      size="xs"
                      onClick={() => {
                        const frequencies = [...carriage.frequencies, emptyFrequency()];
                        setValue(`carriages.${carriageIndex}.frequencies`, frequencies, { shouldDirty: true });
                      }}
                    >
                      <Icon name="plus" size="sm" />
                      {copy.addFrequency}
                    </Button>
                  </div>
                </div>
              );
            })}

            <Button variant="secondary" size="sm" onClick={() => carriages.append(emptyCarriage())}>
              <Icon name="plus" size="sm" />
              {copy.addSatellite}
            </Button>
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
        body={copy.unsavedBody}
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
