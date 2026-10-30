import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { Button } from './Button';

describe('Button', () => {
  it.each([
    ['primary', 'bg-accent', 'text-on-accent'],
    ['secondary', 'bg-surface-2', 'text-text-primary'],
    ['outline', 'text-text-primary', 'ring-divider-strong'],
    ['ghost', 'text-accent-text', 'bg-transparent'],
    ['danger', 'bg-error-container', 'text-error'],
  ] as const)('%s is built from its tokens', (variant, fill, text) => {
    renderRtl(
      <Button variant={variant} onClick={vi.fn()}>
        حفظ
      </Button>,
    );

    const button = screen.getByRole('button', { name: 'حفظ' });
    expect(button).toHaveAttribute('data-variant', variant);
    expect(button).toHaveClass(fill, text);
  });

  it.each([
    ['default', 'h-12'],
    ['sm', 'h-8'],
    ['xs', 'h-6'],
  ] as const)('%s keeps its height and the minimum touch target', (size, height) => {
    renderRtl(<Button size={size}>تصفية</Button>);

    const button = screen.getByRole('button', { name: 'تصفية' });
    expect(button).toHaveAttribute('data-size', size);
    expect(button).toHaveClass(height, 'min-h-12');
  });

  it('is disabled when disabled, and when busy', async () => {
    const onClick = vi.fn();
    const { rerender } = renderRtl(
      <Button disabled onClick={onClick}>
        حذف
      </Button>,
    );

    const disabled = screen.getByRole('button', { name: 'حذف' });
    expect(disabled).toBeDisabled();
    await userEvent.click(disabled);
    expect(onClick).not.toHaveBeenCalled();

    rerender(<Button loading loadingLabel="جارٍ الحفظ">حفظ</Button>);
    const busy = screen.getByRole('button', { name: /جارٍ الحفظ/ });
    expect(busy).toBeDisabled();
    expect(busy).toHaveAttribute('aria-busy', 'true');
    expect(busy.querySelector('[data-spinner]')).toBeInTheDocument();
  });

  it('shows a visible keyboard focus ring', async () => {
    renderRtl(<Button>إضافة مباراة</Button>);

    const button = screen.getByRole('button', { name: 'إضافة مباراة' });
    expect(button.className).toContain('focus-visible:ring-focus-ring');
    await userEvent.tab();
    expect(button).toHaveFocus();
  });

  it('takes an accessible label when it only shows an icon', () => {
    renderRtl(
      <Button iconOnly aria-label="إغلاق">
        ×
      </Button>,
    );

    const button = screen.getByRole('button', { name: 'إغلاق' });
    expect(button).toHaveClass('px-0', 'w-12');
  });
});
