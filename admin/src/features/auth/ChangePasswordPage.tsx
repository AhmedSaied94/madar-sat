import { zodResolver } from '@hookform/resolvers/zod';
import { useState, type ReactElement } from 'react';
import { useForm } from 'react-hook-form';
import { useLocation, useNavigate } from 'react-router-dom';
import { z } from 'zod';

import { useChangePassword } from '../../api/generated/admin';
import { ApiError, INVALID_RESPONSE } from '../../api/http';
import { BrandLockup } from '../../components/BrandMark/BrandMark';
import { Field } from '../../components/Field/Field';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { changePassword as copy, copyForErrorCode } from '../../i18n/ar';
import { useSession } from './session';

// The forced step (contract admin-screens "Change password"): no board draws it, so it is A1's form —
// current, new, confirm, validated here and again by the server. Nothing else renders until it is done,
// and a success keeps this session, clears the flag and returns to the page that sent the editor here.

const MIN_LENGTH = 12;

const schema = z
  .object({
    current_password: z.string().min(1),
    new_password: z.string().min(MIN_LENGTH, copy.tooShort),
    confirm_password: z.string().min(1),
  })
  .refine((values) => values.new_password === values.confirm_password, {
    path: ['confirm_password'],
    message: copy.mismatch,
  });

type FormValues = z.infer<typeof schema>;

/** Where the guard sent the editor from; only paths inside the admin are accepted. */
function returnPath(state: unknown): string {
  if (typeof state === 'object' && state !== null && 'from' in state) {
    const { from } = state;
    if (typeof from === 'string' && from.startsWith('/') && !from.startsWith('//') && !from.startsWith('/change-password')) {
      return from;
    }
  }
  return '/';
}

export function ChangePasswordPage(): ReactElement {
  const navigate = useNavigate();
  const location = useLocation();
  const { signIn } = useSession();
  const [failure, setFailure] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { current_password: '', new_password: '', confirm_password: '' },
    mode: 'onBlur',
  });

  const change = useChangePassword({
    mutation: {
      onSuccess: (envelope) => {
        const session = envelope.data;
        if (!session) {
          setFailure(INVALID_RESPONSE);
          return;
        }
        signIn(session);
        navigate(returnPath(location.state), { replace: true });
      },
      onError: (error) => setFailure(error instanceof ApiError ? error.code : INVALID_RESPONSE),
    },
  });

  const onSubmit = handleSubmit((values) => {
    setFailure(null);
    change.mutate({ data: { current_password: values.current_password, new_password: values.new_password } });
  });

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-bg px-6 py-12">
      <form
        aria-label={copy.title}
        noValidate
        onSubmit={(event) => void onSubmit(event)}
        className="relative flex w-full max-w-list-pane-width flex-col gap-4 rounded-2xl bg-surface-1 p-8 shadow-raised ring-1 ring-inset ring-divider"
      >
        <BrandLockup size="lg" />
        <h1 className="heading-1">{copy.title}</h1>
        <p className="text-body text-text-secondary">{copy.lead}</p>

        {failure ? (
          <div role="alert" className="flex items-center gap-3 rounded-md bg-error-container px-3 py-2 text-error">
            <Icon name="alert" size="lg" />
            <span className="text-label font-semibold">{copyForErrorCode(failure)}</span>
          </div>
        ) : null}

        <Field
          label={copy.current}
          type="password"
          autoComplete="current-password"
          ltr
          leading={<Icon name="lock" className="text-text-tertiary" />}
          error={errors.current_password ? copyForErrorCode('validation_error') : undefined}
          {...register('current_password')}
        />
        <Field
          label={copy.next}
          type="password"
          autoComplete="new-password"
          ltr
          hint={copy.hint}
          leading={<Icon name="lock" className="text-text-tertiary" />}
          error={errors.new_password?.message}
          {...register('new_password')}
        />
        <Field
          label={copy.confirm}
          type="password"
          autoComplete="new-password"
          ltr
          leading={<Icon name="lock" className="text-text-tertiary" />}
          error={errors.confirm_password?.message}
          {...register('confirm_password')}
        />

        <button
          type="submit"
          disabled={change.isPending}
          aria-busy={change.isPending || undefined}
          className={`text-strong h-12 w-full rounded-lg bg-accent text-on-accent hover:brightness-105 disabled:cursor-not-allowed disabled:bg-surface-2 disabled:text-text-disabled ${focusRing}`}
        >
          {change.isPending ? copy.submitting : copy.submit}
        </button>
      </form>
    </div>
  );
}
