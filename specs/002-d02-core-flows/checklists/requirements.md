# Specification Quality Checklist: D2 · Core flows

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-30
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs). *Exception, see Notes.*
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders. *Exception, see Notes.*
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain. *Q1–Q3 answered by the owner on 2026-10-30 (spec Clarifications).*
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details). *Exception, see Notes.*
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification. *Exception, see Notes.*

## Notes

- **Why the spec names technology (accepted exception, as on D1).** The stack is fixed by the constitution (Platform, Stack and Content Constraints), and delivery-plan Appendix A requires each lane story to use its brief row's acceptance as written: argon2id, JWT, `If-Match`, `locked_fields`, `SourceAdapter`, Orval, drift. Stripping the names would make the stories untestable. Success criteria stay outcome-based (seconds, counts, pass rates), except where the brief's acceptance is itself technical (SC-002, SC-005). SC-010 is the brief's done check, copied word for word.
- **The audience is the owner and the four lanes**, not non-technical stakeholders (delivery-plan §5.2).
- **Decisions taken by default, recorded in Assumptions for the owner's review:**
  - the admin runs on the editor's machine over WireGuard on D2; the `wg0` deploy stays on D4;
  - bulk channel removal is the only `admin`-role action today;
  - unmatched names are logged per run until D5's queue (a constitution II deviation for `plan.md` Complexity Tracking);
  - my satellites use the O10 default until D3's picker;
  - B1 creates the Celery app `app.workers`, and B2's tasks live under `backend/app/adapters/`.
- **Scope check against the brief:** every item in the D2 brief rows maps to an acceptance scenario or FR. Three additions follow from the brief's own acceptance or the constitution, not new scope: the VPS-2 worker deploy (FR-029, needed for "without opening a browser"), the 45-minute duplicate guard (FR-022, SD §6.6, so the bridge and ysscores don't double rows), and the read-only broadcast presets list (FR-007, needed by A4's slots).
- **Clarifications resolved (2026-10-30):**
  - Q1, home box: an x86-64 Linux box. CI adds a `linux/amd64` variant of the backend image for it alone; `plan.md` records it against constitution IX (FR-028, FR-029).
  - Q2, bridge scope: fixtures plus channel links, hidden flags and per-channel commentators. FR-008 now makes any link an editor edits a `manual` link, so the bridge never overwrites an editor's change (FR-027, Edge Cases).
  - Q3, Playwright smoke: D4, with the `wg0` deploy; `plan.md` records the reading of the constitution's "once those flows exist" (FR-054).
- Validation: iteration 2. Every item passes, with the exceptions above.
