import { useId, type ReactElement, type ReactNode } from 'react';

import { common } from '../../i18n/ar';
import { Button } from '../Button/Button';
import { Modal } from '../ConfirmDialog/Modal';
import { focusRing } from '../focus';
import { Icon } from '../Icon/Icon';

// The admin's full-height record editor (A7's and A8's drawers): a titled side sheet whose form owns
// the footer, with Cancel and Save in the same place on every screen.

interface EditorDrawerProps {
  open: boolean;
  title: ReactNode;
  /** One line under the title: the record's state, never a second heading. */
  subtitle?: ReactNode;
  /** Names the form for assistive tech, e.g. «تعديل القناة». */
  formLabel: string;
  saving?: boolean;
  /** The line above the footer; a failed save's reason. */
  saveError?: string | null;
  /** Extra footer action, e.g. «إضافة على قمر آخر». */
  footerAction?: ReactNode;
  onSave: () => void;
  onClose: () => void;
  children: ReactNode;
}

export function EditorDrawer({
  open,
  title,
  subtitle,
  formLabel,
  saving = false,
  saveError = null,
  footerAction,
  onSave,
  onClose,
  children,
}: EditorDrawerProps): ReactElement {
  const headingId = useId();

  return (
    <Modal open={open} variant="drawer" role="dialog" labelledBy={headingId} onClose={onClose}>
      <div className="flex items-start gap-3">
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <h2 id={headingId} className="heading-2 text-text-primary">
            {title}
          </h2>
          {subtitle ? <p className="text-caption text-text-secondary">{subtitle}</p> : null}
        </div>
        <button
          type="button"
          aria-label={common.close}
          onClick={onClose}
          className={`inline-flex size-12 flex-none items-center justify-center rounded-md text-text-secondary hover:bg-surface-2 ${focusRing}`}
        >
          <Icon name="close" size="lg" />
        </button>
      </div>

      <form
        aria-label={formLabel}
        className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto"
        onSubmit={(event) => {
          event.preventDefault();
          onSave();
        }}
      >
        <div className="flex flex-col gap-4">{children}</div>

        {saveError ? (
          <p role="alert" className="text-label font-semibold text-error">
            {saveError}
          </p>
        ) : null}

        <div className="mt-auto flex flex-wrap items-center gap-2 border-t border-divider pt-4">
          <Button variant="ghost" size="sm" onClick={onClose}>
            {common.cancel}
          </Button>
          {footerAction}
          <span className="flex-1" />
          <Button type="submit" size="sm" loading={saving} loadingLabel={common.saving}>
            {common.save}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
