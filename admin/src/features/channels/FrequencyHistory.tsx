import type { ReactElement } from 'react';

import type { FrequencyHistoryRow, Polarization } from '../../api/generated/admin.schemas';
import { FrequencyReadout, type ReadoutFrequency } from '../../components/FrequencyReadout/FrequencyReadout';
import { Icon } from '../../components/Icon/Icon';
import { formatCairoClock } from '../../lib/cairoTime';
import { audit as auditCopy, frequencyHistory as copy } from '../../i18n/ar';
import { useFrequencyChanges } from './queries';

// A8's «سجل التردد» (contract admin-screens "A8: frequency history", board "Channels"): the last
// changes under the frequency, in edit mode only, each readout dark and LTR — the board's
// «20 أكتوبر · 11766 H → 11013 H · محمد علي».

const POLARIZATIONS = new Set(['H', 'V', 'L', 'R']);

/** `«11766 H 27500»` as the components `FrequencyReadout` draws; null when it isn't a tuning. */
export function parseReadout(text: string): ReadoutFrequency | null {
  const parts = text.trim().split(/\s+/);
  if (parts.length !== 3) return null;
  const [mhz, pol, sr] = parts as [string, string, string];
  if (!POLARIZATIONS.has(pol) || Number.isNaN(Number(mhz)) || Number.isNaN(Number(sr))) return null;
  return { mhz: Number(mhz), pol: pol as Polarization, sr: Number(sr) };
}

/** `20 أكتوبر`, in Cairo's zone and Western digits — the board's day, not a clock time. */
function day(instant: string): string {
  return new Intl.DateTimeFormat('ar-EG-u-nu-latn', {
    timeZone: 'Africa/Cairo',
    day: 'numeric',
    month: 'long',
  }).format(new Date(instant));
}

function Row({ change }: { change: FrequencyHistoryRow }): ReactElement {
  const before = parseReadout(change.old);
  const after = parseReadout(change.new);
  return (
    <li data-history-id={change.id} className="text-caption flex flex-wrap items-center gap-2 text-text-secondary">
      <span className="rounded-xs bg-surface-2 px-2 py-1 text-text-tertiary">{day(change.detected_at)}</span>
      <FrequencyReadout frequency={before} text={change.old} />
      <Icon name="link" size="sm" className="text-text-tertiary" />
      <FrequencyReadout frequency={after} text={change.new} />
      <span className="text-text-tertiary">· {change.actor ?? auditCopy.actor.importer}</span>
      <span className="text-micro ms-auto text-text-tertiary">{formatCairoClock(change.detected_at).time}</span>
    </li>
  );
}

export function FrequencyHistory({ channelId }: { channelId: number }): ReactElement {
  const history = useFrequencyChanges(channelId);
  const rows = history.data?.data ?? [];

  return (
    <section aria-label={copy.title} className="flex min-w-0 flex-col gap-2">
      <h3 className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
        <Icon name="history" size="sm" />
        {copy.title}
      </h3>
      {history.isPending ? null : rows.length === 0 ? (
        <p className="text-caption text-text-tertiary">{copy.empty}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((change) => (
            <Row key={change.id} change={change} />
          ))}
        </ul>
      )}
    </section>
  );
}
