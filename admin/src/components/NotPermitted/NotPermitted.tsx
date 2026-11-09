import type { ReactElement } from 'react';
import { Link } from 'react-router-dom';

import { EmptyState } from '../EmptyState/EmptyState';
import { focusRing } from '../focus';
import { copyForErrorCode, shell } from '../../i18n/ar';

// What a role can't open (contract admin-screens "Routes and roles"): a direct address to A16 or A17
// as an editor. The server's `403 forbidden` is the real check; this is the screen's answer so the
// editor is never left with an empty frame. The shell also drops the link, so it is reachable only by
// typing the address.

export function NotPermitted(): ReactElement {
  return (
    <div className="flex flex-col items-center gap-4">
      <EmptyState kind="error" title={copyForErrorCode('forbidden')} body={shell.notPermittedBody} />
      <Link to="/" className={`text-label font-semibold text-accent-text ${focusRing}`}>
        {shell.notPermittedBack}
      </Link>
    </div>
  );
}
