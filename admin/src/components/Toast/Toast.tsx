import { cva } from 'class-variance-authority';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactElement,
  type ReactNode,
} from 'react';

import { toast as toastCopy } from '../../i18n/ar';
import { focusRing } from '../focus';
import { Icon, type IconName } from '../Icon/Icon';

// Short confirmations (Banner README, toast part; admin Dialogs board).
// Success and info close after 2 seconds; errors stay until dismissed so they can be read and retried.
export const TOAST_DURATION_MS = 2000;

export type ToastKind = 'success' | 'error' | 'info';

export interface ToastOptions {
  kind: ToastKind;
  title: string;
  description?: string;
  action?: { label: string; onClick: () => void };
}

interface ToastItem extends ToastOptions {
  id: number;
}

interface ToastApi {
  show: (options: ToastOptions) => number;
  dismiss: (id: number) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

const kindIcon: Record<ToastKind, { name: IconName; className: string }> = {
  success: { name: 'check', className: 'text-success' },
  error: { name: 'alert', className: 'text-error' },
  info: { name: 'info', className: 'text-info' },
};

const actionStyles = cva(`text-caption h-8 shrink-0 rounded-sm px-3 font-semibold ${focusRing}`, {
  variants: {
    kind: {
      success: 'text-accent-text hover:bg-surface-2',
      info: 'text-accent-text hover:bg-surface-2',
      error: 'bg-surface-2 text-text-primary hover:bg-surface-3',
    },
  },
});

function ToastCard({ item, onDismiss }: { item: ToastItem; onDismiss: (id: number) => void }): ReactElement {
  const icon = kindIcon[item.kind];
  const { action } = item;

  return (
    <div
      data-toast
      data-kind={item.kind}
      className="text-label pointer-events-auto flex items-center gap-3 rounded-lg bg-elevated px-4 py-3 text-text-primary shadow-raised ring-1 ring-inset ring-divider motion-safe:animate-toast-in"
    >
      <Icon name={icon.name} size="lg" className={icon.className} />
      <p className="min-w-0 flex-1">
        <span className="font-semibold">{item.title}</span>
        {item.description ? <span className="text-text-secondary"> · {item.description}</span> : null}
      </p>
      {action ? (
        <button
          type="button"
          className={actionStyles({ kind: item.kind })}
          onClick={() => {
            action.onClick();
            onDismiss(item.id);
          }}
        >
          {action.label}
        </button>
      ) : null}
      {item.kind === 'error' ? (
        <button
          type="button"
          aria-label={toastCopy.dismiss}
          className={`inline-flex size-8 shrink-0 items-center justify-center rounded-pill text-text-secondary hover:bg-surface-2 ${focusRing}`}
          onClick={() => onDismiss(item.id)}
        >
          <Icon name="close" />
        </button>
      ) : null}
    </div>
  );
}

export function ToastProvider({ children }: { children: ReactNode }): ReactElement {
  const [toasts, setToasts] = useState<readonly ToastItem[]>([]);
  const nextId = useRef(0);
  const timers = useRef(new Map<number, ReturnType<typeof setTimeout>>());

  const dismiss = useCallback((id: number) => {
    const timer = timers.current.get(id);
    if (timer) clearTimeout(timer);
    timers.current.delete(id);
    setToasts((current) => current.filter((item) => item.id !== id));
  }, []);

  const show = useCallback(
    (options: ToastOptions) => {
      nextId.current += 1;
      const id = nextId.current;
      setToasts((current) => [...current, { ...options, id }]);
      if (options.kind !== 'error') {
        timers.current.set(
          id,
          setTimeout(() => dismiss(id), TOAST_DURATION_MS),
        );
      }
      return id;
    },
    [dismiss],
  );

  useEffect(() => {
    const pending = timers.current;
    return () => pending.forEach((timer) => clearTimeout(timer));
  }, []);

  const api = useMemo(() => ({ show, dismiss }), [show, dismiss]);
  const errors = toasts.filter((item) => item.kind === 'error');
  const notices = toasts.filter((item) => item.kind !== 'error');

  return (
    <ToastContext.Provider value={api}>
      {children}
      {/* Live regions exist before any toast, so screen readers announce what is added to them. */}
      <div className="pointer-events-none fixed bottom-6 end-6 z-50 flex w-full max-w-list-pane-width flex-col gap-2">
        <div role="alert" className="flex flex-col gap-2">
          {errors.map((item) => (
            <ToastCard key={item.id} item={item} onDismiss={dismiss} />
          ))}
        </div>
        <div role="status" className="flex flex-col gap-2">
          {notices.map((item) => (
            <ToastCard key={item.id} item={item} onDismiss={dismiss} />
          ))}
        </div>
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const api = useContext(ToastContext);
  if (!api) {
    throw new Error('useToast must be used inside <ToastProvider>');
  }
  return api;
}
