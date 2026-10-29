import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { SidebarNav, type SidebarNavGroup } from './SidebarNav';

const groups: SidebarNavGroup[] = [
  { id: 'top', items: [{ id: 'dashboard', label: 'لوحة المتابعة', icon: 'dashboard', to: '/' }] },
  {
    id: 'content',
    label: 'المحتوى',
    items: [
      { id: 'matches', label: 'المباريات', icon: 'ball', to: '/matches', count: { value: 41, tone: 'waiting' } },
      { id: 'teams', label: 'الفرق', icon: 'shield', to: '/teams' },
      { id: 'channels', label: 'القنوات', icon: 'tv', to: '/channels', count: { value: 7, tone: 'neutral' } },
    ],
  },
  {
    id: 'operations',
    label: 'التشغيل',
    items: [
      { id: 'sources', label: 'المصادر', icon: 'database', to: '/sources', count: { value: 1, tone: 'failing' } },
      { id: 'reports', label: 'البلاغات', icon: 'flag', to: '/reports', planned: true },
    ],
  },
];

function renderNav(active = 'matches', onLogout = vi.fn()) {
  renderRtl(<SidebarNav groups={groups} active={active} user={{ name: 'محمد علي', role: 'admin' }} onLogout={onLogout} />);
  return { nav: screen.getByRole('navigation', { name: 'القائمة الرئيسية' }), onLogout };
}

describe('SidebarNav', () => {
  it('renders grouped sections under their headings, in order', () => {
    const { nav } = renderNav();

    const content = within(nav).getByRole('list', { name: 'المحتوى' });
    expect(within(content).getAllByRole('link').map((link) => link.textContent)).toEqual([
      expect.stringContaining('المباريات'),
      expect.stringContaining('الفرق'),
      expect.stringContaining('القنوات'),
    ]);
    expect(within(nav).getByRole('list', { name: 'التشغيل' })).toBeInTheDocument();
    expect(within(nav).getAllByRole('link')[0]).toHaveTextContent('لوحة المتابعة');
  });

  it('marks only the active item, with the accent container', () => {
    const { nav } = renderNav('teams');

    const active = within(nav).getByRole('link', { name: /الفرق/ });
    expect(active).toHaveAttribute('aria-current', 'page');
    expect(active).toHaveClass('bg-accent-container');
    expect(within(nav).getByRole('link', { name: /المباريات/ })).not.toHaveAttribute('aria-current');
  });

  it('gives inactive items the surface-2 hover state', () => {
    const { nav } = renderNav('teams');

    expect(within(nav).getByRole('link', { name: /المباريات/ })).toHaveClass('hover:bg-surface-2');
  });

  it('shows attention counts with their tone in text, not color alone', () => {
    const { nav } = renderNav();

    const waiting = within(within(nav).getByRole('link', { name: /المباريات/ })).getByTestId('nav-count');
    expect(waiting).toHaveAttribute('data-tone', 'waiting');
    expect(waiting).toHaveTextContent('41');
    expect(waiting).toHaveTextContent('بانتظار العمل');

    const failing = within(within(nav).getByRole('link', { name: /المصادر/ })).getByTestId('nav-count');
    expect(failing).toHaveAttribute('data-tone', 'failing');
    expect(failing).toHaveTextContent('مصدر متعطل');

    const neutral = within(within(nav).getByRole('link', { name: /القنوات/ })).getByTestId('nav-count');
    expect(neutral).toHaveAttribute('data-tone', 'neutral');
  });

  it('keeps V2 items visible and marks them as planned', () => {
    const { nav } = renderNav();

    const planned = within(nav).getByRole('link', { name: /البلاغات/ });
    expect(planned).toHaveTextContent('V2');
    expect(planned).toHaveAccessibleName(expect.stringContaining('مخطط للإصدار الثاني'));
  });

  it('shows the signed-in user with their role and a logout button', async () => {
    const { onLogout } = renderNav();

    expect(screen.getByText('محمد علي')).toBeInTheDocument();
    expect(screen.getByText('مدير')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));
    expect(onLogout).toHaveBeenCalledOnce();
  });

  it('moves keyboard focus through the items in order with a visible focus ring', async () => {
    const { nav } = renderNav();
    const links = within(nav).getAllByRole('link');

    await userEvent.tab();
    expect(links[0]).toHaveFocus();
    await userEvent.tab();
    expect(links[1]).toHaveFocus();
    expect(links[1]).toHaveClass('focus-visible:ring-focus-ring');
  });

  it('renders as the right-hand column in RTL, with its divider toward the content', () => {
    const { nav } = renderNav();

    const aside = nav.closest('aside');
    expect(aside).not.toBeNull();
    expect(aside?.closest('[dir]')).toHaveAttribute('dir', 'rtl');
    expect(aside).toHaveClass('border-e', 'w-admin-sidebar-width');
  });
});
