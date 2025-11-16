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
- Staleness banner appears when context changes; “Re‑run with current state” works.
- Schedule tab is non‑interactive during proposal via overlay.

## Rollback
- Remove the preview checkbox and planning‑mode routing; revert to current behavior (Proposed only in re‑optimization).
