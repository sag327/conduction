# Future Work and Post-Preview Roadmap

This document tracks follow‑ups and enhancements planned after the Phase 1–4 unified‑timeline milestones. Items are grouped by theme and prioritized by impact/risk.

## Locking Model Cleanup (pre‑release)
- Single source of truth: finalize cutover to per‑case `IsUserLocked` + auto‑lock (derived from NOW).
- Remove legacy artifacts:
  - Delete `app.LockedCaseIds`, `app.TimeControlLockedCaseIds`, `app.TimeControlBaselineLockedIds` usage and definitions.
  - Remove writes/reads of `ProspectiveCase.IsLocked` (retain property only if needed for temporary compatibility; otherwise remove).
  - Drop session serialization/deserialization of legacy `isLocked` fields.
  - Remove `scripts/+conduction/+gui/+utils/LockMigration.m` and call sites.
- Renderer hygiene:
  - Eliminate any remaining code paths that push legacy lock state from renderer into models.
  - Keep on‑demand computation of locked IDs from `CaseManager` using `getComputedLock(now)`.

Risk: Low–medium. Critical paths already run off per‑case locks; risk is missed references. Add a short CLI smoke (see Testing) when executing this cleanup.

## Testing & CI
- CLI regression tests (MATLAB `-batch`) for re‑optimization flows:
  - Unscheduled‑only overlay preserves post/turnover for future‑locked cases.
  - Per‑lab earliest‑start enforcement (multi‑lab, in‑progress, midnight on/off, varied `TimeStep`).
  - Scope controls: include unscheduled only vs future; “respect locks = off” yields feasible runs.
  - Proposed summary: moved/unchanged under time change, lab change, and reorder.
- Add a minimal test harness entry (e.g., `tests/matlab/ReoptSmoke.m`) to run on local automation.
- Optional: wire a lightweight CI job (local script) to run the above on demand.

## Scheduling Enhancements
- Prefer current labs tuning
  - Expose a UI slider or preset for `LabChangePenalty`; document expected range and side effects.
  - Consider operator‑specific or case‑class‑specific weights.
- Per‑lab open/close windows (future feature)
  - Extend `SchedulingOptions` with per‑lab day boundaries.
  - Use these with earliest‑start lower bounds to disallow scheduling outside lab hours.
- Operator availability calendars (future feature)
  - Parameterize per‑operator availability windows; integrate into model constraints.

## Selection & Bulk Actions
- Extend multi‑case selection with additional bulk operations beyond Remove Selected (e.g., bulk lock/unlock, bulk resource assignment, and future bulk drag/move if UX risk is acceptable).
- Add keyboard shortcuts for selection workflows (e.g., Delete to remove selected cases, Esc to clear selection) while keeping selection ephemeral and not persisted in session files.

## Proposed Tab & UX Polish
- Conflict detail expansion
  - Enrich conflict reporting beyond resource violations (e.g., feasibility breakdown, operator windows).
- Undo UX
  - Keyboard shortcut for Undo toast; make duration configurable in settings.
- Staleness behavior
  - Current banner works; consider live auto‑dismiss if a fresh proposal lands or proactively refresh on key mutations.
- Proposed‑NOW sandbox
  - Optional “Proposed NOW” override inside the Proposed tab so users can adjust locks and scope within the preview without mutating the baseline NOW; copy it back to the main timeline only on explicit action.
- Interactive Proposed editing
  - Revisit enabling drag/resize edits directly in the Proposed tab using axes‑aware drag/resize context, while keeping changes non‑destructive until Accept/Discard.

### Proposed vs Original Schedule Comparison (new)
Goal: Let users compare a Proposed schedule against the current (original) schedule while a proposal is pending, without allowing edits to the original until Accept/Discard.

Two implementation options
- Option A — Glass Pane Overlay (simplest, safest)
  - When a proposal exists, place a transparent panel above `ScheduleAxes` to swallow pointer events (click/drag/scroll) so the original schedule becomes strictly view‑only.
  - Add a subtle banner: “Read‑only — pending proposal (Accept/Discard in Proposed).” Optionally dim the schedule slightly.
  - Pros: Minimal code, hard to bypass, no need to gate every callback.
  - Cons: Users cannot click through to open the drawer from the original schedule during comparison.
  - Hooks: Create in `showProposedTab` (or when `HasPendingProposal` becomes true); remove in Accept/Discard and `hideProposedTab(true)`; keep overlay sized with layout/resize.

- Option B — Read‑Only Gating with Click‑to‑Inspect
  - Allow clicking cases on the original schedule to open the drawer for details, but disable all mutating interactions until Accept/Discard.
  - Disable: drag/reorder, resize, context menus that mutate; lock/unlock; duration/resource edits; Optimize/Run buttons; keyboard mutations.
  - Allow: case clicks to inspect; scrolling/zoom; Proposed tab Accept/Discard.
  - Pros: Better comparison/inspection; preserves proposal integrity.
  - Cons: Requires gating at multiple layers (renderer, drawer, top‑bar); higher surface to miss a mutation path.
  - Hooks: A centralized `IsCanvasReadOnly = HasPendingProposal` flag checked by renderer (skip `enableCaseDrag` etc.), drawer (disable editors), and top‑bar (disable mutate actions). Moving NOW should increment `OptimizationChangeCounter` to mark Proposed stale.

Acceptance (either option)
- With a pending proposal, original schedule cannot be modified; Accept/Discard restores normal editing.
- Moving NOW while pending marks Proposed stale and shows the banner.
- Optional: linked selection/diff cues can be added later for richer comparison.

## Performance & Accessibility
- Large schedules
  - Validate rendering performance with many labs/cases; consider list/axes virtualization if needed.
- Accessibility
  - Keyboard navigation across tabs and controls; high‑contrast theme audit.
  - Keyboard shortcuts for core actions (optimize/re‑optimize, undo, selection) and screen‑reader‑friendly announcements for NOW changes and case status updates.

## Packaging & Logging
- Follow the open TODOs in `docs/Executable-Packaging-Preflight-Plan.md` for runtime logging, entry wrapper, and artifact metadata.

## Quick Acceptance Checklist (for each release cut)
- Re‑optimization (future + unscheduled‑only) respects user locks and pre‑NOW frozen context.
- Proposed tab summary and staleness banner behave as expected.
- No cases scheduled before per‑lab earliest starts in re‑opt.
- Visual post/turnover preserved for all future‑locked cases.
