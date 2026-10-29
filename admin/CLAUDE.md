# admin/ (Lane A)

The Madar Sat admin: React 18, Vite, TypeScript strict, Tailwind v3 bound to the design tokens, TanStack Query, React Hook Form + Zod, React Router v6. Arabic, RTL, desktop-first (1440 px, usable at 1024 px). It talks only to `app.admin:app` (`/admin/api`), which is reachable only over WireGuard.

Lane A owns this folder and nothing else (delivery-plan §4). Never edit another lane's folder or a generated file.

## Run it

```sh
cd admin
pnpm install                 # pnpm 10 (see packageManager); Node ≥ 22.12
pnpm orval                   # regenerate the client from ../backend/openapi/admin.json
pnpm prism                   # Prism mock of the admin spec on :4010
pnpm dev                     # Vite on :5173; /admin/api is proxied to Prism
```

In dev builds only, a `?mock=<example>` page parameter makes every API call that declares that example send `Prefer: code=<status>, example=<example>` (the status is read from the spec at dev-server start), so Prism answers with that named example. The A1 examples are `login_ok`, `invalid_credentials`, `account_locked` and `validation_error`:

- `http://localhost:5173/login?mock=invalid_credentials` → «إيميل أو باسوورد غلط» and «تبقّت 3 محاولات…»
- `http://localhost:5173/login?mock=account_locked` → the lockout panel counting down from «14:32»
- `http://localhost:5173/login?mock=login_ok` → the A0 shell

Against a local API instead of Prism, point the Vite proxy (`vite.config.ts`) at the backend's admin app.

## Checks (what `admin.yml` runs)

```sh
pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh
```

- `pnpm test`: Vitest + Testing Library + MSW (jsdom). `pnpm test:watch` while working. Render with `renderRtl` from `src/test/render.tsx`, which wraps the RTL root, a query client and a memory router; MSW runs from `src/test/setup.ts` and fails on unhandled requests.
- Tests come first and are seen failing before the code they cover (constitution, Test-first). Every state in a component's README has a test.
- Playwright smoke tests arrive on D11 (delivery-plan §7); until then screens are checked by screenshots against the PNG boards.

## Generated code: never edit by hand

| Path | Generator |
| --- | --- |
| `src/api/generated/` | `pnpm orval` from `../backend/openapi/admin.json`: React Query hooks and TS types (`admin.ts`, `admin.schemas.ts`), Zod schemas (`admin.zod.ts`), and MSW handlers that answer with the spec's named examples (`admin.msw.ts`; Orval can't write them to another folder) |
| `src/styles/tokens.css`, `src/styles/tokens.ts`, `src/assets/fonts/*` | verbatim copies of `madar-design/design-system/` |
| `src/components/Icon/icons.ts` | `node scripts/extract-icons.mjs ../madar-design/admin-react/styles/app.css src/components/Icon/icons.ts` |

- The contract belongs to Lane B1. If the client needs a change, ask B1 to change the spec, then run `pnpm orval` and commit the output. `backend.yml`'s `clients` job fails when the committed output is stale.
- Tokens: change `madar-design/design-system/tokens.json`, run `python3 madar-design/design-system/code/generate_tokens.py`, then copy the generated files and fonts here again. `./scripts/check-token-copy.sh` fails on any difference.
- `src/api/http.ts` is the hand-written axios mutator: same-origin requests (the spec's paths already start with `/admin/api`), `withCredentials`, Zod-parsed responses, and errors turned into `ApiError` with the envelope's `error.code`.

## Visual rules

- Before building a screen, find its row in `madar-design/admin-react/SCREENS.md` (paths there say `new_app/docs/...`; here that is `docs/`), look at the PNG, and read the HTML for structure, Arabic copy and states. The HTML is a mockup: rebuild it with the components, never paste it.
- Short CSS variables in the mockups (`--s1`, `--tx2`, `--acc`) map to tokens in `madar-design/design-system/TOKEN-ALIASES.md`.
- Values come only from tokens. Tailwind's theme is built from `tokens.ts` (`tailwind.config.ts`): colors are `var(--<token>)` (`bg-surface-1`, `text-text-secondary`, `ring-divider`), spacing is `space-*` (`p-4` = 16 px), radii and shadows are the token names. Type sizes come from the tokens.css text styles (`heading-1`, `text-body`, `text-label`, `text-caption`, `text-micro`, `mono-code`). There is no default palette and no arbitrary value (`tailwindcss/no-arbitrary-value` is an error).
- `./scripts/check-literals.sh` fails on hex/rgb colors, `px` values and font names in `src/` outside `src/styles/` and generated folders. Visual CSS that Tailwind can't express goes in `src/styles/global.css`, using token variables.
- Build each component once, under its design-system name (`SidebarNav`, `DataTable`, `Field`, `StatusChip`, `Toast`), with every README state and visible keyboard focus (`focus-visible:outline-focus-ring`).
- Theme: `data-theme="dark"` on `<html>` is the default; `light` is complete too.

## RTL, digits and copy

- The root is `<html lang="ar" dir="rtl">`; the sidebar sits on the right. Use logical utilities (`ps-`, `me-`, `start-`, `border-s`), never `left`/`right`.
- Latin names, source codes, emails, frequencies and keyboard hints are LTR islands (`dir="ltr"` or `<bdi>`), never concatenated into Arabic strings.
- Digits are Western (0–9) with tabular figures; never format numbers or times with the `ar` locale.
- All copy lives in `src/i18n/ar.ts`. API errors render only through `errorCopy` / `copyForErrorCode(error.code)`. `error.message` is never shown.
- The access token lives in memory only (`src/features/auth/session.ts`), never in `localStorage` or `sessionStorage` (FR-034).
