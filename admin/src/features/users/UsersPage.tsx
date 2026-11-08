import { useState, type ReactElement } from 'react';

import { createUser, patchUser, resetPassword } from '../../api/generated/admin';
import type { AdminUserRow } from '../../api/generated/admin.schemas';
import { ApiError, etagOf, INVALID_RESPONSE } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Field } from '../../components/Field/Field';
import { Icon } from '../../components/Icon/Icon';
import { NotPermitted } from '../../components/NotPermitted/NotPermitted';
import { HealthChip, RoleChip } from '../../components/StatusChip/StatusChip';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { formatCairoTime } from '../../lib/cairoTime';
import { conflictParty } from '../../lib/conflict';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { common, copyForErrorCode, table as tableCopy, users as copy } from '../../i18n/ar';
import { useSession } from '../auth/session';
import { useAdmins } from './queries';

// A16 (contract admin-screens "A16: users", board "Users"): the accounts with their status and last
// login, a drawer for a new one, the temporary password shown once and then gone from the DOM and the
// cache, role changes, reset and deactivate behind `ConfirmDialog`, and the server's two refusals said
// in the drawer. It is an admin screen; the shell hides it from editors and the server refuses them.

type Role = 'admin' | 'editor';

type Panel =
  | { kind: 'create' }
  | { kind: 'edit'; user: AdminUserRow }
  | { kind: 'reset'; user: AdminUserRow }
  | { kind: 'deactivate'; user: AdminUserRow }
  | null;

/** The two refusals the client can see coming (contract A16). */
function refusalCopy(code: string): string {
  if (code === 'cannot_change_self') return copy.cannotChangeSelf;
  if (code === 'last_admin') return copy.lastAdmin;
  return copyForErrorCode(code);
}

export function UsersPage(): ReactElement {
  const { session } = useSession();
  const toast = useToast();
  const refresh = useRefreshAdmin();
  const list = useAdmins();
  const [panel, setPanel] = useState<Panel>(null);
  const [menuFor, setMenuFor] = useState<number | null>(null);
  const [temporary, setTemporary] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [conflict, setConflict] = useState<{ user: AdminUserRow; meta: Readonly<Record<string, unknown>> } | null>(null);

  if (session?.admin.role !== 'admin') return <NotPermitted />;

  const rows = list.data?.data ?? [];
  const etag = etagOf(list.data);
  const me = session.admin.id;

  function failed(code: string, inline = false): void {
    setFailure(code);
    if (!inline) toast.show({ kind: 'error', title: refusalCopy(code) });
  }

  async function patch(user: AdminUserRow, body: Record<string, unknown>): Promise<boolean> {
    setBusy(true);
    setFailure(null);
    try {
      await patchUser(user.id, body, etag ? { headers: { 'If-Match': etag } } : {});
      toast.show({ kind: 'success', title: common.saved });
      setPanel(null);
      setMenuFor(null);
      refresh();
      return true;
    } catch (error) {
      const code = error instanceof ApiError ? error.code : INVALID_RESPONSE;
      if (code === 'edit_conflict') setConflict({ user, meta: (error as ApiError).meta });
      // The drawer already says this one, for the account it is about: no second copy in a toast.
      else failed(code, code === 'cannot_change_self' && panel?.kind === 'edit' && panel.user.id === me);
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function onReset(user: AdminUserRow): Promise<void> {
    setBusy(true);
    setFailure(null);
    try {
      const envelope = await resetPassword(user.id, etag ? { headers: { 'If-Match': etag } } : {});
      setPanel({ kind: 'edit', user });
      setTemporary(envelope.data?.temporary_password ?? null);
      refresh();
    } catch (error) {
      failed(error instanceof ApiError ? error.code : INVALID_RESPONSE);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0 flex-1">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle(rows.length)}</p>
        </div>
        <Button size="sm" onClick={() => setPanel({ kind: 'create' })}>
          <Icon name="plus" size="sm" />
          {copy.add}
        </Button>
      </div>

      {list.isPending ? (
        <p className="text-label text-text-secondary">{tableCopy.loading}</p>
      ) : list.isError ? (
        <EmptyState
          kind="error"
          title={copyForErrorCode(list.error?.code ?? '')}
          body={copy.subtitle(rows.length)}
          action={{ label: common.retry, onClick: () => void list.refetch() }}
        />
      ) : rows.length === 0 ? (
        <EmptyState kind="empty" title={copy.empty.title} body={copy.empty.body} />
      ) : (
        <section className="min-w-0 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
          <table className="w-full border-collapse text-start">
            <caption className="sr-only">{copy.title}</caption>
            <thead>
              <tr className="text-micro border-b border-divider text-start text-text-tertiary">
                <th scope="col" className="p-2 text-start">{copy.columns.user}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.role}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.status}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.lastLogin}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.totp}</th>
                <th scope="col" className="p-2" />
              </tr>
            </thead>
            <tbody>
              {rows.map((user) => {
                const tone: 'neutral' | 'near_limit' | 'ok' = !user.is_active
                  ? 'neutral'
                  : user.locked_for_s !== null && user.locked_for_s > 0
                    ? 'near_limit'
                    : 'ok';
                const label = !user.is_active
                  ? copy.status.disabled
                  : user.locked_for_s !== null && user.locked_for_s > 0
                    ? copy.status.locked(Math.max(1, Math.ceil(user.locked_for_s / 60)))
                    : copy.status.active;
                const initials = user.name
                  .split(/\s+/)
                  .slice(0, 2)
                  .map((part) => part.slice(0, 1))
                  .join(' ');
                return (
                  <tr key={user.id} data-testid={`user-${user.id}`} className="border-b border-divider last:border-0">
                    <td className="p-2">
                      <span className="flex items-center gap-2">
                        <span
                          aria-hidden="true"
                          className={`text-micro flex size-8 flex-none items-center justify-center rounded-pill bg-surface-2 font-semibold text-text-secondary ${
                            user.is_active ? '' : 'opacity-50'
                          }`}
                        >
                          {initials}
                        </span>
                        <span className="flex min-w-0 flex-col">
                          <span className={`text-label font-semibold ${user.is_active ? 'text-text-primary' : 'text-text-tertiary'}`}>
                            {user.name}
                          </span>
                          <bdi dir="ltr" className="text-micro text-text-tertiary">
                            {user.email}
                          </bdi>
                        </span>
                      </span>
                    </td>
                    <td className="p-2">
                      <RoleChip role={user.role} />
                    </td>
                    <td className="p-2">
                      <HealthChip health={tone}>{label}</HealthChip>
                    </td>
                    <td className="text-caption p-2 text-text-secondary">
                      {user.last_login_at === null ? copy.neverLoggedIn : formatCairoTime(user.last_login_at)}
                    </td>
                    <td className="text-caption p-2 text-text-tertiary">
                      {user.is_active ? (
                        <bdi dir="ltr" className="text-micro rounded-xs bg-surface-2 px-2 py-1 font-mono">
                          {copy.totpPlanned}
                        </bdi>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td className="p-2 text-end">
                      <span className="relative inline-flex">
                        <button
                          type="button"
                          aria-label={copy.options}
                          aria-expanded={menuFor === user.id}
                          onClick={() => setMenuFor(menuFor === user.id ? null : user.id)}
                          className={`inline-flex size-8 items-center justify-center rounded-md text-text-secondary hover:bg-surface-2 ${focusRing}`}
                        >
                          <Icon name="dotsVertical" size="sm" />
                        </button>
                        {menuFor === user.id ? (
                          <div
                            role="menu"
                            aria-label={copy.options}
                            className="absolute end-0 top-8 z-10 flex flex-col rounded-md bg-surface-1 py-1 text-start shadow-raised ring-1 ring-inset ring-divider"
                          >
                            <button
                              type="button"
                              role="menuitem"
                              onClick={() => {
                                setTemporary(null);
                                setPanel({ kind: 'edit', user });
                                setMenuFor(null);
                              }}
                              className={`text-label px-3 py-2 text-start text-text-primary hover:bg-surface-2 ${focusRing}`}
                            >
                              {copy.menu.edit}
                            </button>
                            <button
                              type="button"
                              role="menuitem"
                              onClick={() => {
                                setPanel({ kind: 'reset', user });
                                setMenuFor(null);
                              }}
                              className={`text-label px-3 py-2 text-start text-text-primary hover:bg-surface-2 ${focusRing}`}
                            >
                              {copy.menu.reset}
                            </button>
                            <button
                              type="button"
                              role="menuitem"
                              onClick={() => {
                                setMenuFor(null);
                                if (user.is_active) setPanel({ kind: 'deactivate', user });
                                else void patch(user, { is_active: true });
                              }}
                              className={`text-label px-3 py-2 text-start text-text-primary hover:bg-surface-2 ${focusRing}`}
                            >
                              {user.is_active ? copy.menu.deactivate : copy.menu.reactivate}
                            </button>
                          </div>
                        ) : null}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </section>
      )}

      {panel?.kind === 'create' ? (
        <UserDrawer
          title={copy.newTitle}
          etag={etag}
          onClose={() => {
            setTemporary(null);
            setPanel(null);
          }}
          onCreated={(password) => {
            setTemporary(password);
            refresh();
          }}
          onFailure={failed}
        />
      ) : null}

      {panel?.kind === 'edit' ? (
        <UserDrawer
          title={copy.editTitle}
          user={panel.user}
          temporary={temporary}
          etag={etag}
          isSelf={panel.user.id === me}
          onClose={() => {
            setTemporary(null);
            setPanel(null);
          }}
          onSave={(body) => void patch(panel.user, body)}
          onDeactivate={() => setPanel({ kind: 'deactivate', user: panel.user })}
          onFailure={failed}
          failure={failure}
        />
      ) : null}

      <ConfirmDialog
        open={panel?.kind === 'reset'}
        title={copy.resetTitle}
        body={copy.resetBody}
        confirmLabel={copy.resetConfirm}
        loading={busy}
        onConfirm={() => {
          if (panel?.kind === 'reset') void onReset(panel.user);
        }}
        onCancel={() => setPanel(null)}
      />

      <ConfirmDialog
        open={panel?.kind === 'deactivate'}
        title={copy.deactivateTitle}
        body={copy.deactivateBody}
        confirmLabel={copy.deactivateConfirm}
        destructive
        loading={busy}
        onConfirm={() => {
          if (panel?.kind === 'deactivate') void patch(panel.user, { is_active: false });
        }}
        onCancel={() => setPanel(null)}
      />

      {conflict === null ? null : (
        <ConflictDialog
          open
          subject={conflict.user.name}
          changedBy={conflictParty(conflict.meta)}
          changes={[]}
          onReload={() => {
            setConflict(null);
            setPanel(null);
            void list.refetch();
          }}
          onDiscard={() => setConflict(null)}
          onDismiss={() => setConflict(null)}
        />
      )}
    </div>
  );
}

interface DrawerProps {
  title: string;
  user?: AdminUserRow;
  temporary?: string | null;
  etag: string | null;
  isSelf?: boolean;
  failure?: string | null;
  onClose: () => void;
  onCreated?: (temporaryPassword: string) => void;
  onSave?: (body: Record<string, unknown>) => void;
  onDeactivate?: () => void;
  onFailure: (code: string) => void;
}

/** A16's drawer: create or edit one account. The temporary password lives here and nowhere else. */
function UserDrawer({
  title,
  user,
  temporary = null,
  etag,
  isSelf = false,
  failure,
  onClose,
  onCreated,
  onSave,
  onDeactivate,
  onFailure,
}: DrawerProps): ReactElement {
  const [name, setName] = useState(user?.name ?? '');
  const [email, setEmail] = useState(user?.email ?? '');
  const [role, setRole] = useState<Role>(user?.role ?? 'editor');
  const [busy, setBusy] = useState(false);
  const [created, setCreated] = useState<string | null>(temporary);
  const [copyDone, setCopyDone] = useState(false);

  async function create(): Promise<void> {
    setBusy(true);
    try {
      const envelope = await createUser({ name, email, role });
      const password = envelope.data?.temporary_password ?? null;
      setCreated(password);
      if (password !== null) onCreated?.(password);
    } catch (error) {
      onFailure(error instanceof ApiError ? error.code : INVALID_RESPONSE);
    } finally {
      setBusy(false);
    }
  }

  const editing = user !== undefined;
  const shown = created ?? temporary;

  return (
    <aside
      role="dialog"
      aria-label={title}
      className="fixed inset-y-0 start-0 z-20 flex w-full max-w-list-pane-width flex-col overflow-y-auto bg-surface-1 shadow-raised ring-1 ring-inset ring-divider"
    >
      <div className="flex items-center gap-2 border-b border-divider px-4 py-3">
        <Icon name="users" size="lg" className="text-accent-text" />
        <h2 className="heading-2 flex-1 text-text-primary">{title}</h2>
        <button
          type="button"
          aria-label={common.close}
          onClick={() => {
            setCreated(null);
            onClose();
          }}
          className={`inline-flex size-8 items-center justify-center rounded-md text-text-secondary hover:bg-surface-2 ${focusRing}`}
        >
          <Icon name="close" size="sm" />
        </button>
      </div>

      <div className="flex flex-col gap-4 p-4">
        <Field label={copy.fields.name} value={name} onChange={(event) => setName(event.target.value)} disabled={shown !== null} />
        <Field
          label={copy.fields.email}
          type="email"
          ltr
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          disabled={editing || shown !== null}
        />

        <fieldset className="flex flex-col gap-2">
          <legend className="text-caption font-semibold text-text-secondary">{copy.fields.role}</legend>
          {(['editor', 'admin'] as const).map((option) => (
            <label
              key={option}
              className={`flex items-start gap-2 rounded-md px-3 py-2 ring-1 ring-inset ${
                role === option ? 'bg-accent-container text-accent-text ring-accent' : 'bg-bg text-text-secondary ring-divider'
              }`}
            >
              <input
                type="radio"
                name="role"
                aria-label={option === 'editor' ? 'محرر' : 'مدير'}
                checked={role === option}
                onChange={() => setRole(option)}
                className="mt-1 size-4 accent-accent"
              />
              <span className="flex flex-col">
                <span className="text-label font-semibold">{option === 'editor' ? 'محرر' : 'مدير'}</span>
                <span className="text-caption text-text-tertiary">{copy.roleHints[option]}</span>
              </span>
            </label>
          ))}
        </fieldset>

        {isSelf ? (
          <p role="note" className="text-label rounded-md bg-surface-2 px-3 py-2 text-text-secondary">
            {copy.cannotChangeSelf}
          </p>
        ) : null}

        {isSelf && failure === 'cannot_change_self' ? null : failure ? (
          <p role="alert" className="text-label rounded-md bg-error-container px-3 py-2 text-error">
            {refusalCopy(failure)}
          </p>
        ) : null}

        {shown === null ? null : (
          <div className="flex flex-col gap-2 rounded-md bg-bg p-3">
            <span className="text-caption font-semibold text-text-secondary">
              {copy.tempPassword} · {copy.tempPasswordHint}
            </span>
            <div className="flex items-center gap-2">
              <bdi dir="ltr" className="text-label min-w-0 flex-1 truncate rounded-xs bg-surface-2 px-3 py-2 font-mono text-text-primary">
                {shown}
              </bdi>
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  void navigator.clipboard?.writeText(shown).then(
                    () => setCopyDone(true),
                    () => setCopyDone(false),
                  );
                }}
              >
                <Icon name="link" size="sm" />
                {copy.copy}
              </Button>
            </div>
            <span role="status" aria-live="polite" className="text-caption text-text-tertiary">
              {copyDone ? copy.copied : ''}
            </span>
          </div>
        )}
      </div>

      <div className="mt-auto flex items-center gap-2 border-t border-divider px-4 py-3">
        <Button size="sm" variant="ghost" onClick={onClose}>
          {common.cancel}
        </Button>
        <span className="flex-1" />
        {editing ? (
          <>
            <Button size="sm" variant="danger" disabled={isSelf} onClick={onDeactivate}>
              {copy.menu.deactivate}
            </Button>
            <Button size="sm" variant="primary" loading={busy} onClick={() => onSave?.({ name, role })}>
              {copy.save}
            </Button>
          </>
        ) : (
          <Button size="sm" variant="primary" loading={busy} disabled={shown !== null} onClick={() => void create()}>
            {copy.create}
          </Button>
        )}
      </div>
      {/* The ETag this drawer read is the version every save must echo (constitution VI). */}
      <span hidden data-etag={etag ?? ''} />
    </aside>
  );
}
