import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { navLabels } from '../../i18n/ar';
import { renderRtl } from '../../test/render';
import { Shell } from './Shell';

function renderShell(route = '/') {
  const onLogout = vi.fn();
  renderRtl(
    <Routes>
      <Route element={<Shell user={{ name: 'محمد علي', role: 'admin' }} onLogout={onLogout} />}>
        <Route index element={<p>محتوى الصفحة</p>} />
        <Route path="matches" element={<p>صفحة المباريات</p>} />
      </Route>
    </Routes>,
    { route },
  );
  return { onLogout };
}

describe('Shell (A0)', () => {
  it('puts the sidebar first in the RTL row, so it sits on the right', () => {
    renderShell();

    const nav = screen.getByRole('navigation', { name: 'القائمة الرئيسية' });
    const layout = screen.getByTestId('shell');
    expect(layout.closest('[dir]')).toHaveAttribute('dir', 'rtl');
    expect(layout).toHaveClass('flex');
    expect(layout.firstElementChild).toContainElement(nav);
  });

  it('lists the product doc §10 A0 sections in order', () => {
    renderShell();

    const nav = screen.getByRole('navigation', { name: 'القائمة الرئيسية' });
    const labels = within(nav)
      .getAllByRole('link')
      .map((link) => link.getAttribute('data-label'));
    expect(labels).toEqual(Object.values(navLabels));
  });

  it('marks البلاغات as a V2 section', () => {
    renderShell();

    const reports = within(screen.getByRole('navigation', { name: 'القائمة الرئيسية' })).getByRole('link', { name: /البلاغات/ });
    expect(reports).toHaveTextContent('V2');
  });

  it('highlights the section of the current route', () => {
    renderShell('/matches');

    const nav = screen.getByRole('navigation', { name: 'القائمة الرئيسية' });
    expect(within(nav).getByRole('link', { name: /المباريات/ })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByText('صفحة المباريات')).toBeInTheDocument();
  });

  it('has a top bar with global search and the signed-in user and role', () => {
    renderShell();

    const topBar = screen.getByRole('banner');
    expect(within(topBar).getByRole('searchbox', { name: 'بحث شامل' })).toBeInTheDocument();
    const user = within(topBar).getByRole('group', { name: 'المستخدم الحالي' });
    expect(user).toHaveTextContent('محمد علي');
    expect(within(user).getByText('مدير')).toHaveAttribute('data-role', 'admin');
  });

  it('focuses global search with Ctrl K', async () => {
    renderShell();

    await userEvent.keyboard('{Control>}k{/Control}');
    expect(screen.getByRole('searchbox', { name: 'بحث شامل' })).toHaveFocus();
  });

  it('renders the routed page in the main area', () => {
    renderShell();

    expect(within(screen.getByRole('main')).getByText('محتوى الصفحة')).toBeInTheDocument();
  });

  it('signs out from the sidebar', async () => {
    const { onLogout } = renderShell();

    await userEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));
    expect(onLogout).toHaveBeenCalledOnce();
  });
});
