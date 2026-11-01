import { clsx } from 'clsx';
import type { ReactElement } from 'react';

import type { Polarization } from '../../api/generated/admin.schemas';
import { readout } from '../../i18n/ar';

// FrequencyReadout (design-system README): the equipment-style display of a tuning, or of a bare
// readout such as a satellite's orbital position. It is a display, not a surface, so it keeps the
// dark well and the cyan mono digits in the light theme too, and it is always LTR (constitution IV).

export type ReadoutSize = 'default' | 'lg' | 'xl';

export interface ReadoutFrequency {
  mhz: number;
  pol: Polarization;
  sr: number;
}

interface FrequencyReadoutProps {
  /** The tuning values; leave out when the well shows a bare value. */
  frequency?: ReadoutFrequency | null;
  /** What the well shows instead of a tuning, e.g. A7's «7.0W». */
  text?: string;
  size?: ReadoutSize;
  className?: string;
}

const wellHeight: Record<ReadoutSize, string> = {
  default: 'h-6 px-2 gap-2',
  lg: 'h-8 px-3 gap-2',
  xl: 'h-12 px-4 gap-3',
};

const typeStyle: Record<ReadoutSize, string> = {
  default: 'readout',
  lg: 'readout-lg',
  xl: 'readout-xl',
};

export function FrequencyReadout({
  frequency = null,
  text,
  size = 'default',
  className,
}: FrequencyReadoutProps): ReactElement {
  const polarization = frequency ? (readout.polarizations[frequency.pol] ?? frequency.pol) : null;
  const label = frequency
    ? readout.spoken(frequency.mhz, polarization ?? '', frequency.sr)
    : text;

  return (
    <span
      dir="ltr"
      data-testid="frequency-readout"
      data-size={size}
      role="img"
      aria-label={label}
      className={clsx(
        'readout-glow inline-flex flex-none items-center whitespace-nowrap rounded-sm bg-readout-bg text-readout ring-1 ring-inset ring-readout-line',
        wellHeight[size],
        typeStyle[size],
        className,
      )}
    >
      {frequency ? (
        <>
          <span className="tabular">{frequency.mhz}</span>
          <span
            aria-hidden="true"
            className="text-micro inline-flex items-center justify-center rounded-xs px-1 ring-1 ring-inset ring-readout-line"
          >
            {frequency.pol}
          </span>
          <span className="text-readout-dim readout-dim tabular">{frequency.sr}</span>
        </>
      ) : (
        <span className="tabular">{text}</span>
      )}
    </span>
  );
}
