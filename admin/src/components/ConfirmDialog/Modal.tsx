import { clsx } from 'clsx';
import { useEffect, useId, useRef, type ReactElement, type ReactNode } from 'react';

// The modal shell behind ConfirmDialog and ConflictDialog (Dialog README): an overlay panel that
// takes focus, traps Tab inside itself, closes on Escape, and gives focus back to its trigger.

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

interface ModalProps {
  open: boolean;
  /** The dialog's accessible name, rendered as its heading by the dialog itself. */
  labelId?: string;
  onClose: () => void;
  children: ReactNode;
  /** Test hook: `alertdialog` for the two dialogs of Dialogs.png. */
  role?: 'dialog' | 'alertdialog';
  labelledBy?: string;
  /** `drawer` slides the same trap in from the inline-start edge, as A7 and A8's editors do. */
  variant?: 'dialog' | 'drawer';
}

export function Modal({
  open,
  onClose,
  children,
  role = 'alertdialog',
  labelledBy,
  variant = 'dialog',
}: ModalProps): ReactElement | null {
  const panelRef = useRef<HTMLDivElement>(null);
  const generatedId = useId();
  // The trap is installed once per opening: a parent that recreates `onClose` on every render must
  // not make the effect re-run, because its cleanup and setup would steal focus from the field the
  // editor is typing in.
  const close = useRef(onClose);
  useEffect(() => {
    close.current = onClose;
  });

  useEffect(() => {
    if (!open) return;
    const trigger = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const panel = panelRef.current;
    panel?.focus();

    function onKeyDown(event: KeyboardEvent): void {
      if (event.key === 'Escape') {
        event.stopPropagation();
        close.current();
        return;
      }
      if (event.key !== 'Tab' || !panel) return;
      const focusable = Array.from(panel.querySelectorAll<HTMLElement>(FOCUSABLE));
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (!first || !last) return;
      // Tab wraps inside the dialog: the page behind it is out of reach while it is open.
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      } else if (!panel.contains(document.activeElement)) {
        event.preventDefault();
        first.focus();
      }
    }

    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      trigger?.focus();
    };
  }, [open]);

  if (!open) return null;

  return (
    <div
      data-testid="modal-overlay"
      data-variant={variant}
      className={clsx(
        'fixed inset-0 z-50 flex bg-overlay',
        variant === 'drawer' ? 'items-stretch justify-start' : 'items-center justify-center p-6',
      )}
    >
      <div
        ref={panelRef}
        role={role}
        aria-modal="true"
        aria-labelledby={labelledBy ?? generatedId}
        tabIndex={-1}
        className={clsx(
          'flex w-full flex-col gap-4 bg-elevated text-text-primary shadow-raised outline-none ring-1 ring-inset ring-divider',
          variant === 'drawer'
            ? 'h-full max-w-list-pane-width p-6'
            : 'max-w-list-pane-width rounded-2xl p-6',
        )}
      >
        {children}
      </div>
    </div>
  );
}

/** The id a dialog's heading uses, so the panel is named by it. */
export function useDialogHeadingId(): string {
  return `dialog-${useId()}`;
}
