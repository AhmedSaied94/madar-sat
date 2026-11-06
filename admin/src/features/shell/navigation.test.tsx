import { render, screen, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { Shell } from './Shell';
import { navigationFor } from './navigation';

// A0's sidebar per role (contract admin-screens "Routes and roles"): an editor never sees A16 or A17,
// and the sections they can't open are absent from the tree rather than merely disabled — a link the
// server refuses is a trap.

const ids = (role: 'admin' | 'editor'): string[] =>
  navigationFor(role).flatMap((group) => group.items.map((item) => item.id));

describe('the sidebar per role', () => {
  it('shows A16 and A17 to an admin', () => {
    expect(ids('admin')).toEqual(expect.arrayContaining(['users', 'audit', 'notifications']));
  });

  it('hides A16 and A17 from an editor, keeping A15', () => {
    expect(ids('editor')).toContain('notifications');
    expect(ids('editor')).not.toContain('users');
    expect(ids('editor')).not.toContain('audit');
  });

  it('keeps every other section for both roles', () => {
    const editor = ids('editor');
    for (const id of ids('admin')) {
      if (id === 'users' || id === 'audit') continue;
      expect(editor).toContain(id);
    }
  });
});

describe('the shell', () => {
  function renderShell(role: 'admin' | 'editor'): void {
    render(
      <MemoryRouter initialEntries={['/notifications']}>
        <Shell user={{ name: 'محمد علي', role }} onLogout={vi.fn()} />
      </MemoryRouter>,
    );
  }

  it('renders A15 for an editor and neither A16 nor A17', () => {
    renderShell('editor');
    const nav = screen.getByRole('navigation', { name: 'القائمة الرئيسية' });

    expect(within(nav).getByRole('link', { name: /الإشعارات/ })).toHaveAttribute('aria-current', 'page');
    expect(within(nav).queryByRole('link', { name: /المستخدمون/ })).not.toBeInTheDocument();
    expect(within(nav).queryByRole('link', { name: /سجل التغييرات/ })).not.toBeInTheDocument();
  });

  it('renders A16 and A17 for an admin', () => {
    renderShell('admin');
    const nav = screen.getByRole('navigation', { name: 'القائمة الرئيسية' });

    expect(within(nav).getByRole('link', { name: /المستخدمون/ })).toHaveAttribute('href', '/users');
    expect(within(nav).getByRole('link', { name: /سجل التغييرات/ })).toHaveAttribute('href', '/audit');
  });

  it('marks A15, not A0, as the current section on /notifications', () => {
    renderShell('admin');
    const nav = screen.getByRole('navigation', { name: 'القائمة الرئيسية' });

    expect(within(nav).getByRole('link', { name: /لوحة المتابعة/ })).not.toHaveAttribute('aria-current');
  });
});
