import type { ReactElement } from 'react';

import { mapName } from '../../api/generated/admin';
import type { UnresolvedNameRow } from '../../api/generated/admin.schemas';
import { ApiError, NETWORK_ERROR } from '../../api/http';
import { useToast } from '../../components/Toast/Toast';
import { copyForErrorCode, unresolved as copy } from '../../i18n/ar';
import { ChannelEditor } from '../channels/ChannelEditor';
import { CompetitionEditor } from '../competitions/CompetitionEditor';
import { TeamEditor } from '../teams/TeamEditor';

// A13's «جديد» (research R10): the queue never creates an entity itself. It opens the form that
// already owns that kind, filled with the source's name, and maps the queued name to what the editor
// created. A map that fails leaves the row open in the queue and says why.

interface CreateFromNameProps {
  row: UnresolvedNameRow | null;
  onClose: () => void;
  /** Called after the name is bound, so the queue and its count follow. */
  onMapped: () => void;
}

export function CreateFromName({ row, onClose, onMapped }: CreateFromNameProps): ReactElement | null {
  const toast = useToast();

  if (row === null) return null;

  async function created(targetId: number, queued: UnresolvedNameRow): Promise<void> {
    try {
      await mapName(
        queued.id,
        { target_id: targetId, scope_to_competition: false, created: true },
        { headers: { 'If-Match': queued.etag } },
      );
      toast.show({ kind: 'success', title: copy.created });
      onMapped();
      onClose();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : NETWORK_ERROR;
      toast.show({ kind: 'error', title: copy.createLeftOpen, description: copyForErrorCode(code) });
    }
  }

  const onCreated = (targetId: number): void => {
    void created(targetId, row);
  };

  switch (row.kind) {
    case 'team':
      return (
        <TeamEditor teamId={null} open initialName={row.name} onCreated={onCreated} onClose={onClose} />
      );
    case 'competition':
      return (
        <CompetitionEditor
          competitionId={null}
          open
          initialName={row.name}
          onCreated={onCreated}
          onClose={onClose}
        />
      );
    case 'channel':
      return (
        <ChannelEditor
          channelId={null}
          open
          initialName={row.name}
          onCreated={onCreated}
          onClose={onClose}
        />
      );
    default:
      return null;
  }
}
