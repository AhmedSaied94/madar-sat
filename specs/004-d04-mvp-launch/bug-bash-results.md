# Bug-bash results: D4 · MVP launch

Format: [data-model.md](data-model.md#bug-bash-results-bug-bash-resultsmd-lane-m). The script is
[bug-bash.md](bug-bash.md); every step runs on all three platforms.

**Status: not run.** Every row needs a device or the release, neither of which is available to
Lane M's code work: the Android release build needs the owner's tag `app-v0.3.0` (T070), the
iPhone PWA needs the live channel, and desktop Chrome needs the preview channel after B2's
release job (T045). The code side of T069–T072 is in place; fill this file during the runs.

A **crash** is the app closing, a white or red screen, or a frozen UI. A **blocker** is a step
that can't be finished; both are fixed with a test before the gate. Everything else is
cosmetic and gets a named day.

## Android release build

- Device and OS:
- Build (`app-v0.3.0`, version code):

| Step | Result | Issue or task | Note |
| --- | --- | --- | --- |
| O1–O7 | | | |
| S1–S9 | | | |
| F1–F5 | | | |
| R1–R2 | | | |
| X1–X5 | | | |

Crashes: — · Open blockers: — ·

## iPhone PWA (iOS ≥ 16.4, installed)

- Device and iOS version:
- Release (`release.json` hash):

| Step | Result | Issue or task | Note |
| --- | --- | --- | --- |
| O1–O7 | | | |
| S1–S9 | | | |
| F1–F5 | | | |
| R1–R2 | | | |
| X1–X3, X5–X6 | | | |

Crashes: — · Open blockers: — ·

## Desktop Chrome, 1440 × 900

- Chrome version:
- Release (`release.json` hash):

| Step | Result | Issue or task | Note |
| --- | --- | --- | --- |
| O1–O4, O6–O7 | | | |
| S1–S9 | | | |
| F1–F5 | | | |
| X1–X3, X5–X6 | | | |

Crashes: — · Open blockers: — ·

## Timings (T072, research R13)

| Run | Network | First data | Repeat open | Bytes from the mirror |
| --- | --- | --- | --- | --- |
| 1 | Chrome "Fast 4G" (≈ 9 Mbps, 150 ms RTT) | | | |
| 2 | A real phone on mobile data | | | |

Targets: first data < 5 s on Fast 4G, repeat open < 1.5 s, ≥ 90 % of first-load bytes from
`app.<ip1>.sslip.io` (SC-008a). `?perf=1` logs `[madar-perf] bootstrap` and
`[madar-perf] flutter-first-frame` (`docs/runbooks/firebase-hosting.md`, "Check a release in
DevTools").

## Cosmetic issues

| Issue | Platform | Target day |
| --- | --- | --- |
