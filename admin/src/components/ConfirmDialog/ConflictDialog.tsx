import { useId, useState, type ReactElement, type ReactNode } from 'react';

import { formatCairoTime } from '../../lib/cairoTime';
import { dialogs } from '../../i18n/ar';
import { Button } from '../Button/Button';
import { Icon } from '../Icon/Icon';
import { Modal } from './Modal';
import { DiffView, type ConflictChange } from './DiffView';

// A 409 edit_conflict (contract admin-api D2): who saved first, what their version changed, and the
// two ways out — reload their version into the form, or drop my own edits. Nothing is re-sent blind.
// The diff itself is `DiffView`'s, so A17 shows the same changes in its قبل / بعد columns.

export type { ConflictChange };

export interface ConflictParty {
  kind: 'admin' | 'source';
  name: string;
  /** ISO instant of their save. */
  at: string;
}

interface ConflictDialogProps {
  open: boolean;
  /** What was being edited: «ميلان × بولونيا», with each Latin name in its own direction island. */
  subject: ReactNode;
  changedBy: ConflictParty;
  changes: readonly ConflictChange[];
  onReload: () => void;
  /** «تجاهل تعديلاتي»: the form goes back to the version it loaded. */
  onDiscard: () => void;
  /** Escape, or a click outside: close the dialog and keep the editor's edits (A-R2-6). */
  onDismiss: () => void;
}

export function ConflictDialog({
  open,
  subject,
  changedBy,
  changes,
  onReload,
  onDiscard,
  onDismiss,
}: ConflictDialogProps): ReactElement {
  const headingId = useId();
  const [showing, setShowing] = useState(false);

  const titlePrefix =
    changedBy.kind === 'admin' ? dialogs.conflictTitleAdminPrefix : dialogs.conflictTitleSourcePrefix;

  return (
    <Modal open={open} onClose={onDismiss} labelledBy={headingId}>
      <div className="flex items-start gap-3">
        <span
          aria-hidden="true"
          className="flex size-12 flex-none items-center justify-center rounded-md bg-postponed-container text-postponed"
        >
          <Icon name={changedBy.kind === 'admin' ? 'users' : 'database'} size="lg" />
        </span>
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <h2 id={headingId} className="heading-2 text-text-primary">
            {titlePrefix}{' '}
            <bdi dir={changedBy.kind === 'source' ? 'ltr' : undefined}>{changedBy.name}</bdi>{' '}
            {dialogs.conflictTitleSuffix}
          </h2>
          <p className="text-body text-text-secondary">
            {dialogs.conflictBodyBefore}
            <bdi>{subject}</bdi>
            {/* A missing `meta.changed_at` is said, never replaced with the client's clock (A-R2-7). */}
            {changedBy.at === '' ? dialogs.conflictTimeUnknown : dialogs.conflictBodyAfter(formatCairoTime(changedBy.at))}
          </p>
        </div>
      </div>

      {showing && changes.length > 0 ? (
        <div data-testid="conflict-diff">
          <DiffView changes={changes} layout="stacked" />
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-2">
        <Button variant="ghost" size="sm" onClick={onDiscard}>
          {dialogs.discard}
        </Button>
        <span className="flex-1" />
        {changes.length > 0 ? (
          <Button
            variant="outline"
            size="sm"
            aria-expanded={showing}
            onClick={() => setShowing((current) => !current)}
          >
            {showing ? dialogs.hideChanges : dialogs.showChanges}
          </Button>
        ) : (
          // Nothing the editor can see differs: no toggle that would open an empty list (A-R2-7).
          <span className="text-caption text-text-tertiary">{dialogs.noChanges}</span>
        )}
        <Button size="sm" onClick={onReload}>
          {dialogs.reload}
        </Button>
      </div>
    </Modal>
  );
}
