import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { UnresolvedQueue } from './UnresolvedQueue';

const envelope = (data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: true,
  data,
  error: null,
  meta,
});

const teamRow = {
  id: 91,
  source: 'livesoccertv',
  kind: 'team',
  name: 'Nasaf Qarshi',
  context: { match_id: 48213, home: 'ناساف', away: 'الكويت', competition: 'دوري أبطال آسيا 2' },
  seen_count: 4,
  last_seen_at: '2026-11-04T10:00:00Z',
  state: 'open',
  etag: '"n-91"',
  suggestions: [{ id: 101, name: 'ناساف', detail: 'دوري أبطال آسيا 2', confidence: 92, exact: false }],
};

const competitionRow = {
  ...teamRow,
  id: 94,
  kind: 'competition',
  name: 'AFC Champions League 2',
  etag: '"n-94"',
  suggestions: [],
};

const channelRow = {
  ...teamRow,
  id: 95,
  kind: 'channel',
  name: 'beIN SPORTS 2 MENA',
  etag: '"n-95"',
  suggestions: [],
};

function serve(row: unknown): void {
  server.use(
    mswHttp.get('*/admin/api/unresolved-names', () => HttpResponse.json(envelope([row], { open_count: 1 }))),
    mswHttp.get('*/admin/api/competitions', () => HttpResponse.json(envelope([]))),
    mswHttp.get('*/admin/api/satellites', () => HttpResponse.json(envelope([]))),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

describe('CreateFromName (A13)', () => {
  it('opens the team form filled with the queued name, then maps the name to what it created', async () => {
    const maps: { body: unknown; ifMatch: string | null }[] = [];
    let createdName: string | null = null;

    server.use(
      mswHttp.post('*/admin/api/teams', async ({ request }) => {
        createdName = ((await request.json()) as { name: string }).name;
        return HttpResponse.json(
          envelope({
            id: 4711,
            name: createdName,
            sport: 'football',
            stadium: null,
            country: null,
            logo: null,
            logo_asset_id: null,
            primary_competition_id: null,
            competition_ids: [],
            external_ids: [],
          }),
          { status: 201, headers: { ETag: '"t-4711"' } },
        );
      }),
      mswHttp.post('*/admin/api/unresolved-names/:id/map', async ({ request }) => {
        maps.push({ body: await request.json(), ifMatch: request.headers.get('If-Match') });
        return HttpResponse.json(envelope({ ...teamRow, state: 'created' }));
      }),
    );
    serve(teamRow);
    renderRtl(<UnresolvedQueue />, { wrapper: Providers });

    const row = await screen.findByTestId('unresolved-91');
    await userEvent.click(within(row).getByRole('button', { name: 'جديد' }));

    const drawer = await screen.findByRole('dialog', { name: 'فريق جديد' });
    expect(within(drawer).getByLabelText('اسم الفريق')).toHaveValue('Nasaf Qarshi');

    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(createdName).toBe('Nasaf Qarshi'));
    await waitFor(() => expect(maps).toHaveLength(1));
    expect(maps[0]).toEqual({
      body: { target_id: 4711, scope_to_competition: false, created: true },
      ifMatch: '"n-91"',
    });
    expect(await screen.findByText('أُنشئ العنصر ورُبط الاسم')).toBeInTheDocument();
  });

  it('opens the competition form for a competition name', async () => {
    let created = false;
    server.use(
      mswHttp.post('*/admin/api/competitions', () => {
        created = true;
        return HttpResponse.json(
          envelope({
            id: 88,
            name: 'AFC Champions League 2',
            sport: 'football',
            priority: 1,
            logo: null,
            logo_asset_id: null,
            etag: '"c-88"',
          }),
          { status: 201 },
        );
      }),
      mswHttp.post('*/admin/api/unresolved-names/:id/map', () =>
        HttpResponse.json(envelope({ ...competitionRow, state: 'created' })),
      ),
    );
    serve(competitionRow);
    renderRtl(<UnresolvedQueue />, { wrapper: Providers });

    const row = await screen.findByTestId('unresolved-94');
    await userEvent.click(within(row).getByRole('button', { name: 'جديد' }));

    const drawer = await screen.findByRole('dialog', { name: 'بطولة جديدة' });
    expect(within(drawer).getByLabelText('اسم البطولة')).toHaveValue('AFC Champions League 2');
    expect(created).toBe(false);
  });

  it('opens the channel drawer for a channel name', async () => {
    serve(channelRow);
    renderRtl(<UnresolvedQueue />, { wrapper: Providers });

    const row = await screen.findByTestId('unresolved-95');
    await userEvent.click(within(row).getByRole('button', { name: 'جديد' }));

    const drawer = await screen.findByRole('dialog', { name: 'قناة جديدة' });
    expect(within(drawer).getByLabelText('اسم المطابقة')).toHaveValue('beIN SPORTS 2 MENA');
  });

  it('leaves the row open and says so when the map fails after the create', async () => {
    server.use(
      mswHttp.post('*/admin/api/teams', () =>
        HttpResponse.json(
          envelope({
            id: 4711,
            name: 'Nasaf Qarshi',
            sport: 'football',
            stadium: null,
            country: null,
            logo: null,
            logo_asset_id: null,
            primary_competition_id: null,
            competition_ids: [],
            external_ids: [],
          }),
          { status: 201 },
        ),
      ),
      mswHttp.post('*/admin/api/unresolved-names/:id/map', () =>
        HttpResponse.json(
          { success: false, data: null, error: { code: 'alias_conflict', message: 'bound' }, meta: {} },
          { status: 409 },
        ),
      ),
    );
    serve(teamRow);
    renderRtl(<UnresolvedQueue />, { wrapper: Providers });

    const row = await screen.findByTestId('unresolved-91');
    await userEvent.click(within(row).getByRole('button', { name: 'جديد' }));
    const drawer = await screen.findByRole('dialog', { name: 'فريق جديد' });
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await screen.findByText('أُنشئ العنصر لكن لم يُربط الاسم. الصف ما زال مفتوحاً')).toBeInTheDocument();
    expect(screen.getByTestId('unresolved-91')).toBeInTheDocument();
  });
});
