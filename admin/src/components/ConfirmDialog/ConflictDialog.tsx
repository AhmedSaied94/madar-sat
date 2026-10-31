import { useId, useState, type ReactElement, type ReactNode } from 'react';

import { formatCairoTime } from '../../lib/cairoTime';
import { dialogs } from '../../i18n/ar';
import { Button } from '../Button/Button';
import { Icon } from '../Icon/Icon';
import { Modal } from './Modal';

// A 409 edit_conflict (contract admin-api D2): who saved first, what their version changed, and the
// two ways out — reload their version into the form, or drop my own edits. Nothing is re-sent blind.

export interface ConflictChange {
  /** The API field name, shown as a mono LTR key. */
  field: string;
  /** Its Arabic label. */
  label: string;
  before: string | null;
  after: string | null;
}

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
}

export function ConflictDialog({
  open,
  subject,
  changedBy,
  changes,
  onReload,
  onDiscard,
}: ConflictDialogProps): ReactElement {
  const headingId = useId();
  const [showing, setShowing] = useState(false);

  const titlePrefix =
    changedBy.kind === 'admin' ? dialogs.conflictTitleAdminPrefix : dialogs.conflictTitleSourcePrefix;

  return (
    <Modal open={open} onClose={onDiscard} labelledBy={headingId}>
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
            {dialogs.conflictBodyAfter(formatCairoTime(changedBy.at))}
          </p>
        </div>
      </div>

      {showing ? (
        <div data-testid="conflict-diff" className="flex flex-col gap-3 rounded-lg bg-bg p-4">
          {changes.map((change) => (
            <div key={change.field} className="flex flex-col gap-1">
              <span className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
                {change.label}
                <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
                  {change.field}
                </bdi>
              </span>
              <p className="text-label rounded-xs bg-error-container px-2 py-1 text-error">
                <span aria-hidden="true" className="me-2 font-mono">
                  −
                </span>
                <bdi data-change="before">{change.before ?? '—'}</bdi>
              </p>
              <p className="text-label rounded-xs bg-free-container px-2 py-1 text-free">
                <span aria-hidden="true" className="me-2 font-mono">
                  +
                </span>
                <bdi data-change="after">{change.after ?? '—'}</bdi>
              </p>
            </div>
          ))}
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-2">
        <Button variant="ghost" size="sm" onClick={onDiscard}>
          {dialogs.discard}
        </Button>
        <span className="flex-1" />
        <Button
          variant="outline"
          size="sm"
          aria-expanded={showing}
          onClick={() => setShowing((current) => !current)}
        >
          {showing ? dialogs.hideChanges : dialogs.showChanges}
        </Button>
        <Button size="sm" onClick={onReload}>
          {dialogs.reload}
        </Button>
      </div>
    </Modal>
  );
}
