# Proposed Workflow Unification (Planning + Re-optimization)

Status: Draft (implementation plan)
Branch: proposed-schedule-optimization
Owner: Scheduling/GUI

## Goal
Unify the “Proposed schedule” preview workflow across both modes:
- Planning mode (NOW before first case)
- Re-optimization mode (NOW after first case)

So users can preview, accept, or discard changes consistently, with scope controls (unscheduled‑only, respect locks, prefer current labs) functional in both contexts.

## Why
- DRY: a single pipeline (routing, scope handling, staleness, undo).
- Safety: avoid accidental destructive changes by previewing even in planning.
- Clarity: identical controls and semantics, fewer mental models.

## Non‑Goals
- Changing solver behavior or objectives.
- Introducing new constraints beyond already planned “earliest start”, resource capacity, locks.

## UX/Behavior
- Preview option in planning
  - Add a “Preview changes (Proposed tab)” toggle in the Optimization panel.
  - Default: OFF in planning (direct apply), ON in re‑optimization.
  - If ON (or in re‑optimization): run to Proposed, show summary, Accept/Discard/Undo.

- Scope controls in planning
  - Visible and functional before NOW moves.
  - “Unscheduled‑only”: Freeze all currently scheduled cases as locks and schedule only the unscheduled pool around them.
  - “Respect locks”: User‑locked cases remain locked.
  - “Prefer current labs”: Soft penalty applied (existing LabChangePenalty wiring).

- Summary logic
  - When no baseline exists (first run): hide moved/unchanged counts; show “Scheduled N cases” + conflicts.
  - When a baseline exists: show moved/unchanged as today.

- Read‑only schedule during proposal
  - Use the glass‑pane overlay to make the original Schedule tab non‑interactive while a proposal is open.
  - Allow tab switching to compare, but block all edits until Accept/Discard.

- Staleness
  - Any context changes (NOW move, options, labs/resources) increment the change counter; banner appears in Proposed with “Re‑run with current state.”

## Implementation Plan (phased)

Phase 1 — Routing + Controls
1. Add `app.EnablePreviewInPlanning` (logical, default false). Persist in `app.Opts` if desired.
2. Optimization panel: add a checkbox “Preview changes (Proposed tab)” near scope controls. Show always; tooltips clarify defaults per mode.
3. Execute routing: in `OptimizationController.executeOptimization` choose Proposed vs direct apply with:
   - `useProposed = isReoptimizationMode() || app.EnablePreviewInPlanning;`
   - If `useProposed`: set `app.ProposedSchedule/Outcome/Metadata`, `ProposedSourceVersion`, show Proposed tab; else apply directly.
4. Scope controls: enable/always functional in planning; ensure unscheduled‑only logic freezes scheduled context (existing code path) also when not in re‑opt.

Phase 2 — Summary + Read‑only
5. Proposed summary: update `updateProposedSummary` to handle “no baseline” (first run) gracefully — show counts without moved/unchanged.
6. Read‑only overlay: create a transparent panel over Schedule axes when a proposal exists; remove it on Accept/Discard/hideProposedTab.

Phase 3 — Staleness + Undo polish
7. Ensure `ProposedSourceVersion` is set in planning preview; staleness banner appears on subsequent context changes.
8. Undo paths remain unchanged; test Accept/Discard in planning.

Phase 4 — Tests
9. CLI tests (MATLAB -batch):
   - Planning + Preview: unscheduled‑only freezes scheduled cases; Accept applies; Discard keeps schedule.
   - Planning + Direct apply: unchanged behavior when Preview is OFF.
   - Resource highlights and capacity constraints: future/locked usage reduces capacity; unscheduled cases scheduled in feasible gaps only.
   - Re‑optimization unaffected.

## File Touchpoints
- `scripts/+conduction/+gui/+app/buildOptimizationTab.m`
  - Add “Preview changes (Proposed tab)” checkbox under optimization controls.
- `scripts/+conduction/+gui/+controllers/OptimizationController.m`
  - Routing: compute `useProposed`; set Proposed fields + show tab in planning when preview enabled.
- `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
  - Add `EnablePreviewInPlanning` property (and session save/load if we persist it).
  - `showProposedTab`, `hideProposedTab`: also manage read‑only overlay lifecycle.
  - `updateProposedSummary`: handle empty baseline case.
- `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m` or a small helper
  - Glass‑pane overlay management (create/destroy; z‑order; resize handling).

## Risks & Mitigations
- First‑time “preview” feels heavier than direct apply
  - Default preview OFF in planning preserves current one‑click flow; users opt‑in to preview.
- Missed mutation paths while read‑only
  - Overlay blocks pointer events; belt‑and‑suspenders: keep drag/resize disabled during proposal.
- Confusion on summary without baseline
  - Tailor summary text for first runs; keep conflicts and counts clear.

## Acceptance Criteria
- With Preview ON in planning, Optimize routes to Proposed, respects scope options, and Accept/Discard works.
- With Preview OFF in planning, Optimize applies directly; behavior unchanged.
- Scope options work identically in both modes; unscheduled‑only freezes scheduled context; resources respected.
- Staleness banner appears when context changes; “Re‑run with current state” works.
- Schedule tab is non‑interactive during proposal via overlay.

## Rollback
- Remove the preview checkbox and planning‑mode routing; revert to current behavior (Proposed only in re‑optimization).

