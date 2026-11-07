import { useMemo, useState, type ReactElement } from 'react';

import { useListMatches } from '../../api/generated/admin';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { notifications as copy } from '../../i18n/ar';

// A15's match picker (contract admin-screens "Composer"): the composer needs two of them — one for the
// audience «متابعو هذه المباراة» and one for the deep link «يفتح» — so it is built once. Inline mode
// draws the list straight away (an audience is a choice, not a search); with a `trigger` it opens on
// the button, because the deep link is optional. The day's window is the list's own: eight days, as the
// contract's `from`/`to` allow.

export interface PickedMatch {
  id: number;
  label: string;
  route: string;
}

interface MatchPickerProps {
  /** Shown as the button that opens the list. Left out for the inline audience picker. */
  trigger?: string;
  onPick: (match: PickedMatch) => void;
}

const MAX_SHOWN = 8;
const WINDOW_DAYS = 7;

const isoDay = (offset: number): string => {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
};

export function MatchPicker({ trigger, onPick }: MatchPickerProps): ReactElement {
  const [open, setOpen] = useState(trigger === undefined);
  const from = useMemo(() => isoDay(-1), []);
  const to = useMemo(() => isoDay(WINDOW_DAYS), []);
  const { data, isFetching } = useListMatches({ from, to });
  const matches = useMemo(() => (data?.data ?? []).slice(0, MAX_SHOWN), [data]);

  function pick(match: (typeof matches)[number]): void {
    const label = `${match.home.name} × ${match.away.name}`;
    onPick({ id: match.id, label, route: `/match/${match.id}` });
    if (trigger !== undefined) setOpen(false);
  }

  return (
    <div className="flex min-w-0 flex-col gap-2">
      {trigger === undefined ? null : (
        <button
          type="button"
          aria-expanded={open}
          onClick={() => setOpen((current) => !current)}
          className={`text-label inline-flex h-8 items-center gap-2 self-start rounded-md bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3 ${focusRing}`}
        >
          <Icon name="ball" size="sm" />
          {trigger}
        </button>
      )}

      {open ? (
        <ul aria-label={copy.composer.chooseMatch} className="flex flex-col divide-y divide-divider">
          {isFetching && matches.length === 0 ? (
            <li className="text-caption py-2 text-text-tertiary">{copy.composer.emptyBody}</li>
          ) : (
            matches.map((match) => (
              <li key={match.id}>
                <button
                  type="button"
                  onClick={() => pick(match)}
                  className={`text-label flex w-full items-center gap-2 py-2 text-start text-text-primary ${focusRing}`}
                >
                  <bdi className="min-w-0 flex-1 truncate">
                    {match.home.name} × {match.away.name}
                  </bdi>
                  <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
                    {match.match_date}
                  </bdi>
                </button>
              </li>
            ))
          )}
        </ul>
      ) : null}
    </div>
  );
}
