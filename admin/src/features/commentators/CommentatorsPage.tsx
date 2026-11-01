import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';

import { deleteCommentator } from '../../api/generated/admin';
import type { AdminCommentator, ListCommentatorsParams } from '../../api/generated/admin.schemas';
import { ApiError, NETWORK_ERROR } from '../../api/http';
import { AudioPlayer } from '../../components/AudioPlayer/AudioPlayer';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { Icon } from '../../components/Icon/Icon';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { commentators as copy, common, copyForErrorCode, toast as toastCopy } from '../../i18n/ar';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { CommentatorEditor } from './CommentatorEditor';
import { useCommentators } from './queries';

// A10 (admin board "Commentators"): a card per commentator with their photo, how many matches use
// them, and their voice sample. Removing one shows the usage first and refuses while it is in use.

const initials = (name: string): string =>
  name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word.charAt(0))
    .join(' ');

export function CommentatorsPage(): ReactElement {
  const [query, setQuery] = useState('');
  const [menuFor, setMenuFor] = useState<number | null>(null);
  const [editing, setEditing] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);
  const [removing, setRemoving] = useState<AdminCommentator | null>(null);
  const [deleting, setDeleting] = useState(false);
  const toast = useToast();
  const refresh = useRefreshAdmin();

  const params: ListCommentatorsParams = { q: query.trim() === '' ? null : query.trim(), limit: 100 };
  const { data, isPending, isError, error } = useCommentators(params);
  const rows = data?.data ?? [];
  const withoutProfile = rows.filter((row) => row.photo === null).length;

  async function remove(person: AdminCommentator): Promise<void> {
    setDeleting(true);
    try {
      await deleteCommentator(person.id);
      refresh();
      toast.show({ kind: 'success', title: toastCopy.saved });
      setRemoving(null);
    } catch (failure) {
      const code = failure instanceof ApiError ? failure.code : NETWORK_ERROR;
      toast.show({ kind: 'error', title: copy.delete.confirm, description: copyForErrorCode(code) });
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle(rows.length, withoutProfile)}</p>
        </div>
        <span className="flex-1" />
        <button
          type="button"
          onClick={() => setCreating(true)}
          className={clsx(
            'text-label inline-flex h-12 items-center gap-2 rounded-lg bg-accent px-3 font-semibold text-on-accent',
            focusRing,
          )}
        >
          <Icon name="plus" size="sm" />
          {copy.add}
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <label className="flex h-8 min-w-0 items-center gap-2 rounded-lg bg-surface-1 px-3 ring-1 ring-inset ring-divider">
          <Icon name="search" size="md" className="text-text-tertiary" />
          <input
            type="search"
            aria-label={copy.search}
            placeholder={copy.search}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="text-caption min-w-0 flex-1 bg-transparent text-text-primary outline-none placeholder:text-text-tertiary"
          />
        </label>
      </div>

      {isPending ? (
        <p className="text-label text-text-secondary">{common.loading}</p>
      ) : isError ? (
        <p className="text-label font-semibold text-error">{copyForErrorCode(error?.code ?? '')}</p>
      ) : rows.length === 0 ? (
        <p className="text-label text-text-secondary">{copy.editor.empty}</p>
      ) : (
        <ul aria-label={copy.title} className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          {rows.map((person) => (
            <li
              key={person.id}
              data-testid={`commentator-${person.id}`}
              className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider"
            >
              <div className="flex items-start gap-3">
                <span
                  aria-hidden="true"
                  className="text-label flex size-12 flex-none items-center justify-center overflow-hidden rounded-pill bg-surface-3 font-semibold text-text-secondary"
                >
                  {person.photo ? (
                    <img src={person.photo} alt="" className="size-full object-cover" />
                  ) : (
                    initials(person.name)
                  )}
                </span>
                <div className="flex min-w-0 flex-1 flex-col">
                  <bdi className="text-label truncate font-semibold text-text-primary">{person.name}</bdi>
                  <span className="text-caption text-text-tertiary">{copy.usage(person.usage.matches)}</span>
                </div>

                <button
                  type="button"
                  aria-label={copy.options(person.name)}
                  aria-expanded={menuFor === person.id}
                  onClick={() => setMenuFor((current) => (current === person.id ? null : person.id))}
                  className={`inline-flex size-12 flex-none items-center justify-center rounded-md text-text-secondary hover:bg-surface-2 ${focusRing}`}
                >
                  <Icon name="dotsVertical" size="lg" />
                </button>
              </div>

              {menuFor === person.id ? (
                <div role="menu" aria-label={copy.options(person.name)} className="flex flex-col gap-1 rounded-lg bg-bg p-1">
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setMenuFor(null);
                      setEditing(person.id);
                    }}
                    className={`text-label rounded-sm px-3 py-2 text-start text-text-primary hover:bg-surface-2 ${focusRing}`}
                  >
                    {common.edit}
                  </button>
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setMenuFor(null);
                      setRemoving(person);
                    }}
                    className={`text-label rounded-sm px-3 py-2 text-start text-error hover:bg-error-container ${focusRing}`}
                  >
                    {copy.delete.confirm}
                  </button>
                </div>
              ) : null}

              {person.audio ? (
                <AudioPlayer src={person.audio} person={person.name} />
              ) : (
                <p className="text-caption text-text-tertiary">{copy.withoutAudio}</p>
              )}
            </li>
          ))}
        </ul>
      )}

      <CommentatorEditor commentatorId={editing} open={editing !== null} onClose={() => setEditing(null)} />
      <CommentatorEditor commentatorId={null} open={creating} onClose={() => setCreating(false)} />

      <ConfirmDialog
        open={removing !== null}
        title={removing === null ? '' : copy.delete.title(removing.name)}
        body={removing === null ? '' : copy.delete.body(removing.usage.matches)}
        confirmLabel={copy.delete.confirm}
        destructive
        loading={deleting}
        onConfirm={() => {
          if (removing) void remove(removing);
        }}
        onCancel={() => setRemoving(null)}
      />
    </div>
  );
}
