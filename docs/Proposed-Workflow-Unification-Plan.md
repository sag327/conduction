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
- Unified Proposed workflow in both modes
  - Always route optimization to the Proposed tab (planning and re‑opt), with one exception below.
  - Read‑only original Schedule view while a proposal is present (glass‑pane overlay), so users can compare without editing.

- Auto‑apply on first optimize (no baseline)
  - When no baseline exists (i.e., there is no prior OptimizedSchedule), auto‑apply the computed schedule immediately.
  - Show an Undo toast: “Initial plan applied” with an Undo action that restores the pre‑opt state.
  - Optionally keep a Proposed payload for summary/compare; summary should show “Scheduled N cases” (no moved/unchanged).
  - No user preference for this — behavior is hard‑wired.

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

- KPI metrics in Proposed
  - KPIs (utilization/idle/flip and KPI bar) recalculate dynamically for the Proposed schedule whenever the proposal changes: after a re‑optimization, after interactive edits (drag/resize/lock), after drawer resource assignments, and after Proposed‑NOW adjustments.
  - The same AnalyticsRenderer routines are reused; Proposed passes the Proposed schedule to the KPI update calls (axes‑agnostic where applicable) to keep behavior DRY.

## Proposed‑NOW Sandbox (Dual‑NOW Model)

Goal: Allow moving the NOW line inside the Proposed tab for bulk operations (e.g., locking several cases at once) without mutating the global NOW or other global context until the user accepts.

What this means
- Dual NOW values:
  - Baseline NOW: `app.NowPositionMinutes` (global; drives main Schedule and status).
  - Proposed NOW: `app.ProposedNowMinutes` (sandbox override; NaN means “mirror baseline NOW”).
- Proposed NOW is draggable on the Proposed tab only and affects only the preview and re‑optimization scope/locks performed from within Proposed. Baseline NOW remains unchanged unless explicitly applied.

Data model additions
- `app.ProposedNowMinutes` (double; NaN when unset).
- `app.ProposedLockOverrides` (string[]): case IDs locked in the Proposed sandbox (e.g., by “lock before Proposed NOW” action or per‑case toggles).
- `app.ProposedMetadata.ProposedSourceNowMinutes` (double) to record the NOW used when the proposal was generated (for staleness detection).

UI behavior
- Proposed tab shows a draggable NOW line (using Proposed NOW if set; otherwise the baseline NOW). The original baseline NOW may be drawn as a thin dashed reference line for orientation.
- Actions row in Proposed:
  - “Lock cases before Proposed NOW” — updates `app.ProposedLockOverrides` only (no baseline changes).
  - “Apply Proposed NOW to Baseline” — optional one‑click to copy Proposed NOW to `app.NowPositionMinutes`.
  - “Reset Proposed NOW” — clears override (mirror baseline again).
- Editing and dragging within Proposed operate against `app.ProposedSchedule` and `app.ProposedLockOverrides` (sandbox), not the baseline schedule/locks.

Threading into solver (no global mutation)
- When executing optimization from Proposed, pass an explicit `nowMinutes` override sourced from `app.ProposedNowMinutes` (fallback to baseline when NaN):
  - Case filtering: `CaseManager.filterCasesByNowPosition(cases, nowOverride, includeScheduledFuture)`.
  - Future locks (unscheduled‑only): build from `nowOverride` via `buildFutureLocksFromCaseStore` / `extractFutureScheduledAssignments`.
  - Earliest starts per lab: compute using `nowOverride` in `computeLabEarliestStartsFromSchedule` so model time grids enforce “no placements before Proposed‑NOW”.
- Rendering in Proposed uses `annotateScheduleWithDerivedStatus(app, schedule, nowOverride)` so statuses match the sandbox time.

Accept/Discard semantics
- Accept copies the Proposed schedule to baseline as usual. Baseline NOW is not changed unless the user chooses “Apply Proposed NOW to Baseline”. Sandbox locks (`ProposedLockOverrides`) are merged into baseline locks only on Accept.
- Discard clears `app.ProposedSchedule`, `app.ProposedNowMinutes`, and `app.ProposedLockOverrides` (baseline remains untouched).

Staleness rules
- Record `ProposedSourceNowMinutes` when the proposal is generated. If `app.ProposedNowMinutes` changes from that value, show a non‑blocking banner in Proposed: “Proposed NOW changed; re‑run to enforce.”
- Baseline context mutations (labs/resources/options/locks) still increment the shared `OptimizationChangeCounter` and can also mark the proposal stale.

Implementation notes (DRY/KISS)
- Generalize NOW drag to be axes‑aware:
  - Add `enableNowLineDragOnAxes(app, axes, commitFcn)` and reuse it for main Schedule (commit = `app.setNowPosition`) and Proposed (commit = set `app.ProposedNowMinutes` + re‑annotate Proposed + mark proposal stale).
  - Refactor existing NOW drag helpers to accept an axes handle instead of using only `app.ScheduleAxes`.
- Do not alter `app.setNowPosition` from Proposed; only mutate `app.ProposedNowMinutes` inside the sandbox.

CLI tests (headless)
- Filtering honors Proposed‑NOW:
  - Build a mixed set; assert `filterCasesByNowPosition` with `nowOverride` excludes only pre‑NOW starts.
- Earliest‑start bounds:
  - With an in‑progress case before Proposed‑NOW, computed per‑lab earliest start ≥ case end + post + turnover.
- Unscheduled‑only locks:
  - Future locks built from Proposed‑NOW are included and preserve post/turnover; Proposed overlay shows all frozen future cases.
- Accept/Discard:
  - Accept does not change baseline NOW unless explicitly applied; Discard resets Proposed NOW and sandbox locks.

- KPI recomputation (Proposed):
  - After a Proposed edit (e.g., drag one case +10 min), recompute KPIs against the Proposed schedule and assert KPI labels or computed metrics change consistently with the delta.

## Implementation Plan (phased)

Phase 1 — Routing (unified) + Auto‑apply first run
1. Routing: in `OptimizationController.executeOptimization`
   - Compute `hasBaseline = ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments())`.
   - Always build Proposed payload; set `app.ProposedSchedule/Outcome/Metadata`, `ProposedSourceVersion = app.OptimizationChangeCounter`.
   - If `hasBaseline` → show Proposed tab (read‑only overlay active).
   - If not `hasBaseline` → auto‑apply direct to `OptimizedSchedule`; show Undo toast; keep Proposed optional for summary.
2. Scope in planning: ensure existing unscheduled‑only logic also runs when NOW is before first case (freeze all scheduled cases as locks).

Phase 2 — Summary + Read‑only overlay
3. Proposed summary: Detect no‑baseline and render “Scheduled N cases” instead of moved/unchanged.
4. Read‑only overlay: create/remove overlay panel over `ScheduleAxes` while proposal exists; same logic as re‑opt.

Phase 3 — Staleness + Undo polish
5. Set `ProposedSourceVersion` on proposal generation; staleness banner appears on context changes (NOW move, options, labs/resources).
6. Undo: keep existing Accept/Discard/Undo actions; validate Undo after auto‑apply on first run restores the pre‑opt state.

Phase 4 — CLI Tests (MATLAB `-batch`)
7. Test: initial optimize auto‑applies (no extra click)
   ```matlab
   app = conduction.launchSchedulerGUI(); pause(0.5);
   % Add cases
   for i=1:3
     app.OperatorField.Value = sprintf('Op%d',i);
     app.ProcedureField.Value = sprintf('Proc%d',i);
     app.ProcedureTimeField.Value = 60; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
   end
   % Optimize: should apply directly (no baseline)
   app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []); pause(1);
   assert(~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments()), 'Initial plan not applied');
   % Undo toast exists and Undo restores empty schedule
   app.triggerUndoAction(); pause(0.5);
   assert(isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments()), 'Undo did not restore empty state');
   delete(app);
   ```
8. Test: planning Proposed preview + scope
   ```matlab
   app = conduction.launchSchedulerGUI(); pause(0.5);
   % Build a baseline plan
   app.OperatorField.Value='A'; app.ProcedureField.Value='P'; app.ProcedureTimeField.Value=60; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
   app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []); pause(0.5);
   % Add unscheduled case and run again; should open Proposed
   app.OperatorField.Value='B'; app.ProcedureField.Value='P2'; app.ProcedureTimeField.Value=45; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
   app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []); pause(0.5);
   assert(~isempty(app.ProposedTab.Parent), 'Proposed should be visible in planning with baseline');
   % Enable unscheduled-only
   app.onScopeIncludeChanged("unscheduled"); pause(0.2);
   app.onProposedRerun(); pause(0.5);
   % Accept applies
   app.onProposedAccept(); pause(0.5);
   assert(~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments()), 'Accept did not apply');
   delete(app);
   ```
9. Test: resource capacity with locked context in planning
   ```matlab
   app = conduction.launchSchedulerGUI(); pause(0.5);
   % Create resource type and assign to baseline case
   store = app.CaseManager.getResourceStore(); store.create("Device A",1);
   app.OperatorField.Value='X'; app.ProcedureField.Value='Q'; app.ProcedureTimeField.Value=120; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
   % Assign resource via drawer or directly on case
   [c,~]=app.CaseManager.getCase(1); c.assignResource("device-a");
   app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []); pause(0.5);
   % Add unscheduled case requiring same resource
   app.OperatorField.Value='Y'; app.ProcedureField.Value='Q'; app.ProcedureTimeField.Value=60; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
   [c2,~]=app.CaseManager.getCase(2); c2.assignResource("device-a");
   % Run planning Proposed, unscheduled-only: second case must be placed around baseline resource window
   app.onScopeIncludeChanged("unscheduled"); app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []); pause(0.5);
   assert(~isempty(app.ProposedSchedule), 'No proposed result');
   % Optionally inspect Proposed schedule windows for overlap (manual)
   delete(app);
   ```
10. Test: re‑optimization unchanged (existing Proposed path and staleness banner) — smoke as already documented.

---

## Proposed Tab Interactivity (Sandbox)

Enable full interactivity in Proposed so users can test edits before Accept. The Proposed tab should behave like the main Schedule: case highlighting, clicking (drawer), locking/unlocking, and (where supported) dragging/resizing — while all mutations apply only to `app.ProposedSchedule` until Accepted.

### Goals
- Case selection/highlight and multi‑select overlays work in Proposed.
- Clicking a case opens the drawer; drawer edits (resources, admission, lock) update the corresponding ProspectiveCase and reflect in Proposed overlays.
- Lock/unlock via drawer updates proposal visuals and summary.
- Drag/resize (if supported in main Schedule) act on ProposedSchedule only, not on OptimizedSchedule, until Accept.
- Resource legends and highlights update in Proposed (already wired); overlays reflect drawer changes immediately.

### Design (DRY/KISS)
- Parameterize ScheduleRenderer interactions by axes + schedule context:
  - Add helpers `enableCaseInteractionOnAxes(app, axes, context)` that call existing `enableCaseDrag`, selection overlays, and callbacks but target the provided axes.
  - Context carries pointers to: target axes (ProposedAxes), get/set schedule (read/write `app.ProposedSchedule`), and callbacks for post‑mutation refresh (refresh Proposed summary + overlays only).
- CaseDragController registry supports multiple axes:
  - Register CaseBlock handles from ProposedAxes in the controller (extend registry to index by axes/handle key, already keyed by handle).
  - Motion/hover uses the hovered handle to resolve position/selection; axes resolved via handle ancestor (already in `resolveSelectionGeometry`).
- Drawer & locking:
  - Keep drawer actions writing to ProspectiveCase (unchanged), then refresh Proposed overlays and summary.
  - Lock/unlock affects auto/user lock visuals and future constraints on Accept.
- Prevent mutating OptimizedSchedule:
  - All Proposed interactions must not write to `OptimizedSchedule`.
  - Accept: promote `ProposedSchedule` → `OptimizedSchedule` (existing path) and re-render main Schedule.

### Touchpoints
- `ProspectiveSchedulerApp.renderProposedSchedule`
  - Use same callbacks as Schedule tab:
    - `CaseClickedFcn`, `BackgroundClickedFcn` pointing to `app.onScheduleBlockClicked` / `app.onScheduleBackgroundClicked`.
  - After visualize, call `ScheduleRenderer.enableCaseInteractionOnAxes(app, app.ProposedAxes, 'proposed')` to attach drag/selection.
- `ScheduleRenderer`
  - Extract interaction enabling code to accept arbitrary axes; reuse for both ScheduleAxes and ProposedAxes.
  - Add `refreshProposedOnly()` helper: redraw overlays and summary for Proposed without touching main Schedule.
- `CaseDragController`
  - Ensure registry and hover/selection logic work with Proposed handles (already handle-based); no OptimizedSchedule mutations.
- `ResourceOverlayRenderer`
  - Already supports Proposed via context; keep called after Proposed visualize and after drawer changes.

### Summary & Staleness
- Proposed summary must recompute moved/unchanged/conflicts against the baseline (OptimizedSchedule) after any Proposed edits.
- Staleness banner continues to reflect changes to the baseline (OptimizedSchedule) or global options/NOW; edits inside Proposed do not trigger staleness.

### CLI Testing (where feasible)
Note: GUI drag/resize can’t be simulated easily via CLI; focus on function-level assertions and state transitions.

1) Drawer click → drawer opens and Proposed overlays refresh
```matlab
app = conduction.launchSchedulerGUI(); pause(0.5);
% Seed baseline
app.OperatorField.Value='A'; app.ProcedureField.Value='P'; app.ProcedureTimeField.Value=60; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton,[]);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton,[]); pause(0.5);
% Add second case and open Proposed
app.OperatorField.Value='B'; app.ProcedureField.Value='Q'; app.ProcedureTimeField.Value=45; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton,[]);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton,[]); pause(0.5);
% Programmatically simulate clicking a known case in Proposed: select by id then call drawer populate
ids = string({app.ProposedSchedule.cases().caseID}); selId = ids(1);
app.DrawerController.openDrawer(app, selId); pause(0.1);
assert(strlength(app.DrawerCurrentCaseId)>0, 'Drawer did not open');
delete(app);
```

2) Drawer resource update reflects in Proposed overlays
```matlab
app = conduction.launchSchedulerGUI(); pause(0.5);
store = app.CaseManager.getResourceStore(); store.create('Device A', 1);
% Baseline + Proposed
app.OperatorField.Value='A'; app.ProcedureField.Value='P'; app.ProcedureTimeField.Value=60; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton,[]);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton,[]); pause(0.5);
app.OperatorField.Value='B'; app.ProcedureField.Value='Q'; app.ProcedureTimeField.Value=45; app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton,[]);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton,[]); pause(0.5);
% Assign resource to the selected case
ids = string({app.ProposedSchedule.cases().caseID}); selId = ids(1);
[caseObj,~] = app.CaseManager.findCaseById(selId); caseObj.assignResource('device-a');
% Refresh overlays for Proposed
app.ScheduleRenderer.refreshProposedResourceHighlights(app);
% (Manual visual check in GUI)
delete(app);
```

3) Lock/unlock in drawer updates Proposed summary and overlays
```matlab
% Similar to (2): toggle IsUserLocked on a case, call Summary update and overlay refresh, assert no crash.
```

4) Accept promotion
```matlab
% After (1)/(2): app.onProposedAccept(); assert( ~isempty(app.OptimizedSchedule) );
```

### Risks
- Drag/resize semantics: If main Schedule resizing isn’t fully implemented, Proposed should align to the same capabilities (don’t expose partial interactions).
- Interaction conflicts: Ensure Proposed drag/hover watchers use ProposedAxes, not ScheduleAxes.


## File Touchpoints
- `scripts/+conduction/+gui/+app/buildOptimizationTab.m`
  - Add “Preview changes (Proposed tab)” checkbox under optimization controls.
- `scripts/+conduction/+gui/+controllers/OptimizationController.m`
  - Routing: compute `useProposed`; set Proposed fields + show tab in planning when preview enabled.
- `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
  - Add `EnablePreviewInPlanning` property (and session save/load if we persist it).
  - `showProposedTab`, `hideProposedTab`: also manage read‑only overlay lifecycle.
  - `updateProposedSummary`: handle empty baseline case.
- `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m` and `scripts/+conduction/+gui/+controllers/AnalyticsRenderer.m`
  - Expose/update helpers so KPI bar and analytics can be recomputed for an arbitrary schedule/axes context.
  - When Proposed tab renders or when Proposed schedule mutates (opt result, drag/resize/lock, drawer resource edits, Proposed‑NOW change), call KPI recompute with the Proposed schedule.
- `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m` or a small helper
  - Glass‑pane overlay management (create/destroy; z‑order; resize handling).

## Risks & Mitigations
- First‑time friction
  - Mitigated: auto‑apply initial optimize with Undo toast (no extra click).
- Missed mutation paths while read‑only
  - Overlay blocks pointer events; belt‑and‑suspenders: keep drag/resize disabled during proposal.
- Confusion on summary without baseline
  - Tailor summary text for first runs; keep conflicts and counts clear.

## Acceptance Criteria
- First optimize (no baseline): auto‑applies result and shows Undo toast.
- Subsequent optimizes (planning and re‑opt): route to Proposed, respect scope options; Accept/Discard works.
- Scope options work identically in both modes; unscheduled‑only freezes scheduled context; resources respected.
- Staleness banner appears when context changes; “Re-run with current state” works.
- Schedule tab is non-interactive during proposal via overlay.
- KPI metrics (utilization/idle/flip + KPI bar) update dynamically in the Proposed tab after any change to the proposal (re-opt or interactive edits), using the same analytics code path as the main schedule.
- KPI context follows the active view: when switching between Schedule and Proposed tabs, KPI bar recalculates against the schedule currently shown, using the shared analytics entry point (no duplicated logic).
- Status derivation in Proposed uses the Proposed schedule timings directly (no baseline CaseManager lookups) so NOW-based simulation reflects the previewed plan.

## Rollback
- Remove the preview checkbox and planning-mode routing; revert to current behavior (Proposed only in re-optimization).

## Minimal Refactor/DRY Plan (limit file bloat)
- Keep heavy files stable: `ProspectiveSchedulerApp` (4.3k LOC) only gets thin orchestration; push new logic into small helpers/controllers instead of new nested functions.
- Axes-agnostic interactions: Extract existing Schedule interactions into `ScheduleRenderer.enableCaseInteractionOnAxes(app, axes, ctx)` and `enableNowLineDragOnAxes(app, axes, commitFcn)`; reuse for Schedule/Proposed to avoid duplicating drag/selection/NOW wiring.
- Overlay + summary helpers: Add a tiny overlay utility (e.g., `ScheduleRenderer.ensureReadOnlyOverlay(axes, mode)`) and keep proposal summaries in a single `updateProposedSummary(app)` path called by all proposal mutations.
- Proposed state bundle: Add `resetProposedState(app)` / `applyProposedState(app)` helpers (could live in a small `ProposedState` utility) so Accept/Discard/auto-apply touch one surface instead of hand-editing app fields.
- Analytics/KPIs by context: Provide a single entry (e.g., `AnalyticsRenderer.renderForSchedule(app, schedule, outcome, axesSet)`) so main/Proposed both reuse it; no bespoke KPI code per tab.
- Staleness/undo reuse: Reuse the existing `OptimizationChangeCounter` + `ProposedSourceVersion` check and the current Undo toast plumbing—no new staleness flags or toasts scattered around.
- Timer cleanup reuse: Any new timers (if needed for overlay sizing or Proposed-only updates) must use the existing `clearTimerProperty` pattern to avoid adding cleanup branches in `delete(app)`.
