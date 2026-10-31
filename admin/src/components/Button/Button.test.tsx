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

  // Every size is a 48 px element; the two smaller ones clip a 40 px and a 32 px fill inside it with
  // a transparent band of border, because `border-box` puts the border inside the height (A-R2-3).
  it.each([
    ['default', null],
    ['sm', 'border-y-4'],
    ['xs', 'border-y-8'],
  ] as const)('%s keeps a 48 px target', (size, band) => {
    renderRtl(<Button size={size}>تصفية</Button>);

    const button = screen.getByRole('button', { name: 'تصفية' });
    expect(button).toHaveAttribute('data-size', size);
    // 48 px is the element's height, not a band drawn around a smaller one: a 32 px or 24 px element
    // leaves A4's Save and the dialogs with a target below the 48 px rule (constitution IV).
    expect(button).toHaveClass('h-12');
    expect(button).not.toHaveClass('h-8', 'h-6', 'min-h-12');
    if (band === null) {
      expect(button).not.toHaveClass('border-transparent');
    } else {
      expect(button).toHaveClass(band, 'border-transparent', 'bg-clip-padding');
    }
  });

  it('darkens while pressed', () => {
    renderRtl(<Button variant="primary">حفظ</Button>);

    expect(screen.getByRole('button', { name: 'حفظ' }).className).toContain('active:brightness-95');
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
