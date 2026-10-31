import { clsx } from 'clsx';
import { useEffect, useId, useState, type ReactElement, type ReactNode } from 'react';

import { dialogs } from '../../i18n/ar';
import { Button } from '../Button/Button';
import { Field } from '../Field/Field';
import { Icon } from '../Icon/Icon';
import { Modal } from './Modal';

// Bulk actions that cannot be clicked through (ConfirmDialog README): the destructive button stays
// disabled until the editor types the exact phrase, and clicking through it is never the default.

interface ConfirmDialogProps {
  open: boolean;
  title: ReactNode;
  /** The scope and consequence, in numbers. */
  body: string;
  /** What must be typed: «حذف 20». Left out for a confirmation that is not destructive. */
  phrase?: string;
  confirmLabel: string;
  /** The way out. «ابقَ» on A4's unsaved prompt, as `Dialogs.png` has it; «إلغاء» by default. */
  cancelLabel?: string;
  destructive?: boolean;
  loading?: boolean;
  /** Extra content between the copy and the actions, such as a competition picker. */
  children?: ReactNode;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmDialog({
  open,
  title,
  body,
  phrase,
  confirmLabel,
  cancelLabel,
  destructive = false,
  loading = false,
  children,
  onConfirm,
  onCancel,
}: ConfirmDialogProps): ReactElement {
  const headingId = useId();
  const [typed, setTyped] = useState('');

  // A dialog that asks for a phrase starts from an empty field, so it is always typed deliberately.
  useEffect(() => {
    if (!open) setTyped('');
  }, [open]);

  const matches = phrase === undefined || typed.trim() === phrase;

  return (
    <Modal open={open} onClose={onCancel} labelledBy={headingId}>
      <div className="flex items-start gap-3">
        <span
          aria-hidden="true"
          className={clsx(
            'flex size-12 flex-none items-center justify-center rounded-md',
            destructive ? 'bg-error-container text-error' : 'bg-accent-container text-accent-text',
          )}
        >
          <Icon name={destructive ? 'trash' : 'alert'} size="lg" />
        </span>
        <h2 id={headingId} className="heading-2 flex-1 text-text-primary">
          {title}
        </h2>
      </div>

      <p className="text-body text-text-secondary">{body}</p>

      {phrase === undefined ? null : (
        <Field
          label={dialogs.typeToConfirm(phrase)}
          autoComplete="off"
          value={typed}
          onChange={(event) => setTyped(event.target.value)}
        />
      )}

      {children}

      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" onClick={onCancel}>
          {cancelLabel ?? dialogs.cancel}
        </Button>
        <span className="flex-1" />
        <Button
          variant={destructive ? 'danger' : 'primary'}
          size="sm"
          disabled={!matches}
          loading={loading}
          onClick={onConfirm}
        >
          {confirmLabel}
        </Button>
      </div>
    </Modal>
  );
}
