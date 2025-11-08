# Visualized Schedule Multi‑Select Plan

Goal
- Allow users to select multiple cases directly on the schedule with Shift/Ctrl clicks.
- Keep selection synchronized with the Cases table highlights and schedule overlays.
- When multiple cases are selected, disable drag/resize and show a neutral drawer message instead of the inspector.

Non‑Goals (for this iteration)
- Bulk edit operations from the drawer (beyond Remove Selected which already exists).
- Bulk drag/move/resizing; bulk lock/unlock; bulk resource assignment.
- Persisting selection state in sessions (selection is transient UI state).

Principles
- Single source of truth: `app.SelectedCaseIds` (last member mirrored as `app.SelectedCaseId` for legacy paths).
- DRY reuse of existing selection, overlay, and guard logic implemented for multi‑select from the table.
- Clear, minimal UX: show multi‑select message in the drawer; maintain current drag/resize disable with concise warnings.

Current State (baseline)
- Multi‑select plumbing exists (SelectedCaseIds, selectCases, ID↔index sync to CaseStore).
- Overlays render for multiple cases; resize grip is hidden when multi‑select is active.
- Drag/resize is disabled while multi‑select is active (with brief warnings).
- Schedule click already supports: double‑click to lock toggle, and shift‑click toggling via `SelectionType == 'extend'`.

---

## Phase 1 — Robust Modifier Detection for Schedule Clicks

Why
- Ensure both Shift and Ctrl/Command clicks trigger toggle selection across platforms.

Changes
- `ScheduleRenderer.invokeCaseBlockClick`:
  - Treat `SelectionType == 'open'` as lock‑toggle (unchanged).
  - Treat `SelectionType == 'extend'` OR `any(get(fig,'CurrentModifier') ∈ {'shift','control','command'})` as toggle.
  - Otherwise, replace selection.

CLI Validation (headless stand‑in using app helpers)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:3, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  ids = strings(3,1); for i=1:3, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  % Replace
  app.selectCases(ids(1),'replace'); assert(isequal(app.SelectedCaseIds, ids(1))); \
  % Toggle on second and third
  app.selectCases(ids(2),'toggle'); app.selectCases(ids(3),'toggle'); \
  assert(all(ismember(ids, app.SelectedCaseIds))); \
  delete(app);"
```

Acceptance
- Toggle/replace semantics work via `selectCases`; later verified via manual GUI clicks with modifiers.

---

## Phase 2 — Table Highlight Sync From Schedule Selection

Why
- Selecting on the canvas should mirror row selection in the Cases table.

Changes
- None expected; `assignSelectedCaseIds` already pushes indices to `CaseStore.setSelection`.
- Keep `CaseTableView` multiselect on (already set).

CLI Validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:2, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids,'replace'); \
  assert(numel(app.CaseStore.Selection)==2); \
  delete(app);"
```

Acceptance
- Case table shows two highlighted rows matching the selected IDs.

---

## Phase 3 — Drawer Neutral View For Multi‑Select

Why
- The inspector should not imply single‑case editing when multiple are selected.

Changes
- `ProspectiveSchedulerApp.updateCaseSelectionVisuals`:
  - If `app.isMultiSelectActive()`: set `DrawerCurrentCaseId = ""`.
  - If the drawer is open, call new `DrawerController.showMultiSelectMessage(app)` to display a neutral message (e.g., “Multiple cases selected; bulk edits coming soon”).
- `DrawerController.showMultiSelectMessage(app)`:
  - Clear any case‑specific panels; show a centered label or simple panel with Tag `DrawerMultiSelectMessage`.

CLI Validation (headless proxy)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:2, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids,'replace'); \
  assert(app.isMultiSelectActive() && strlength(app.DrawerCurrentCaseId)==0); \
  % Optional (if drawer open in tests): msg = findobj(app.UIFigure,'Tag','DrawerMultiSelectMessage'); \
  % assert(~isempty(msg)); \
  app.selectCases(ids(1),'replace'); \
  assert(~app.isMultiSelectActive() && app.DrawerCurrentCaseId==ids(1)); \
  delete(app);"
```

Acceptance
- Drawer does not show single‑case inspector UI while multiple cases are selected.

---

## Phase 4 — Interaction Guard (Regression)

Why
- Ensure we continue to block drag/resize while multi‑select is active.

Changes
- None (already implemented): guards in `ScheduleRenderer` and `CaseDragController`.

CLI Validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:2, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  app.OptimizationController.executeOptimization(app); \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids,'replace'); \
  assert(~app.CaseDragController.canInteractWithCase(ids(1))); \
  assert(isempty(findobj(app.ScheduleAxes,'Tag','CaseResizeHandle','Visible','on'))); \
  app.selectCases(ids(1),'replace'); \
  assert(app.CaseDragController.canInteractWithCase(ids(1))); \
  assert(~isempty(findobj(app.ScheduleAxes,'Tag','CaseResizeHandle','Visible','on'))); \
  delete(app);"
```

Acceptance
- No interaction affordances while multi‑select is active; normal affordances when single‑selected.

---

## Phase 5 — Background Click Clears Selection

Why
- Quick way to exit multi‑select without reaching for the table.

Changes
- Confirm `ScheduleRenderer` uses `BackgroundClickedFcn` to call `app.onScheduleBackgroundClicked()`, which clears CaseStore selection (already present). No code changes expected.

CLI Validation (stand‑in)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:2, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids,'replace'); \
  app.onScheduleBackgroundClicked(); \
  assert(isempty(app.SelectedCaseIds)); \
  delete(app);"
```

Acceptance
- Background click clears selection (GUI), verified by helper in headless test.

---

## Phase 6 — Time Control Compatibility

Why
- Multi‑select behavior must be consistent under simulated schedule rendering and NOW line.

Changes
- None expected; overlays and guards already respect time control paths.

CLI Validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:3, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  app.OptimizationController.executeOptimization(app); \
  app.IsTimeControlActive = true; app.CaseManager.setCurrentTime(9*60); \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids,'replace'); \
  % Overlays exist, no active resize grip, drag disabled \
  assert(~app.CaseDragController.canInteractWithCase(ids(1))); \
  assert(isempty(findobj(app.ScheduleAxes,'Tag','CaseResizeHandle','Visible','on'))); \
  delete(app);"
```

Acceptance
- Same interaction rules and overlays apply during Time Control.

---

## File/Hook Inventory
- `+controllers/ScheduleRenderer.m`
  - `invokeCaseBlockClick` modifier detection (extend + CurrentModifier).
- `ProspectiveSchedulerApp.m`
  - `updateCaseSelectionVisuals` drawer logic for multi‑select; keep overlays & CaseStore sync.
- `+controllers/DrawerController.m`
  - `showMultiSelectMessage(app)` helper for neutral view.

---

## Rollback/Compatibility
- Legacy single‑select flows unchanged (`SelectedCaseId` still maintained).
- Session files unaffected (selection not serialized).
- Existing guards continue to disable drag/resize under multi‑select.

---

## Notes for Manual QA (GUI)
- Single, Shift, Ctrl/Command clicks on schedule blocks with a few cases added.
- Double‑click still toggles lock state.
- Drawer shows neutral text only when multi‑select is active; returns to normal inspector on single select.

