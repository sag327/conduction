# Case Status Buckets and Cases Tab Restructure — Implementation Plan

Status: In progress (Phases 1–6 completed; Phase 7 polish pending)
Branch: `separate-completed-case-logic`
Owner: Conduction CLI agent
Last updated: 2025-11-10

## Goals
- Introduce a clear taxonomy for case organization in the UI: Unscheduled, Scheduled, Completed.
- Keep `Locked` orthogonal to status (a separate boolean that applies to any case).
- Allow identification of “completed” from Time Control’s derived status (unchanged), and add a manual “Mark as complete” control in the drawer.
- Restructure the Cases tab to show three separate tables for the three buckets.
- Do not change optimizer behavior yet; only prepare the model/API for a later step.
- Keep the visual schedule changes minimal for now: continue to show the green check on completed cases only.

## Non‑Goals (for this phase)
- No changes to optimization rules/constraints (will follow in a subsequent plan).
- No new visual schedule badges for Scheduled/Unscheduled beyond the existing green check for completed.
- No resource bulk actions beyond what already exists.

## Taxonomy and Definitions
- Buckets shown in Cases tab:
  - Unscheduled: cases without a scheduled start (e.g., `ScheduledProcStartTime` is NaN).
  - Scheduled: cases with a scheduled start/end and not archived as completed.
  - Completed: “real” completed cases (manually marked complete or confirmed via dialog), stored in the completed archive.
- Derived vs. archived completion:
  - Derived completion (from Time Control) continues to set `ProspectiveCase.CaseStatus` to `in_progress` / `completed` for display and simulation, but does not move the case to the Completed archive.
  - Archived completion means the case is removed from the active list and stored in `CaseManager.CompletedCases`.
- Locking remains orthogonal (`ProspectiveCase.IsLocked`), applicable in any bucket.

## High‑Level Architecture
- Data model remains centered on `ProspectiveCase` with existing `CaseStatus` values: `pending`, `in_progress`, `completed`.
- Buckets are derived:
  - Completed bucket reads from `CaseManager.CompletedCases` (archived cases only).
  - For active cases (`CaseManager.Cases`):
    - Unscheduled: `isnan(c.ScheduledProcStartTime)`.
    - Scheduled: `~isnan(c.ScheduledProcStartTime)` (includes “in_progress” for UI labeling purposes).
- Introduce small, modular helpers and view‑model stores to avoid bloating large controllers.

## Phased Implementation

### Phase 1 — Status Derivation Helpers
Changes
- Add lightweight helpers under `scripts/+conduction/+gui/+status/`:
  - `computeBucket(caseObj)` → returns `'unscheduled' | 'scheduled' | 'completed-archived'` for a given `ProspectiveCase` or small struct of flags.
  - `partitionActiveCases(cases)` → indices for Unscheduled vs Scheduled among active cases.
  - `isSimulatedCompleted(caseObj)` → true if `CaseStatus == 'completed'` but case is still active (derived completion).

Rationale
- Keep classification logic consolidated and testable.

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase1"`
- Test creates 5 `ProspectiveCase` objects with mixed `ScheduledProcStartTime` and `CaseStatus`, then asserts partition counts and `isSimulatedCompleted` behavior.
- Status: ✅ Completed on 2025-11-10 (see CLI logs in branch history).

### Phase 2 — Filtered View‑Model Stores
Changes
- Add `scripts/+conduction/+gui/+stores/FilteredCaseStore.m`:
  - Wraps a `CaseManager` and materializes a filtered view of active cases (maps table rows to underlying indices).
  - Exposes `Data`, `Selection`, `setSelectedByIds`, `getSelectedCaseIds` consistent with `CaseStore`.
  - Accepts a `FilterFcn` handle (e.g., Unscheduled vs Scheduled) provided at construction.
- Add `scripts/+conduction/+gui/+stores/CompletedCaseStore.m` for `CaseManager.CompletedCases` with parallel API.

Rationale
- Preserve the single underlying source of truth while enabling multiple table views without duplicating model logic.

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase2"`
- Tests:
  - Build a `CaseManager` with 6 active cases (some scheduled) + 2 completed in the archive.
  - Create one `FilteredCaseStore` for Unscheduled and one for Scheduled; assert row→id and id→row mapping integrity.
  - Create a `CompletedCaseStore`; assert its row mapping and removal handler behavior (see Phase 3).
- Status: ✅ Completed on 2025-11-10 via `case_status_phase2`.

### Phase 3 — Cases Tab: Three Tables
Changes
- Modify `scripts/+conduction/+gui/+app/buildCaseManagementSection.m` to host three table views.
- In `ProspectiveSchedulerApp` initialization:
  - Instantiate three stores: `ActiveUnscheduledStore`, `ActiveScheduledStore`, `CompletedStore`.
  - Create three `CaseTableView` instances in a 1×3 (or 3×1) grid, titles:
    - “Unscheduled Cases”
    - “Scheduled Cases”
    - “Completed Cases”
- Wire remove/clear handlers:
  - Unscheduled/Scheduled → operate on underlying active cases (reuse or delegate to `CaseStore` semantics).
  - Completed → call `CaseManager.removeCompletedCasesByIds(ids)`.
- Selection sync rules:
  - Active selection remains the cross‑app source of truth via existing `CaseStore` semantics; when a selection is made in one active table, clear selection in the other active table and update the shared selection by CaseIds.
  - Completed selection is independent (not mirrored to schedule).

Rationale
- Minimizes disruption by leaving selection and schedule behavior unchanged for active cases. Completed cases are not shown on the schedule, so a separate selection scope is logical.

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase3"`
- Tests (controller‑level, headless):
  - Instantiate the stores and simulate selections by CaseId.
  - Assert that selecting in Unscheduled clears selection in Scheduled and vice‑versa; schedule selection (if exposed via `CaseStore`) updates accordingly.
  - Remove from CompletedStore by ids and assert archive count decrements.
- Status: ✅ Completed via `conduction.tests.case_status_phase3` (popout + multi-table sync).

### Phase 4 — Drawer: Manual “Mark as Complete”
Changes
- Add a new drawer control near the existing lock toggle in `scripts/+conduction/+gui/+app/+drawer/buildDrawerUI.m`:
  - Push button: “Mark case complete” (single‑select only; drawer keeps existing multi‑select message as is).
- Behavior:
  - When pressed: move the case from the active array to `CaseManager.CompletedCases` (via `CaseManager.setCaseStatus(..., 'completed')`), drop it from current schedules, and refresh selection/locks.
  - Restoring from archive is available through `CaseManager.restoreCompletedCases` (used by session import and future UI affordances).
- Ensure drawer state updates reflect archival status (button disabled when no single case is selected).

Rationale
- Complements derived completion by giving the user an explicit archival control without changing Time Control logic.

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase4"`
- Tests:
  - Create an active case, toggle to complete via drawer API surface (controller method), assert movement to archive.
  - Optional: toggle back to active, assert reappearance in Unscheduled or Scheduled bucket.
- Status: ✅ Completed via `conduction.tests.case_status_phase4` (stores + archive/restore regression).

### Phase 5 — Time Control Compatibility (No visual changes)
Changes
- Confirm that `ScheduleRenderer.updateCaseStatusesByTime(app, now)` keeps writing simulated statuses (`pending`/`in_progress`/`completed`) but does not auto‑archive.
- Keep the existing green check in schedule visuals tied to `isCompleted()` on active items (simulated) and to archived cases only in the Completed table.

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase5"`
- Tests:
  - With Time Control OFF/ON, advance NOW; verify Unscheduled/Scheduled partitions of active cases remain correct (only schedule times matter).
  - Derived completed should not move cases into the archive.
- Status: ✅ Completed via `conduction.tests.case_status_phase5` (TestTimeControlBuckets).

### Phase 6 — Session Serialization/Deserialization (Completed Archive)
Changes
- Export already includes `sessionData.completedCases` (see `ProspectiveSchedulerApp.exportAppStateInternal`).
- Add import support to restore archived completed cases:
  - `ProspectiveSchedulerApp.importAppStateInternal`: deserialize `completedCases` and call a new `CaseManager.restoreCompletedCases(cases)`.
  - Implement `CaseManager.restoreCompletedCases` to append to `CompletedCases` and notify listeners once.

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase6"`
- Tests:
  - Save a session with some archived completed cases; reload; assert archive count restored and active counts match pre‑save.
- Status: ✅ Completed via `conduction.tests.case_status_phase6` (TestSessionCompletedRestore).

### Phase 7 — UX Copy and Small Polish
Changes
- Table column headers for all three tables use the same schema; Completed table’s first column shows the check mark consistently.
- Cases undock window should reflect the new three‑table view (reuse the same components/layout where possible).

Validation (MATLAB CLI)
- Command: `matlab -batch "addpath(genpath('scripts')); conduction.tests.case_status_phase7"`
- Tests: basic store/data integrity checks still pass in undocked mode, selection events don’t error.
- Status: ⏳ Pending polish.

## File Touchpoints (planned)
- New helpers: `scripts/+conduction/+gui/+status/computeBucket.m`, `partitionActiveCases.m`, `isSimulatedCompleted.m`.
- New stores: `scripts/+conduction/+gui/+stores/FilteredCaseStore.m`, `scripts/+conduction/+gui/+stores/CompletedCaseStore.m`.
- Cases tab layout and wiring:
  - `scripts/+conduction/+gui/+app/buildCaseManagementSection.m`
  - `scripts/+conduction/+gui/ProspectiveSchedulerApp.m` (instantiate stores/views; sync selection)
  - `scripts/+conduction/+gui/+windows/CasesPopout.m` (mirror three‑table layout)
- Drawer:
  - `scripts/+conduction/+gui/+app/+drawer/buildDrawerUI.m` (add checkbox)
  - `scripts/+conduction/+gui/+controllers/DrawerController.m` (toggle handler)
- Session I/O:
  - `scripts/+conduction/+gui/ProspectiveSchedulerApp.m` (import ‘completedCases’)
  - `scripts/+conduction/+session/*` (already serializes ProspectiveCase; reuse)

## Testing Strategy Summary
- Keep tests headless and controller/store‑level where possible. GUI construction is acceptable in `-batch`, but avoid pixel assertions.
- For each phase, add a small test script under `tools/tests/` (or `tests/`) with a simple PASS/FAIL summary and `exit` non‑zero on failure so CI and CLI runs are clear.
- Example one‑liner invocations are listed under each phase.

## Risks and Mitigations
- Selection complexity across three tables: restrict cross‑table selection to “one active table at a time”; completed selection isolated.
- Performance: filtering stores recompute data; mitigate via CaseManager change listeners and minimal recompute.
- Session import of completed archive currently missing: covered in Phase 6.
- Future optimizer changes must consume partitions via a helper (`getOptimizationSets(now, opts)`) to avoid drift.

## Future Work (Next Doc)
- Optimizer scoping using these buckets:
  - Exclude Completed; freeze In‑Progress; scope to RemainingAfterNow for Unscheduled + (optionally) movable scheduled future.
  - Add “freeze locked” toggle and movement penalties.
- UI affordances: quick filters, counts, and context actions per bucket.
