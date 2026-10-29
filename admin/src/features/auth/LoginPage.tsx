import { zodResolver } from '@hookform/resolvers/zod';
import { useState, type ReactElement } from 'react';
import { useForm, type FieldError } from 'react-hook-form';
import { useLocation, useNavigate } from 'react-router-dom';

import { useLogin } from '../../api/generated/admin';
import { loginBody } from '../../api/generated/admin.zod';
import type { ApiError } from '../../api/http';
import { BrandLockup } from '../../components/BrandMark/BrandMark';
import { Field } from '../../components/Field/Field';
import { focusRing } from '../../components/focus';
import { Icon } from '../../components/Icon/Icon';
import { attemptsRemaining, copyForErrorCode, login as copy } from '../../i18n/ar';
import { useSession } from './session';
import { formatCountdown, useCountdown } from './useCountdown';

// A1 (admin board "Login · error + lockout"). Errors render from error.code only; error.message is never shown.

interface LoginFailure {
  code: string;
  attemptsRemaining: number | null;
  lockedUntil: number | null;
}

// The generated login schema (email ≤ 254, password 1–256) reports Zod issue codes; the Arabic copy
// is chosen from the field and the code, so Zod's English messages never reach the screen.
const emailMessage = (error: FieldError | undefined): string | undefined => (error ? copy.emailInvalid : undefined);
const passwordMessage = (error: FieldError | undefined): string | undefined =>
  error ? (error.type === 'too_big' ? copy.passwordTooLong : copy.passwordRequired) : undefined;

function toFailure(error: ApiError, now: number): LoginFailure {
  const { attempts_remaining: attempts, retry_after_s: retryAfter } = error.meta;
  return {
    code: error.code,
    attemptsRemaining: typeof attempts === 'number' ? attempts : null,
    lockedUntil: error.code === 'account_locked' && typeof retryAfter === 'number' ? now + retryAfter * 1000 : null,
  };
}

/** Where the guard sent the editor from; only paths inside the admin are accepted. */
function returnPath(state: unknown): string {
  if (typeof state === 'object' && state !== null && 'from' in state) {
    const { from } = state;
    if (typeof from === 'string' && from.startsWith('/') && !from.startsWith('//')) return from;
  }
  return '/';
}

function ErrorBanner({ message }: { message: string }): ReactElement {
  return (
    <div role="alert" className="flex items-center gap-3 rounded-md bg-error-container px-3 py-2 text-error">
      <Icon name="alert" size="lg" />
      <span className="text-label font-semibold">{message}</span>
    </div>
  );
}

function LockoutPanel({ secondsLeft }: { secondsLeft: number }): ReactElement {
  return (
    <div role="alert" className="flex flex-col gap-3 rounded-lg bg-bg p-4 ring-1 ring-inset ring-divider">
      <div className="flex items-center gap-3">
        <span className="inline-flex size-8 items-center justify-center rounded-sm bg-postponed-container text-postponed">
          <Icon name="clock" size="lg" />
        </span>
        <span className="heading-2">{copy.lockedTitle}</span>
      </div>
      <p className="text-label text-text-secondary">
        {copy.lockedBefore}{' '}
        <b className="font-bold text-text-primary">
          <time dir="ltr" className="tabular-nums">
            {formatCountdown(secondsLeft)}
          </time>
        </b>{' '}
        {copy.lockedAfter}
      </p>
    </div>
  );
}

export function LoginPage(): ReactElement {
  const navigate = useNavigate();
  const location = useLocation();
  const { signIn } = useSession();
  const [failure, setFailure] = useState<LoginFailure | null>(null);
  const [passwordVisible, setPasswordVisible] = useState(false);
  const secondsLocked = useCountdown(failure?.lockedUntil ?? null);
  const locked = failure?.code === 'account_locked' && secondsLocked > 0;

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(loginBody),
    defaultValues: { email: '', password: '' },
    mode: 'onBlur',
  });

  const loginMutation = useLogin({
    mutation: {
      onSuccess: (envelope) => {
        if (!envelope.data) {
          setFailure({ code: 'invalid_response', attemptsRemaining: null, lockedUntil: null });
          return;
        }
        signIn(envelope.data);
        navigate(returnPath(location.state), { replace: true });
      },
      onError: (error) => setFailure(toFailure(error, Date.now())),
    },
  });

  const onSubmit = handleSubmit((values) => {
    setFailure(null);
    loginMutation.mutate({ data: values });
  });

  const pending = loginMutation.isPending;
  const showBanner = failure !== null && failure.code !== 'account_locked';
  const passwordHint =
    failure?.code === 'invalid_credentials' && failure.attemptsRemaining !== null ? attemptsRemaining(failure.attemptsRemaining) : undefined;

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-bg px-6 py-12">
      <div className="login-orbits" aria-hidden="true">
        <i />
        <i />
        <i />
        <u />
      </div>

      <form
        aria-label={copy.formLabel}
        noValidate
        onSubmit={(event) => void onSubmit(event)}
        className="relative flex w-full max-w-list-pane-width flex-col gap-4 rounded-2xl bg-surface-1 p-8 shadow-raised ring-1 ring-inset ring-divider"
      >
        <BrandLockup size="lg" />
        <h1 className="heading-1">{copy.title}</h1>

        {showBanner ? <ErrorBanner message={copyForErrorCode(failure.code)} /> : null}
        {locked ? <LockoutPanel secondsLeft={secondsLocked} /> : null}

        <Field
          label={copy.email}
          type="email"
          autoComplete="username"
          ltr
          leading={<Icon name="mail" className="text-text-tertiary" />}
          invalid={failure?.code === 'invalid_credentials'}
          error={emailMessage(errors.email)}
          {...register('email')}
        />
        <Field
          label={copy.password}
          type={passwordVisible ? 'text' : 'password'}
          autoComplete="current-password"
          ltr
          leading={<Icon name="lock" className="text-text-tertiary" />}
          trailing={
            <button
              type="button"
              aria-label={passwordVisible ? copy.hidePassword : copy.showPassword}
              onClick={() => setPasswordVisible((visible) => !visible)}
              className={`inline-flex size-8 shrink-0 items-center justify-center rounded-pill text-text-secondary hover:bg-surface-2 ${focusRing}`}
            >
              <Icon name={passwordVisible ? 'eyeOff' : 'eye'} />
            </button>
          }
          hint={passwordHint}
          error={passwordMessage(errors.password)}
          {...register('password')}
        />

        <button
          type="submit"
          disabled={pending || locked}
          aria-busy={pending || undefined}
          className={`text-strong h-12 w-full rounded-lg bg-accent text-on-accent hover:brightness-105 disabled:cursor-not-allowed disabled:bg-surface-2 disabled:text-text-disabled disabled:hover:brightness-100 ${focusRing}`}
        >
          {pending ? copy.submitting : copy.submit}
        </button>

        <p className="text-caption flex items-center justify-center gap-2 text-text-tertiary">
          <Icon name="shieldCheck" />
          {copy.wireguardOnly}
        </p>
      </form>
    </div>
  );
}
