# Dynamic Case Durations — Implementation & Test Plan

This document tracks the plan for making case durations editable both on the schedule canvas (resize gesture) and in the drawer, with robust headless tests plus manual tests to validate UX and guard against regressions.

Status: planning for Phase 1–3. Current working branch: `feat/dynamic-case-durations-impl`.

## Goals

- On-canvas: allow resizing a case’s procedure duration by dragging the bottom edge of the procedure segment (procStart → procEnd). Setup and post remain unchanged.
- Drawer: allow editing setup, procedure, post, and turnover durations with instant feedback on the schedule.
- Drawer: expose an explicit “Reset to Baseline Duration” control so users can revert to the original estimates; re-optimization must preserve any edited duration until the reset is used.
- Overlap detection/integrity: reuse the same logic as case dragging; if a change would create invalid state, revert and alert.
- Preserve persistent IDs and case numbers; labels remain stable across re-optimization.

---

## Phase 1: On‑Canvas Procedure Resize

Interaction & Architecture
- Reuse `CaseDragController` infrastructure (registry, throttling, soft highlight) by adding a resize gesture alongside drag.
- Add transparent resize handles for each procedure segment (bottom edge; top edge deferred to Phase 3).
- In `ScheduleRenderer` add `applyCaseResize(app, caseId, newProcEndMinutes)` modeled on `applyCaseMove`:
  - Update only `procEndTime` and derived `endTime`.
  - Normalize lab assignments (consistent struct shape) before re-constructing `DailySchedule`.
  - Run existing integrity checks; revert and alert on anomalies.
  - Mark `IsOptimizationDirty = true` and lock the resized case (`LockedCaseIds`).

Overlap/Validation
- Snap to minute grid (reuse drag snap).
- Clamp to schedule bounds and enforce minimum duration.
- Reuse current overlap/integrity logic; if overlap is not allowed, revert with alert (or allow visual offset consistent with current drag, but state must be valid on commit).

Headless Tests (new)
- `tests/schedule/test_applyCaseResize.m`
  - Resizing longer/shorter changes only `procEndTime`/`endTime`; setup/post remain the same.
  - Locks case and marks optimization dirty.
  - Rejects invalid (too short) durations and beyond-bounds values.
- `tests/schedule/test_resize_struct_normalization.m`
  - After resize, lab assignments concatenate without field mismatches (vertcat safe).
- `tests/schedule/test_resize_integrity_checks.m`
  - Overlap/integrity failure triggers revert; schedule and IDs unchanged.

Manual Tests
- Resize a pending/unlocked case longer/shorter; soft highlight follows; release applies change.
- Verify locked/selected visuals: white highlight frames red lock.
- Attempt to resize when optimization is running or time control is active → blocked with alert.
- After a resize, re-optimize; durations persist; case numbers (labels) remain stable.

CLI Examples
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "addpath(genpath(pwd)); R=runtests({'tests/schedule'}); disp(table(R)); exit(any([R.Failed]));"
```

---

## Phase 2: Drawer Duration Editing

UI & Data Flow
- Add numeric inputs to the drawer for `setupTime`, `procTime`, `postTime`, `turnoverTime` (minutes).
- On change: validate inputs, recompute `procEndTime = procStartTime + procTime`, keep setup/post values as edited.
- Apply using the same pipeline as Phase 1 (`applyCaseResize`) to ensure overlap/integrity and locking behavior.
- Update `ProspectiveCase.EstimatedDurationMinutes` and any stored per-case duration fields used for optimization.
- Drawer should also provide a “Reset to Baseline Duration” action that restores the original duration values and unlocks the case if appropriate.

Headless Tests (new)
- `tests/schedule/test_drawer_duration_apply.m`
  - Simulate drawer edits (direct call into controller APIs) and verify the schedule fields and ProspectiveCase fields are in sync.
- `tests/schedule/test_drawer_overlap_integrity.m`
  - Drawer edit resulting in overlap triggers revert.

Manual Tests
- Edit each duration field; verify immediate schedule update and stable labels.
- Edit procedure time across multiple cases and labs; re-optimize and verify locked windows preserved.
- Use the “Reset to Baseline Duration” control to revert to the original estimate; confirm the schedule refreshes accordingly and re-optimization respects the restored duration.

---

## Phase 3: Polish & Advanced

Enhancements
- Optional top-edge handle to shift the entire proc window (procStart & procEnd together).
- Keyboard nudges, fine-grained snapping controls.
- Undo/redo of last resize/edit.
- Hover cursor change and tooltip on handles.

Headless Tests
- Extend Phase 1/2 tests for new APIs (e.g., shift proc window) and undo/redo invariants.

Manual Tests
- Sanity for long schedules (performance/responsiveness).
- Stress switching between drag and resize quickly; no ghost overlays; selection/lock visuals remain correct.

---

## Shared Testing Notes

- Existing tests remain runnable:
  - `tests/save_load/*`, `tests/schedule/test_removeCasesByIds.m`.
- All new headless tests should avoid GUI dependencies; interact with controllers/renderers at the function level.
- For GUI verification (resize handles, overlays), use manual tests until a UI testing framework is added.

CLI Templates
```bash
# Run all tests
/Applications/MATLAB_R2025a.app/bin/matlab -batch "addpath(genpath(pwd)); R=runtests('tests'); disp(table(R)); exit(any([R.Failed]));"

# Run only schedule tests
/Applications/MATLAB_R2025a.app/bin/matlab -batch "addpath(genpath(pwd)); R=runtests('tests/schedule'); disp(table(R)); exit(any([R.Failed]));"
```

---

## Definition of Done

- Phase 1: On-canvas resize works with snapping, locking, and overlap/integrity enforcement; headless tests pass; manual checks OK.
- Phase 2: Drawer edits wired; synchronization between drawer, schedule, and re-optimization validated; headless tests pass; manual checks OK.
- Phase 3: UX polish and advanced behaviors validated; no regressions in headless suite.

## Risks & Mitigations

- GUI event interop (drag vs resize) — mitigate by clear handle tagging and isolated callbacks.
- Struct shape drift — continue to normalize lab assignments after every mutation.
- Label drift — post-opt caseNumber annotation kept on both optimized and simulated schedules.
