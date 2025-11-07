# Time Control Edit Enhancement Plan

Goal: While Time Control is ON, allow drag/resize edits for any active case (pending, in_progress, simulated-completed) without enforcing post-edit overlaps or lock constraints, then immediately recompute status vs NOW and update Time Control locks so optimization can honor the user’s changes. Truly archived cases (explicit completed via Case Status) remain out of the active board and are not editable.

Principles
- Consistent UX: Same lenient edit model as non–Time Control mode (no overlap checks; optimizer resolves later).
- DRY/KISS: Reuse existing drag/resize handlers and status recomputation; minimize new code paths.
- Separation: Locking is an optimization constraint; archiving is a lifecycle transition. Time Control “locks” are hints, not edit blockers.

Modularization & File Layout
- Avoid bloating large scripts (`ScheduleRenderer`, `ProspectiveSchedulerApp`, `CaseDragController`). Add a small, focused controller:
  - New: `scripts/+conduction/+gui/+controllers/TimeControlEditController.m`
    - `finalizePostEdit(app, caseId, newTimesOrLab)` – recompute statuses vs NOW, update `SimulatedSchedule`, update `TimeControlLockedCaseIds`, mark optimize-dirty, request re-render.
    - `pauseNowTimer(app)` / `resumeNowTimer(app)` – delegate to `CaseStatusController` to avoid duplication.
- Only minimal shims in existing classes to call into the new controller (1–3 lines per call site).
- If generic helpers are needed, place under `scripts/+conduction/+gui/+utils/`.

Out of Scope
- No banners or new UI indicators.
- No new archive UI; existing archive remains internal and driven by explicit completion.

## Phase 1 — Enable Edits During Time Control

Scope
- Allow case drag/resize when `app.IsTimeControlActive == true`.
- Permit edits regardless of simulated status (pending/in_progress/completed).
- Keep only optimization-in-progress as an edit blocker.

Targets
- `CaseDragController.canInteractWithCase`: remove/block early return on `IsTimeControlActive`; stop gating on `isPending()` when Time Control is ON.
- `ScheduleRenderer` drag/resize mouse-down handlers: bypass the `IsTimeControlActive` early return.
- Add optional flag `app.AllowEditInTimeControl` (default true) to gate this feature.
- Keep modifications small; do not expand handler bodies—only relax the guards.

Validation (MATLAB -batch)
- Launch in batch and verify interactions are permitted logically by calling edit methods directly (UI drag not simulated here):
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  app.IsTimeControlActive = true; \
  % Create a simple case (using existing app APIs); assume index 1 -> get ID
  caseId = app.CaseManager.createCase('operator','A','procedure','X', ... \
      'setupMinutes',10,'procedureMinutes',30,'postMinutes',10); \
  % Attempt a resize/move via ScheduleRenderer public methods (should succeed, not abort on Time Control): \
  app.ScheduleRenderer.applyCaseResize(app, caseId, 600); \
  app.ScheduleRenderer.applyCaseMove(app, caseId, 1, 540); \
  delete(app);"
```
- Expected: methods return without early abort; no errors thrown. (Functional correctness validated in later phases.)

## Phase 2 — Post-Edit Status Recompute (NOW)

Scope
- After any edit, recompute statuses vs NOW using existing logic and keep NOW line attached.
- Update `app.SimulatedSchedule` and `app.TimeControlLockedCaseIds` via the existing recompute path.

Targets
- New: `TimeControlEditController.finalizePostEdit(app, caseId, context)` calls existing `ScheduleRenderer.updateCaseStatusesByTime` and centralizes post-edit work (status recompute, `SimulatedSchedule`/lock updates, mark-dirty, re-render).
- `ScheduleRenderer.applyCaseMove/applyCaseResize`: when `IsTimeControlActive`, delegate to `TimeControlEditController.finalizePostEdit(...)` after committing the change. Keep call sites to a single line.

Validation (MATLAB -batch)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  app.IsTimeControlActive = true; \
  % Build one case whose edited times will straddle NOW
  caseId = app.CaseManager.createCase('operator','A','procedure','X','setupMinutes',10,'procedureMinutes',30,'postMinutes',0); \
  % Set a NOW time
  app.CaseManager.setCurrentTime(9*60+30); % 09:30 \
  % Move case to 09:15-09:45
  app.ScheduleRenderer.applyCaseMove(app, caseId, 1, 9*60+15); \
  app.ScheduleRenderer.applyCaseResize(app, caseId, 9*60+45); \
  % Recompute statuses vs NOW
  updated = app.ScheduleRenderer.updateCaseStatusesByTime(app, 9*60+30); \
  % Inspect in-memory status
  [c, ~] = app.CaseManager.findCaseById(caseId); \
  fprintf('Status: %s\n', c.CaseStatus); \
  delete(app);"
```
- Expected: status becomes `in_progress` and `TimeControlLockedCaseIds` includes `caseId`.

## Phase 3 — Ignore Locks During Edit; Optimizer Resolves Later

Scope
- Do not enforce user locks or time-control locks as edit blockers in Time Control mode. Keep optimization as the place to resolve overlaps/constraints.

Targets
- `CaseDragController.canInteractWithCase`: do not reject due to locks when Time Control is ON.
- Post-edit checks reside only in `TimeControlEditController` and intentionally skip overlap/lock-conflict validation.

Validation (MATLAB -batch)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); app.IsTimeControlActive = true; \
  id1 = app.CaseManager.createCase('operator','A','procedure','X','setupMinutes',10,'procedureMinutes',30); \
  id2 = app.CaseManager.createCase('operator','B','procedure','Y','setupMinutes',10,'procedureMinutes',30); \
  % Simulate a user lock on id2 if your app exposes LockedCaseIds \
  app.LockedCaseIds = [string(id2)]; \
  % Create an overlap by moving id1 into id2's time window \
  app.ScheduleRenderer.applyCaseMove(app, id1, 1, 9*60); \
  % No errors; no blocking dialogs; mark dirty handled by existing code. \
  delete(app);"
```
- Expected: edit succeeds; no post-edit overlap validation runs.

## Phase 4 — Simulated “Completed” Still Editable; True Archive Not

Scope
- Ensure simulated-completed (via Time Control) cases remain editable; truly archived cases (explicit completed via Case Status) are not on the active board and thus not editable.

Targets
- Only `IsOptimizationRunning` blocks edits while Time Control is ON; do not block by status.
- No change to archive behavior: `CaseManager.setCaseStatus(...,'completed')` moves the case out of active set.
- `TimeControlEditController` should no-op safely if a caseId is not in the active set.

Validation (MATLAB -batch)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); app.IsTimeControlActive = true; \
  id = app.CaseManager.createCase('operator','A','procedure','X','setupMinutes',10,'procedureMinutes',30); \
  % Simulate completed via NOW (end < NOW) and attempt edit \
  app.CaseManager.setCurrentTime(12*60); \
  app.ScheduleRenderer.updateCaseStatusesByTime(app, 12*60); \
  app.ScheduleRenderer.applyCaseResize(app, id, 12*60-5); % should be allowed \
  % Now truly archive via explicit completion and attempt edit again \
  idx = app.CaseStatusController.findCaseIndexById(app, id); \
  app.CaseManager.setCaseStatus(idx, "completed"); \
  ok = app.ScheduleRenderer.applyCaseResize(app, id, 12*60-10); \
  fprintf('EditAfterArchive:%d\n', ok); \
  delete(app);"
```
- Expected: first edit succeeds; after archiving, edit returns false/no-op (case no longer active).

## Phase 5 — Timer Coordination & Stability

Scope
- Prevent race conditions with the NOW-line timer while editing. Pause timer on drag start; resume on commit/cancel.

Targets
- `TimeControlEditController.pauseNowTimer/resumeNowTimer` delegate into `CaseStatusController` (keep logic in one place). Drag/resize handlers call these wrappers at start/end when Time Control is ON.

Validation (MATLAB -batch)
- Hard to simulate motion in batch; validate indirect effects: perform rapid sequential edits and call `updateCaseStatusesByTime` to confirm consistent status updates without exceptions.
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); app.IsTimeControlActive = true; \
  id = app.CaseManager.createCase('operator','A','procedure','X','setupMinutes',10,'procedureMinutes',30); \
  for k=1:3, app.ScheduleRenderer.applyCaseMove(app, id, 1, 9*60 + 5*k); end; \
  app.CaseManager.setCurrentTime(9*60+20); updated = app.ScheduleRenderer.updateCaseStatusesByTime(app, 9*60+20); \
  delete(app);"
```

---

Notes
- Optimization is never auto-triggered by edits; existing “dirty”/needs-opt flagging remains.
- Tests above use programmatic calls to the same methods the GUI uses after a user drag/resize; they validate that Time Control no longer blocks edits and that status/locks update via the existing recompute.

Refactoring Guardrails
- Small surface changes in large files; push new logic into the new controller/utility.
- Single-responsibility functions with descriptive names; prefer 20–50 line helpers over monolith methods.
- No duplicate timer or status-recompute logic—always delegate to existing `CaseStatusController` and `ScheduleRenderer.updateCaseStatusesByTime`.
