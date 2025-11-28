# Responsiveness Improvements – Schedule Click & Lock Interactions

Status: Draft (implementation plan – delete when complete)  
Branch: `responsiveness-improvements`  
Scope: Main Schedule tab (baseline schedule); patterns likely reused elsewhere.

## Goals

- Make single-click selection on the main schedule feel instantaneous, including the appearance of the resize affordance.
- Make double-click lock toggling feel snappy by avoiding unnecessary full schedule re-renders.
- Keep the behavior and visual semantics identical (selection rules, locks, NOW line, etc.), only reducing latency.
- Add lightweight measurement so we can quantify improvements as we go.

## Baseline: Current Interaction Flow (Summary)

For a **single click** on a case:

- `visualizeDailySchedule` draws `CaseBlock` rectangles and attaches `ButtonDownFcn` → `ScheduleRenderer.onCaseBlockMouseDown`.
- `onCaseBlockMouseDown`:
  - Uses `CaseDragController` to resolve the case and draws a **soft highlight** rectangle (`showSoftHighlight`), with an immediate `drawnow limitrate nocallbacks`.
  - Arms drag state and sets `WindowButtonMotionFcn` / `WindowButtonUpFcn`.
- On mouse-up without significant movement, `endDragCase` calls `invokeCaseBlockClick`, which:
  - Reads `SelectionType` (`normal`, `open`, `extend`).
  - Dispatches to `app.onScheduleBlockClicked` with either:
    - `caseId` (single click)
    - `lock-toggle:caseId` (double click)
    - `toggle-select:caseId` (modifier/extend click).
- `onScheduleBlockClicked` updates the multi-selection model (`selectCases` → `assignSelectedCaseIds` → `onSelectionChanged`), which:
  - Syncs selection into `CaseStore` and bucket stores.
  - Calls `updateCaseSelectionVisuals`, which:
    - Calls `ScheduleRenderer.enableCaseSelectionOnAxes` (rebuilds `CaseDragController` registry from all `CaseBlock`s).
    - Calls `CaseDragController.showSelectionOverlayForIds` to draw the white selection outline and resize grip, with another `drawnow`.
    - May fall back to a full `redrawSchedule(app)` if overlay cannot be applied.

For a **double-click lock toggle**, all of the above runs, plus:

- `onScheduleBlockClicked` sees `lock-toggle:caseId` and calls `DrawerController.toggleCaseLock`, which:
  - Flips `caseObj.IsUserLocked`.
  - Calls `app.updateCasesTable()`.
  - Then calls:
    ```matlab
    scheduleToRender = app.getScheduleForRendering();
    app.ScheduleRenderer.renderOptimizedSchedule(app, scheduleToRender, app.OptimizationOutcome);
    ```
  - `renderOptimizedSchedule` redraws the entire Gantt, recomputes locks/overlaps, re-applies resource overlays and KPIs, and rebinds all drag/selection handlers.

The user-visible symptoms:

- Soft highlight appears quickly at mouse-down (lightweight).
- Resize grip and persistent selection outline appear only after the full selection/update pipeline on mouse-up.
- Double-click lock toggling feels slower because it adds a full schedule re-render on top of the selection work.

---

## Step 1 – Add Timing Instrumentation (Measurement Only)

**Objective:** Identify the dominant contributors to latency for:
- Single-click selection.
- Double-click lock toggling.

**Implementation tasks (Step 1)**

1. In `ProspectiveSchedulerApp.m`, wrap the following in lightweight timing logs (using `tic`/`toc` or `timeit`-style helpers):
   - `onScheduleBlockClicked`.
   - `onSelectionChanged` (or just inside the method, around the main body).
   - `updateCaseSelectionVisuals`.
2. In `CaseDragController.m`, add optional timing around:
   - `showSelectionOverlayForIds`.
   - `showSelectionOverlay`.
3. In `DrawerController.m`, add timing around:
   - `toggleCaseLock`.
4. In `ScheduleRenderer.m`, add timing around:
   - `renderOptimizedSchedule` (at least when invoked from lock toggling).
5. Guard all logging with a simple flag, e.g. `app.DebugTiming` or a small utility `conduction.gui.utils.Timing.log(...)` so that:
   - The logs can be enabled/disabled without touching each call site.
   - Default behavior in production sessions is **no logging**.

**Testing / commands (Step 1)**

These are mostly observational; command-line runs will simply exercise code paths and print timings:

1. Launch the GUI and exercise manual clicks:
   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); app = conduction.launchSchedulerGUI(); pause(5);"
   ```
   - With `DebugTiming` turned on (e.g., set in the App constructor or via a small helper), click and double-click cases on the main schedule.
   - Observe timing outputs in the MATLAB console (or a log file, if we route logs there).
2. For a rough automated baseline, add a small manual script under `tests/matlab/` (e.g., `measure_schedule_click_timings.m`) that:
   - Creates an app.
   - Loads a known test dataset (via `Developer-Quickstart` instructions).
   - Programmatically calls:
     - `app.onScheduleBlockClicked(caseId)` in a loop.
     - `app.DrawerController.toggleCaseLock(app, caseId)` in a loop.
   - Prints average and max timings for each operation.
3. Run the script from the command line:
   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/measure_schedule_click_timings.m');"
   ```

**Progress tracking (Step 1)**

- [x] Instrument timing around selection & lock paths.
- [x] Implement optional `DebugTiming` flag / helper.
- [ ] Run `measure_schedule_click_timings.m` (or equivalent) and record baseline numbers in this file.

---

## Step 2 – Avoid Rebuilding the CaseDragController Registry on Every Selection

**Objective:** Keep `CaseDragController.registerCaseBlocks` tied to schedule rendering, not selection changes, so single-click selection doesn’t rescan all `CaseBlock`s on every click.

**Current behavior (important sites)**

- `renderOptimizedSchedule`:
  - At the end, calls `enableCaseDrag(app, app)`, which:
    - Finds all `CaseBlock`s on `ScheduleAxes`.
    - Calls `CaseDragController.registerCaseBlocks(app, caseBlocks)`.
- `updateCaseSelectionVisuals`:
  - Always calls `ScheduleRenderer.enableCaseSelectionOnAxes(app, axes)`:
    - This again finds all `CaseBlock`s and calls `registerCaseBlocks`.

So each selection change re-walks and re-registers all case blocks even though nothing moved.

**Implementation tasks (Step 2)**

1. In `ScheduleRenderer.enableCaseSelectionOnAxes`:
   - Only call `CaseDragController.registerCaseBlocks` when needed:
     - If the registry is empty (`obj.CaseIds` is empty).
     - Or when a cheap “staleness” check says the registry is outdated (e.g., compare `LastRegistryUpdate` with a timestamp that `renderOptimizedSchedule` writes).
2. In `updateCaseSelectionVisuals`:
   - Before calling `enableCaseSelectionOnAxes`, check:
     - That we are on the Schedule or Proposed tab (already done).
     - That there is at least one selected ID.
   - Do **not** trigger `redrawSchedule` when overlays cannot be applied in the normal selection path; prefer logging and a no-op, because:
     - `CaseDragController.registerCaseBlocks` already runs after renders.
     - Re-rendering just to select is what makes selection feel sluggish.
3. (Optional) Add a debug assertion when overlays cannot be drawn while a registry exists, so we can examine corner cases without penalizing the common path.

**Testing / commands (Step 2)**

1. Run existing manual time-control / schedule tests to ensure no regressions:
   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/manual_verify_time_control_phase2.m');"
   ```
2. Re-run the timing script from Step 1:
   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/measure_schedule_click_timings.m');"
   ```
   - Compare average single-click timings before/after.
3. Manual GUI verification:
   - Launch the app, load a test day, and click quickly across cases.
   - Confirm:
     - Soft highlight still appears immediately.
     - Resize affordance appears faster on mouse-up.
     - Drag/resize still work as expected.

**Progress tracking (Step 2)**

- [ ] Gate `enableCaseSelectionOnAxes` so it only re-registers when necessary.
- [ ] Remove `redrawSchedule` from normal selection fallbacks.
- [ ] Confirm no regressions in the drag/resize behavior via manual and scripted tests.

---

## Step 3 – Make Lock Toggling Incremental (No Full Re-render)

**Objective:** When double-clicking to lock/unlock a case, update only the lock indicator for that case instead of re-rendering the entire schedule.

**Current behavior**

- `DrawerController.toggleCaseLock`:
  - Flips `caseObj.IsUserLocked`.
  - Calls `app.updateCasesTable()`.
  - Calls `app.getScheduleForRendering()` and `renderOptimizedSchedule(...)`, which rebuilds the entire visualization.

**Implementation tasks (Step 3)**

1. Introduce a helper in `ScheduleRenderer`, conceptually:
   - `refreshLockVisualForCase(app, caseId)`
   - Responsibilities:
     - Use `CaseDragController.resolveSelectionGeometry(caseId)` or a similar helper to:
       - Obtain the case rectangle and axes.
       - Compute the case span from setup to post end.
     - Draw or remove the red locked outline around that case only, matching the style currently drawn in `visualizeDailySchedule`:
       - `EdgeColor = [1 0 0]`, `LineWidth = 3`, `Tag = 'LockedOutline_<caseId>'` (or reuse the existing lock tags if we can localize them).
     - Avoid touching resource overlays, KPIs, NOW line, etc.
2. Refactor `DrawerController.toggleCaseLock` to:
   - Update the model state as now (`IsUserLocked`, cases table, drawer toggle).
   - Call `ScheduleRenderer.refreshLockVisualForCase` instead of `renderOptimizedSchedule`.
   - Optionally call `applyMultiSelectionHighlights` to keep the selection overlay consistent when the locked case is also selected.
3. Ensure `getScheduleForRendering` and `annotateScheduleWithDerivedStatus` still compute correct lock semantics for the next **full** render (e.g., after optimization or a big structural change).

**Testing / commands (Step 3)**

1. Automated / CLI:
   - Extend or add a simple test script (e.g., `tests/matlab/test_lock_toggle_visuals.m`) that:
     - Creates an app and runs an optimization.
     - Picks one `caseId` from the optimized schedule.
     - Calls `DrawerController.toggleCaseLock(app, caseId)` several times.
     - After each toggle:
       - Asserts `caseObj.IsUserLocked` matches expectation.
       - Optionally inspects axes children to ensure exactly one locked outline exists when locked, none when unlocked.
   - Run:
     ```bash
     matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/test_lock_toggle_visuals.m');"
     ```
2. Manual GUI:
   - Launch the app and double-click a case to lock/unlock repeatedly.
   - Confirm:
     - Lock icon/outline updates immediately without a noticeable redraw pause.
     - Cases table correctly shows the lock state.
     - Re-running optimization still respects existing locks.

**Progress tracking (Step 3)**

- [ ] Implement `ScheduleRenderer.refreshLockVisualForCase`.
- [ ] Wire `DrawerController.toggleCaseLock` to the new helper instead of `renderOptimizedSchedule`.
- [ ] Add or update tests to verify visual and model lock behavior.

---

## Step 4 – Trim `updateCaseSelectionVisuals` and Selection Sync

**Objective:** Reduce overhead in the selection pipeline, especially work that doesn’t impact the main schedule canvas.

**Implementation tasks (Step 4)**

1. In `onSelectionChanged`:
   - Ensure we avoid redundant selection pushes:
     - If `source == "case-store"`, skip `pushSelectionToCaseStore`.
     - If `source == "bucket"`, skip `pushSelectionToBucketStores`.
2. In `updateCaseSelectionVisuals`:
   - Avoid redundant drawer updates:
     - Only call `DrawerController.showInspectorContents` / `populateDrawer` when:
       - The selected ID actually changed, or
       - The drawer is currently open/auto-open; otherwise defer until the drawer is opened.
   - Ensure there is only **one** necessary `drawnow` in the selection overlay path; do not call it multiple times inside nested helpers unless it materially improves perceived latency.
3. Confirm that `CaseDragController.showSelectionOverlayForIds` remains the primary way overlays are applied, and that we no longer have any path where a normal selection triggers `redrawSchedule`.

**Testing / commands (Step 4)**

1. Run relevant existing tests:
   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/TestTimeControlBuckets.m');"
   ```
2. Re-run the timing script from Step 1 to confirm further improvement:
   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/measure_schedule_click_timings.m');"
   ```
3. Manual GUI:
   - Click quickly across cases with the drawer both open and closed.
   - Confirm:
     - No errors.
     - Selection overlays and resize grips remain correct.

**Progress tracking (Step 4)**

- [ ] Remove redundant selection pushes based on `source`.
- [ ] Reduce unnecessary `drawnow` calls in the selection path.
- [ ] Verify bucket/case-view selections stay in sync.

---

## Step 5 – Optional: Pre-Selection Overlay on Mouse-Down

**Objective (optional, only if needed after Steps 2–4):** Make resize affordances appear as soon as possible by drawing the selection overlay on mouse-down, before full selection sync.

**Implementation idea (Step 5)**

1. In `ScheduleRenderer.onCaseBlockMouseDown`:
   - After drawing the soft highlight, immediately ask `CaseDragController` to:
     - Treat the clicked case as the primary selection for overlay purposes (without yet touching app-wide `SelectedCaseIds`).
     - Draw the persistent selection outline and resize grip.
2. On mouse-up:
   - If no drag occurred (`drag.hasMoved == false`), commit the selection:
     - Call `invokeCaseBlockClick` / `onScheduleBlockClicked` as today, which will:
       - Sync selection to tables/buckets.
       - Re-apply overlays based on the true selection set.
   - If a drag occurred, keep existing drag behavior.

This is only necessary if, after Steps 2–4, the resize grip still feels noticeably delayed compared with the soft highlight.

**Testing / commands (Step 5)**

Same as previous steps, with emphasis on user feel:

```bash
matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/measure_schedule_click_timings.m');"
```

Then manual GUI checks focusing on:

- Immediate appearance of resize grip on mouse-down.
- Correct multi-select behavior (no accidental drags, no inconsistent selection states).

**Progress tracking (Step 5)**

- [ ] Decide whether pre-selection overlay is necessary after earlier optimizations.
- [ ] If implemented, verify that it doesn’t introduce regressions in drag/resize or selection semantics.

---

## Step 6 – Extend Improvements Beyond Main Schedule (If Needed)

**Objective:** Apply the same principles to other parts of the app where small interactions cause heavy re-renders.

Potential targets:

- Proposed tab selection and lock visuals (if we allow locking there).
- Cases tab selection interactions.
- Any other views where minor UI updates call `renderOptimizedSchedule` or `redrawSchedule`.

**Implementation tasks (Step 6)**

1. Reuse the timing helper from Step 1 to probe:
   - Proposed tab click/selection.
   - Cases tab selection operations (if they feed into schedule).
2. For any hot path identified:
   - Replace full re-renders with targeted overlays or partial updates, similar to Step 3.

**Testing / commands (Step 6)**

At minimum, re-run:

```bash
matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/manual_verify_time_control_phase2.m');"
matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/TestTimeControlBuckets.m');"
```

Plus manual checks on the Proposed tab and Cases tab.

**Progress tracking (Step 6)**

- [ ] Identify non-schedule hotspots via timing.
- [ ] Apply targeted partial updates where justified.
- [ ] Confirm end-to-end interactions remain correct across tabs.

---

## Completion Criteria and Cleanup

We will consider this plan **complete** when:

- [ ] Single-click selection feels instantaneous on the main schedule (no perceptible lag before the resize affordance appears).
- [ ] Double-click lock toggling no longer causes a noticeable pause due to full re-renders.
- [ ] Timing logs confirm measurable improvements over the baseline.
- [ ] All automated tests used above pass reliably.

**Final cleanup:**

- Once all boxes above are checked and the work is merged to `main`, delete this file:
  ```bash
  rm docs/Responsiveness-Improvements-Plan.md
  git add -u docs/Responsiveness-Improvements-Plan.md
  git commit -m \"Remove completed responsiveness plan doc\"
  ```
