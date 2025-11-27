# NOW Line – Reset to Planning Mode Fix Plan

Status: Draft (implementation plan – move to `docs/archive/` after completion)  
Branch: `now-line-fixes`  
Owner: Conduction GUI / unified timeline

## Observed Bug

User flow:
- Drag NOW line forward into the day and/or mark cases complete manually.
- Click **Reset to Planning** in the top bar.
- App shows a confirmation dialog (“Reset NOW to start of day and clear manual completion flags?”).
- After confirming:
  - The NOW line does **not** visibly move back to the planning/start position.
  - Case statuses (completed / in‑progress) do **not** revert to the pre‑execution “planning” state.

Expected behavior:
- NOW line should jump back to the planning start time.
- All derived completion/in‑progress statuses should revert to **pending** (except for genuine archived completions, if any).
- User‑applied locks should **persist** across the reset.
- While in planning mode, the NOW label should read **“PLANNING”** (no time); once NOW is dragged away from the planning position, it should switch to **“NOW (HH:MM)”**.

## Root Cause Analysis

Key pieces of current implementation:

- `ProspectiveSchedulerApp.onResetToPlanningMode`:
  - Confirms with `uiconfirm`.
  - Calls:
    - `app.hideProposedTab(true);`
    - `app.clearManualCompletionFlags();`
    - `app.setNowPosition(app.getPlanningStartMinutes());`
    - `app.updateScopeSummaryLabel();`
    - `app.updateScopeControlsVisibility();`
  - **Missing:** any schedule re‑render or NOW‑label update after changing the NOW position.

- `setNowPosition(app, timeMinutes)`:
  - Clamps and stores `app.NowPositionMinutes`.
  - Calls `app.markDirty();` and `app.refreshOptimizeButtonLabel();`
  - Does **not** re‑render the schedule or recompute visual statuses.

- Status derivation:
  - `ProspectiveCase.getComputedStatus(nowMinutes)` uses:
    - `ScheduledStartTime`, `ScheduledEndTime`, and `ManuallyCompleted`.
  - `ScheduleRenderer.annotateScheduleWithDerivedStatus(app, schedule, nowMinutes)` iterates the `DailySchedule` assignments, looks up each `ProspectiveCase` by `CaseId`, and writes `caseStatus` based on `getComputedStatus`.
  - `getScheduleForRendering` uses this helper to build an annotated schedule from `app.OptimizedSchedule`, driven by `app.getNowPosition()`.

- NOW drag behavior (`ScheduleRenderer.endDragNowLine`):
  - Sets the new NOW position via `app.setNowPosition(finalTimeMinutes)`.
  - Calls `obj.updateCaseStatusesByTime(app, finalTimeMinutes)` to build an updated schedule with simulated statuses.
  - Compares statuses for dirtiness.
  - Finally calls `renderOptimizedSchedule(app, updatedSchedule, app.OptimizationOutcome);` to redraw, including the NOW line and updated status colors.

- Manual completion reset (`clearManualCompletionFlags`):
  - Iterates `CaseManager` cases:
    - Sets `caseObj.ManuallyCompleted = false;`
    - Sets `caseObj.CaseStatus = "pending";`
  - Calls `app.refreshCaseBuckets('ResetPlanning');`
  - Calls `app.updateResetPlanningButton();`
  - **Note:** `CaseStatus` is now legacy; derived status flows rely on `getComputedStatus(nowMinutes)`, so simply writing `CaseStatus = "pending"` is not enough; the schedule still needs to be re‑annotated and rendered using the new NOW position and cleared `ManuallyCompleted` flags.

Consequence:
- After **Reset to Planning**, only the in‑memory NOW value and `ManuallyCompleted` flags change. The currently visualized `DailySchedule` and NOW overlay remain as they were because we never:
  - Recompute derived statuses with the new NOW.
  - Redraw the schedule canvas (Gantt + NOW line).
- This exactly matches the observed bug: the confirmation dialog works, but the visual schedule and statuses remain in the previous state.

## Desired Behavior (Clarified)

1. **Planning mode**:
   - NOW is at the planning start time (`getPlanningStartMinutes()`).
   - All active cases are visually **pending** (no simulated in‑progress/completed), except for true archived completions in the Completed bucket.
   - User locks (`IsUserLocked`) persist (they still constrain optimization and are visually indicated).
   - NOW line label shows **“PLANNING”** (no time string).

2. **Execution mode** (NOW moved forward or manual completions exist):
   - NOW line label shows **“NOW (HH:MM)”**.
   - Status is derived live from NOW:
     - completed / in_progress / pending.
   - Manual completions add persistent overrides (ManuallyCompleted).

3. **Reset to Planning**:
   - Clears manual completion flags (`ManuallyCompleted = false` for all active cases; `CaseStatus` only used for legacy table display).
   - Keeps user locks (`IsUserLocked`) intact.
   - Returns NOW to the planning start minute.
   - Rebuilds the rendered schedule based on:
     - `app.OptimizedSchedule` (unchanged times),
     - NOW at planning start,
     - Cleared manual completions.
   - Updates KPIs and button visibility (Reset/Advance) accordingly.

## Implementation Plan

### 1) Fix Reset to Planning Mode Pipeline

**Goal:** Make `onResetToPlanningMode` follow the same pattern as NOW‑drag finalize (`endDragNowLine`), but without using the legacy `updateCaseStatusesByTime` path.

Steps:

1. Keep the existing confirmation dialog and:
   - `app.hideProposedTab(true);`
   - `app.clearManualCompletionFlags();`
   - `app.setNowPosition(app.getPlanningStartMinutes());`

2. After changing NOW and completion flags, explicitly re‑render the schedule using the unified timeline annotation:
   - Retrieve an annotated schedule from the current optimized schedule:
     - `scheduleForRender = app.getScheduleForRendering();`  
       (internally calls `annotateScheduleWithDerivedStatus(app, app.OptimizedSchedule)` based on `app.getNowPosition()`).
   - If `scheduleForRender` is non‑empty:
     - `app.ScheduleRenderer.renderOptimizedSchedule(app, scheduleForRender, app.OptimizationOutcome);`

3. Let `renderOptimizedSchedule` handle:
   - NOW line placement using the new NOW position (planning start).
   - Status visualization (completed/in‑progress/pending) via the annotated schedule.
   - KPI bar refresh and resource overlays.

4. Ensure helper calls are ordered as:
   - Clear proposal + manual completions.
   - Set NOW position.
   - Recompute annotated schedule + re‑render.
   - Update scope summary / scope controls.

Notes:
- Manual locks:
  - `clearManualCompletionFlags` only touches `ManuallyCompleted` and `CaseStatus`.
  - `IsUserLocked` remains unchanged.
  - `getComputedLock(nowMinutes)` will still return `true` for user‑locked cases even at planning time, so locks persist visually and functionally.
- Legacy arrays (`app.LockedCaseIds`, etc.) should not be modified here; this flow should rely solely on per‑case flags + computed locks to avoid re‑introducing older locking semantics.

### 2) Update NOW Line Label for Planning vs Execution

We want the label to reflect planning vs execution more clearly without changing the underlying timeline semantics.

**A. Add a dedicated NOW label updater in `ScheduleRenderer`**

- New helper: `refreshNowLabel(app, axesHandle)`:
  - Arguments:
    - `app` (for NOW + planning start).
    - `axesHandle` (typically `app.ScheduleAxes` or `app.ProposedAxes`).
  - Logic:
    1. Find `nowLabel = findobj(axesHandle, 'Tag', 'NowLabel');`
       - If missing, no‑op.
    2. Compute:
       - `nowMinutes = app.getNowPosition();`
       - `firstCaseStart = app.getFirstScheduledCaseStartMinutes();`
    3. If `nowMinutes` is **at or before the first scheduled case** (or there is no first case):
       - Set `nowLabel.String = 'PLANNING';`
       - Keep its Y position aligned just above the NOW line (reuse the existing `newTimeHour - 0.1` pattern).
    4. Else:
       - Compute `timeStr = minutesToTimeString(nowMinutes);`
       - Set `nowLabel.String = sprintf('NOW (%s)', timeStr);`

- Call sites:
  - At the end of `renderOptimizedSchedule`, after `visualizeDailySchedule`:
    - `obj.refreshNowLabel(app, app.ScheduleAxes);`
  - Optionally in `renderProposedSchedule` **only** if we want Proposed to mirror the baseline label; otherwise we can leave Proposed in “NOW (time)” mode only.

**B. Integrate with NOW drag logic**

- `updateNowLinePosition` currently hard‑codes:
  - `nowLabel.String = sprintf('NOW (%s)', timeStr);`
- Adjust logic to:
  - Use the same planning vs NOW decision as `refreshNowLabel`:
    - When dragging ends up exactly at planning start (within tolerance), show “PLANNING”.
    - Otherwise, show “NOW (HH:MM)”.
- `endDragNowLine` already calls `setNowPosition(finalTimeMinutes)` and then re‑renders the schedule via `renderOptimizedSchedule` (through `updateCaseStatusesByTime` and/or future unified path). The final label will be corrected by `refreshNowLabel`.

### 3) Keep Proposed Tab Behavior Separate

Planning vs execution is fundamentally a concept for the **baseline** schedule:

- Proposed view is already explicitly a “preview” state; it’s fine to keep its NOW label as “NOW (HH:MM)” only.
- We should therefore:
  - Apply the “PLANNING” label only on `ScheduleAxes`, not `ProposedAxes`.
  - Keep Proposed internal NOW handling (`getEffectiveProposedNowMinutes`, `setProposedNowPosition`) unchanged except for use of the shared time range and axis alignment already implemented.

### 4) Testing Strategy

Manual tests (GUI):

1. **Reset to Planning**
   - Optimize a schedule; drag NOW forward; mark one or more cases complete manually.
   - Observe:
     - Reset button is visible (as today).
   - Click **Reset to Planning** and confirm:
     - NOW line jumps back to planning start time.
     - All active cases visually show as pending (no green checks or in‑progress overlays).
     - User‑locked cases remain visually locked and locked in optimization.
     - Header read‑only text disappears (if no proposal), and drag/resize is enabled again.

2. **Planning vs NOW label**
   - On a fresh session (no manual completions):
     - Before any drag, NOW label shows “PLANNING”.
   - Drag NOW forward a few minutes:
     - Label switches to “NOW (HH:MM)”.
   - Drag NOW precisely back to planning start:
     - Label returns to “PLANNING”.

3. **Interaction with Proposed tab**
   - Generate a proposal, with NOW > first case.
   - Confirm:
     - Schedule tab is read‑only; Proposed tab shows the preview.
     - Reset to Planning:
       - Clears the proposal and returns Schedule to editable planning mode.
       - NOW label shows “PLANNING”.
       - Statuses revert to pending as above.

CLI sanity checks (optional):

- Add a small headless test that:
  - Launches app, creates a few cases, runs optimization.
  - Moves NOW forward programmatically (via `setNowPosition` + re‑render).
  - Calls `onResetToPlanningMode` with the confirmation path stubbed or by calling the internal logic directly.
  - Asserts:
    - `app.getNowPosition() == getPlanningStartMinutes()`.
    - `all(caseObj.getComputedStatus(app.getNowPosition()) == "pending")` for active cases.
    - `IsUserLocked` unchanged before/after reset for a locked case.

## Archival Plan

Once the above behavior is implemented, tested, and stabilized:

- Move this document to `docs/archive/NOW-Line-Planning-Mode-Plan.md` to keep `docs/` focused on current, high‑level design docs.
- Update `docs/Architecture-Overview.md` and/or `docs/Developer-Quickstart.md` with a succinct summary of the final NOW/Planning behavior so future contributors don’t have to read this detailed plan.
