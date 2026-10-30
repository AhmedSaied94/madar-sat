import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { renderRtl } from '../../test/render';
import { HealthChip, RoleChip, SourceChip, Stat } from './StatusChip';

describe('Stat (send state)', () => {
  it.each([
    ['sent', 'أُرسل', 'text-free'],
    ['failed', 'فشل', 'text-error'],
    ['partial', 'جزئي', 'text-postponed'],
    ['scheduled', 'مجدول', 'text-text-secondary'],
    ['live', 'مباشر', 'text-live'],
  ] as const)('%s reads «%s» with its tone', (kind, label, tone) => {
    renderRtl(<Stat kind={kind} />);

    const chip = screen.getByText(label);
    expect(chip).toHaveAttribute('data-kind', kind);
    expect(chip).toHaveClass(tone);
  });

  it('accepts its own content, such as a count with an icon', () => {
    renderRtl(<Stat kind="partial">0</Stat>);

    expect(screen.getByText('0').closest('[data-kind]')).toHaveAttribute('data-kind', 'partial');
  });
});

describe('SourceChip', () => {
  it.each(['YSS', 'LST', 'SEZ', 'YK', 'API'] as const)('%s is a mono LTR code', (source) => {
    renderRtl(<SourceChip source={source} />);

    const chip = screen.getByText(source);
    expect(chip).toHaveAttribute('dir', 'ltr');
    expect(chip).toHaveClass('font-mono');
  });

  it('highlights a manual value as «يدوي»', () => {
    renderRtl(<SourceChip source="manual" />);

    const chip = screen.getByText('يدوي');
    expect(chip).toHaveAttribute('data-source', 'manual');
    expect(chip).toHaveClass('bg-accent-container', 'text-accent-text');
    expect(chip).not.toHaveAttribute('dir', 'ltr');
  });
});

describe('RoleChip', () => {
  it.each([
    ['admin', 'مدير'],
    ['editor', 'محرر'],
  ] as const)('%s reads «%s»', (role, label) => {
    renderRtl(<RoleChip role={role} />);

    expect(screen.getByText(label)).toHaveAttribute('data-role', role);
  });
});

describe('HealthChip', () => {
  it.each([
    ['ok', 'سليم', 'text-success'],
    ['near_limit', 'قرب الحد', 'text-postponed'],
    ['open', 'مفتوحة', 'text-error'],
  ] as const)('%s reads «%s» next to a dot', (health, label, tone) => {
    renderRtl(<HealthChip health={health} />);

    const chip = screen.getByText(label).closest('[data-health]');
    expect(chip).toHaveAttribute('data-health', health);
    expect(chip).toHaveClass(tone);
    expect(chip?.querySelector('[data-dot]')).toHaveAttribute('aria-hidden', 'true');
  });
});

describe('meaning is never carried by color alone', () => {
  it('every chip has a text label', () => {
    renderRtl(
      <>
        <Stat kind="failed" />
        <SourceChip source="YK" />
        <RoleChip role="editor" />
        <HealthChip health="open" />
      </>,
    );

    for (const label of ['فشل', 'YK', 'محرر', 'مفتوحة']) {
      expect(screen.getByText(label)).toBeVisible();
    }
  });
});
