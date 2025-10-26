# ProspectiveSchedulerApp Refactor Implementation Plan

A staged approach to shrinking `ProspectiveSchedulerApp.m` while keeping behaviour identical. Each phase introduces one integration surface at a time, with explicit validation before proceeding.

## Goals & Constraints
- Reduce file size and complexity by extracting cohesive responsibilities into controllers/utilities.
- Maintain current public methods, callbacks, and test interfaces (wrappers forward into new modules).
- Avoid behaviour changes; each phase should be a pure migration with verification.
- Provide concrete automated and manual tests per phase to confirm parity.

## Global Pre-flight
1. Ensure MATLAB path points to project root:
   ```matlab
   addpath(genpath(fullfile(pwd, 'scripts')));
   ```
2. Baseline smoke test (optional but recommended):
   ```bash
   /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); app = conduction.launchSchedulerGUI(); pause(5); delete(app);"
   ```
3. Baseline save/load suite:
   ```bash
   /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"
   ```
Resolve any failures before starting.

## Phase 0 – Organise the App File (No Behaviour Change)
**Objective:** Introduce structure (grouped sections, logical ordering) to make upcoming extractions easier.

### Tasks
- Add comment headers grouping related methods (Resources, Sessions, Popout, Time Control, Utilities, etc.).
- Reorder methods so helpers sit next to their callbacks. Avoid altering bodies.

### Tests
- Automated regression: none required.
- Manual spot check: launch GUI once to ensure it still opens (`conduction.launchSchedulerGUI`).

## Phase 1 – Extract ResourceController
**Objective:** Move resource tab callbacks, store wiring, and legend refresh logic into `+controllers/ResourceController`.

### Scope
- `onResourceTableSelectionChanged`, `onSaveResourcePressed`, `onDeleteResourcePressed`, `onResetResourcePressed`.
- `refreshResourcesTable`, `refreshDefaultResourcesPanel`, `clearResourceForm`, `applyResourcesToCase`.
- Store helpers: `ensureResourceStoreListener`, `onResourceStoreChanged`, `getValidatedResourceStore`.
- Legend helpers: `refreshResourceLegend`, `updateResourceLegendContents`, `onResourceLegendHighlightChanged`.

### Tasks
- Create `scripts/+conduction/+gui/+controllers/ResourceController.m`.
- Instantiate controller in app setup; keep app properties the same.
- Replace method bodies in app with forwarding wrappers calling controller methods.

### Tests
- Automated regression:
  1. Quick state extraction regression (ensures resource data still serialises):
     ```bash
     /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load/test_stage2_state_extraction'); disp(results); exit(~all([results.Passed]));"
     ```
  2. Full save/load suite (recommended before proceeding):
     ```bash
     /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"
     ```
- Manual spot checks:
  - Launch GUI, add a new resource (name + capacity), verify row appears in table and legend updates.
  - Toggle default checkbox, confirm Add tab checklist updates immediately.
  - Delete resource, confirm confirmation dialog still appears and legend clears.

### Optional Debug Aid
- Temporarily enable `app.debugLog` calls within controller entry points to trace invocations. Remove before committing.

## Phase 2 – Extract SessionController
**Objective:** Move save/load UI callbacks, state serialization, and autosave timer handling into a dedicated controller.

### Scope
- UI callbacks: `SaveSessionButtonPushed`, `LoadSessionButtonPushed`, `AutoSaveCheckboxValueChanged`.
- Core methods: `exportAppState`, `importAppState`, `enableAutoSave`, `startAutoSaveTimer`, `stopAutoSaveTimer`, `rotateAutoSaves`, and related helpers.

### Tasks
- Create `scripts/+conduction/+gui/+controllers/SessionController.m`.
- App retains public wrappers forwarding into controller to keep tests (`app.exportAppState`) unchanged.
- Session controller references existing serializers under `scripts/+conduction/+session/`.

### Tests
- Automated regression (focus on save/load stages):
  ```bash
  /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests({'tests/save_load/test_stage2_state_extraction','tests/save_load/test_stage3_state_restoration','tests/save_load/test_stage5_save_ui','tests/save_load/test_stage6_load_ui','tests/save_load/test_stage7_dirty_tracking','tests/save_load/test_stage8_autosave'}); disp(results); exit(~all([results.Passed]));"
  ```
- Manual spot checks:
  - Launch GUI, add a case, click **Save Session**, ensure file saved and dirty flag clears in window title.
  - Modify data (add a resource), click **Load Session**, confirm unsaved-changes prompt appears.
  - Enable Auto-save, wait >5 minutes or adjust interval temporarily to verify autosave files rotate in `./sessions/autosave`.

### Optional Debug Aid
- Add temporary `fprintf` in controller when autosave starts/stops; remove after validation.

## Phase 3 – Extract CasesWindowController
**Objective:** Move cases tab popout/undock handling into its own controller.

### Scope
- `handleCasesUndockRequest`, `applyCasesTabUndockedState`, `createCasesTabOverlay`, `focusCasesPopout`, `redockCases`, `onCasesPopoutRedock`.

### Tasks
- Create `scripts/+conduction/+gui/+controllers/CasesWindowController.m`.
- Controller manages `CasesPopout` lifecycle; app wrappers forward events.

### Tests
- Automated regression:
  ```bash
  /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load/test_stage2_state_extraction'); disp(results); exit(~all([results.Passed]));"
  ```
  (Popout logic has no dedicated unit test; re-run full suite before next phase.)
- Manual spot checks:
  - Launch GUI, click **Open Window** in Cases tab; verify overlay appears and popout shows cases table.
  - Press **Esc** or **Redock** button; confirm cases table returns inline and overlay clears.
  - Use **Focus Window** button when popout is open.

### Optional Debug Aid
- Temporary logging in controller for `applyCasesTabUndockedState` transitions.

## Phase 4 – Extract Time Control Timer Helper
**Objective:** Move current-time timer management out of app into existing `CaseStatusController` or a small helper.

### Scope
- `startCurrentTimeTimer`, `stopCurrentTimeTimer`, `onCurrentTimeTimerTick` and associated timer properties.

### Tasks
- Extend `CaseStatusController` (preferred) with timer lifecycle methods.
- App methods become wrappers; ensure controller updates ScheduleRenderer's NOW line and current-time labels exactly as before.

### Tests
- Automated regression:
  ```bash
  /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load/test_time_control_load_behavior'); disp(results); exit(~all([results.Passed]));"
  ```
  Follow with the full save/load suite to guard regressions.
- Manual spot checks:
  - Launch GUI, toggle Time Control ON, ensure NOW line appears.
  - Toggle **Current Time** checkbox; observe label and NOW line update every second.
  - Disable Time Control, verify timer stops (no further updates).

### Optional Debug Aid
- Temporary `debugLog('TimeControlTimer','tick')` inside timer callback to verify firing; remove after confirmation.

## Phase 5 – Utilities Cleanup
**Objective:** Move generic helpers (dialogs, logging) into reusable utilities under `+utils`.

### Scope
- Dialog wrappers: `showAlert`, `showConfirm`, `showQuestion` → `conduction.gui.utils.Dialogs` (static methods).
- Optional: migrate `debugLog` to `conduction.gui.utils.DebugLogger`.

### Tasks
- Implement utilities with same defaults (title, icon, cancel behaviour).
- Replace app/controller calls with the new utility functions.

### Tests
- Automated regression: run quick subset to ensure dialogs don’t break save/load flows (since they exercise confirmations).
  ```bash
  /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load/test_stage6_load_ui'); disp(results); exit(~all([results.Passed]));"
  ```
  Then run complete save/load suite once more.
- Manual spot checks:
  - Trigger validation error (attempt to save resource with empty name) to ensure alert still appears.
  - Delete a resource to confirm confirmation dialog works.

## Final Regression & Cleanup
1. Run entire save/load suite one last time:
   ```bash
   /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"
   ```
2. Optional GUI smoke test for sanity.
3. Remove any temporary logging/debug code introduced during validation.
4. Review `ProspectiveSchedulerApp.m` to confirm it primarily wires controllers and UI.

## Rollback Strategy
- Each phase only touches a discrete set of files. If validation fails, revert files from that phase and rerun baseline tests.
- Keep commit checkpoints per phase for quick rollbacks.

## Follow-on Ideas (Post-Refactor)
- Add targeted unit tests for new controllers once stable.
- Evaluate whether save/load tests can exercise controllers directly for faster iteration.
