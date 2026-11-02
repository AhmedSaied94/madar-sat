import type { ReactElement } from 'react';

import { focusRing } from '../focus';

// The admin's logo field (design-system Logo README): the current or freshly chosen logo on a dark
// and on a light neutral frame, so a dark-only crest can be judged on both grounds (T095, A-R1-6).
// Each frame forces its own theme, so the pair is the same whatever theme the admin is in.

interface LogoFieldProps {
  /** «الشعار» */
  label: string;
  /** «على خلفية داكنة» */
  darkLabel: string;
  /** «على خلفية فاتحة» */
  lightLabel: string;
  /** «رفع شعار» */
  uploadLabel: string;
  /** The logo shown in both frames; the record's, or the one just uploaded. */
  url: string | null;
  onUpload: (file: File) => void;
  /** A round frame, for the commentator's portrait. */
  round?: boolean;
}

export function LogoField({
  label,
  darkLabel,
  lightLabel,
  uploadLabel,
  url,
  onUpload,
  round = false,
}: LogoFieldProps): ReactElement {
  const frame = round ? 'rounded-pill' : 'rounded-md';
  const frames = [
    { theme: 'dark', caption: darkLabel },
    { theme: 'light', caption: lightLabel },
  ] as const;

  return (
    <div className="flex flex-col gap-2">
      <span className="text-caption font-semibold text-text-secondary">{label}</span>
      <div className="flex flex-wrap items-end gap-3">
        {frames.map(({ theme, caption }) => (
          <figure key={theme} className="flex flex-col items-center gap-1">
            <span
              data-theme={theme}
              data-testid={`logo-tile-${theme}`}
              className={`flex size-12 items-center justify-center overflow-hidden ring-1 ring-inset ring-divider ${frame} bg-surface-2`}
            >
              {url ? (
                <img src={url} alt="" className={round ? 'size-12 object-cover' : 'size-8 object-contain'} />
              ) : (
                <span className="text-caption text-text-tertiary">—</span>
              )}
            </span>
            <figcaption className="text-micro text-text-tertiary">{caption}</figcaption>
          </figure>
        ))}

        <label
          className={`text-label inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-lg bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3 has-[:focus-visible]:outline has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-focus-ring ${focusRing}`}
        >
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp"
            className="sr-only"
            aria-label={uploadLabel}
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) onUpload(file);
            }}
          />
          {uploadLabel}
        </label>
      </div>
    </div>
  );
}
