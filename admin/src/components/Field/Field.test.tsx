import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createRef } from 'react';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { Field } from './Field';

describe('Field', () => {
  it('puts the label above the input and wires it to the input', () => {
    renderRtl(<Field label="الملعب" defaultValue="سان سيرو" />);

    const input = screen.getByLabelText('الملعب');
    expect(input).toHaveValue('سان سيرو');
    expect(input).not.toHaveAttribute('placeholder');
  });

  it('describes the input with its hint', () => {
    renderRtl(<Field label="الجولة" hint="مثل: الجولة 9" />);

    expect(screen.getByLabelText('الجولة')).toHaveAccessibleDescription('مثل: الجولة 9');
  });

  it('shows the focus ring when the input has keyboard focus', async () => {
    renderRtl(<Field label="الجولة" />);

    await userEvent.tab();
    const input = screen.getByLabelText('الجولة');
    expect(input).toHaveFocus();
    expect(screen.getByTestId('field-control')).toHaveClass('focus-within:ring-focus-ring');
  });

  it('shows the error outline and message, and marks the input invalid', () => {
    renderRtl(<Field label="التردد" error="الاستقطاب يجب أن يكون H أو V أو L أو R" ltr mono defaultValue="11843 X 29900" />);

    const input = screen.getByLabelText('التردد');
    expect(input).toHaveAttribute('aria-invalid', 'true');
    expect(input).toHaveAccessibleDescription('الاستقطاب يجب أن يكون H أو V أو L أو R');
    expect(screen.getByTestId('field-control')).toHaveAttribute('data-state', 'error');
    expect(screen.getByTestId('field-control')).toHaveClass('ring-error');
  });

  it('marks a locked value with a lock glyph and the importer hint', () => {
    renderRtl(<Field label="المعلق" locked defaultValue="بلال علام" />);

    const input = screen.getByLabelText(/المعلق/);
    expect(input).toHaveAccessibleDescription('لن يغيّره الاستيراد');
    expect(screen.getByTestId('field-control')).toHaveAttribute('data-state', 'locked');
    expect(screen.getByTestId('field-lock')).toBeInTheDocument();
    expect(input).toBeEnabled();
  });

  it('disables the input', () => {
    renderRtl(<Field label="معطل" disabled defaultValue="—" />);

    expect(screen.getByLabelText('معطل')).toBeDisabled();
    expect(screen.getByTestId('field-control')).toHaveAttribute('data-state', 'disabled');
  });

  it('renders frequency-style values as an LTR mono island', () => {
    renderRtl(<Field label="التردد" ltr mono defaultValue="11843 H 27500" />);

    const input = screen.getByLabelText('التردد');
    expect(input).toHaveAttribute('dir', 'ltr');
    expect(input).toHaveClass('font-mono');
  });

  it('forwards the ref and input props for React Hook Form', async () => {
    const ref = createRef<HTMLInputElement>();
    const onChange = vi.fn();
    renderRtl(<Field ref={ref} label="البريد الإلكتروني" name="email" type="email" onChange={onChange} />);

    await userEvent.type(screen.getByLabelText('البريد الإلكتروني'), 'a');
    expect(ref.current).toBe(screen.getByLabelText('البريد الإلكتروني'));
    expect(ref.current).toHaveAttribute('name', 'email');
    expect(onChange).toHaveBeenCalled();
  });
});
