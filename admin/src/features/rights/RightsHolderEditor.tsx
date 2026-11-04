import { clsx } from 'clsx';
import { useEffect, useState, type ReactElement } from 'react';
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
import { EditorDrawer } from '../../components/EditorDrawer/EditorDrawer';
import { Field } from '../../components/Field/Field';
import { FrequencyField, type FrequencyValue } from '../../components/FrequencyField/FrequencyField';
import { Icon } from '../../components/Icon/Icon';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { copyForErrorCode, rights as copy, toast as toastCopy } from '../../i18n/ar';import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { useSatelliteOptions } from '../channels/queries';
import { useCompetitionOptions } from '../teams/queries';

// A9's editor (admin board "Rights", right pane): the name, the competitions it covers and one
// carriage per satellite with its access, beam, package and frequencies. The generated schema checks
// the body; the one-primary rule of `admin-api` §A9 is added on top, because no index enforces it.

/** One frequency as the editor holds it: the strings the fields carry, plus the primary mark. */
export interface FrequencyDraft extends FrequencyValue {
  primary: boolean;
}

export interface CarriageDraft {
  satelliteId: string;
  access: Access;
  beam: Beam | '';
  package: string;
  frequencies: FrequencyDraft[];
}

export interface RightsHolderDraft {
  name: string;
  competitionIds: number[];
  carriages: CarriageDraft[];
}

/**
 * `admin-api` §A9: a carriage with frequencies has exactly one primary, and names one satellite. The
 * rest of the body is the generated schema, unedited.
 */
export const rightsHolderBodySchema = createRightsHolderBody.superRefine((body, context) => {
  body.carriages.forEach((carriage, index) => {
    const primaries = carriage.frequencies.filter((frequency) => frequency.is_primary).length;
    if (carriage.frequencies.length > 0 && primaries !== 1) {
      context.addIssue({ code: 'custom', path: ['carriages', index], message: copy.primaryRequired });
    }
    if (carriage.satellite_ids.length !== 1) {
      context.addIssue({ code: 'custom', path: ['carriages', index], message: copy.satelliteRequired });
    }
  });
});

export const emptyDraft = (): RightsHolderDraft => ({ name: '', competitionIds: [], carriages: [] });

const emptyCarriage = (): CarriageDraft => ({
  satelliteId: '',
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
    competitionIds: [...holder.competition_ids],
    carriages: holder.carriages.map((carriage) => ({
      satelliteId: carriage.satellite_ids[0] === undefined ? '' : String(carriage.satellite_ids[0]),
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

/** The wire body: empty fields are left out, and the numbers are parsed from the fields. */
export function bodyOf(draft: RightsHolderDraft): unknown {
  return {
    name: draft.name.trim(),
    competition_ids: draft.competitionIds,
    carriages: draft.carriages.map((carriage) => ({
      access: carriage.access,
      beam: carriage.beam === '' ? null : carriage.beam,
      package: carriage.package.trim() === '' ? null : carriage.package.trim(),
      satellite_ids: carriage.satelliteId === '' ? [] : [Number(carriage.satelliteId)],
      frequencies: carriage.frequencies.map((frequency) => ({
        frequency_mhz: Number(frequency.mhz),
        polarization: frequency.pol,
        symbol_rate: Number(frequency.sr),
        is_primary: frequency.primary,
      })),
    })),
  };
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
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const draft = watch();
  const holder = detail.data?.data ?? null;

  // The form is seeded once per opening: a detail refetch must never overwrite what is being typed.
  useEffect(() => {
    if (!open) return;
    if (holderId === null) {
      reset(emptyDraft());
      setSaveError(null);
      return;
    }
    if (holder === null) return;
    reset(draftOf(holder));
    setSaveError(null);
  }, [open, holderId, holder, reset]);

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
    setSaveError(null);
    const parsed = rightsHolderBodySchema.safeParse(bodyOf(values));
    if (!parsed.success) {
      setSaveError(parsed.error.issues[0]?.message ?? copy.primaryRequired);
      return;
    }
    setSaving(true);
    try {
      if (holderId === null) {
        await createRightsHolder(parsed.data as RightsHolderCreate);
      } else {
        const etag = etagOf(detail.data);
        await patchRightsHolder(holderId, parsed.data as RightsHolderPatch, {
          headers: etag ? { 'If-Match': etag } : {},
        });
      }
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      onClose();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : NETWORK_ERROR;
      setSaveError(copyForErrorCode(code));
    } finally {
      setSaving(false);
    }
  }

  const title = holderId === null ? copy.createTitle : copy.editTitle(draft.name);

  return (
    <EditorDrawer
      open={open}
      title={title}
      subtitle={holderId === null ? null : copy.competitionCount(draft.competitionIds.length)}
      formLabel={title}
      saving={saving}
      saveError={saveError}
      onSave={() => void handleSubmit(submit)()}
      onClose={onClose}
    >
      <div className="flex flex-col gap-4">
        <Field label={copy.name} ltr {...register('name')} />

        <fieldset className="flex flex-col gap-2">
          <legend className="text-caption font-semibold text-text-secondary">{copy.competitions}</legend>
          <div className="flex flex-wrap gap-2">
            {competitions.map((competition) => (
              <label
                key={competition.id}
                className={clsx('text-caption flex items-center gap-2 rounded-md bg-surface-2 px-2 py-1', focusRing)}
              >
                <input
                  type="checkbox"
                  value={competition.id}
                  checked={draft.competitionIds.includes(competition.id)}
                  onChange={(event) => {
                    const id = Number(event.target.value);
                    setValue(
                      'competitionIds',
                      event.target.checked
                        ? [...draft.competitionIds, id]
                        : draft.competitionIds.filter((value) => value !== id),
                      { shouldDirty: true },
                    );
                  }}
                  className="size-4 accent-accent"
                />
                <bdi className="text-text-primary">{competition.name}</bdi>
              </label>
            ))}
          </div>
        </fieldset>

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
                <div className="flex items-end gap-2">
                  <label className="flex min-w-0 flex-1 flex-col gap-1">
                    <span className="text-caption text-text-secondary">{copy.satellite}</span>
                    <select
                      aria-label={copy.satellite}
                      value={carriage.satelliteId}
                      onChange={(event) =>
                        setValue(`carriages.${carriageIndex}.satelliteId`, event.target.value, {
                          shouldDirty: true,
                        })
                      }
                      className={clsx('text-label h-12 rounded-md bg-surface-2 px-2 text-text-primary', focusRing)}
                    >
                      <option value="">—</option>
                      {satellites.map((satellite) => (
                        <option key={satellite.id} value={String(satellite.id)}>
                          {satellite.name_ar}
                        </option>
                      ))}
                    </select>
                  </label>

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
  );
}
