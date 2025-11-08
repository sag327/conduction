# Multi‑Case Selection & Bulk Actions Plan

Goal: Allow selecting multiple cases (from the Cases table and schedule), reflect that selection visually in the schedule, and perform bulk actions (starting with Remove Selected). Keep edits DRY and modular without bloating large files.

Non‑Goals (for now)
- Bulk drag/move/reschedule; bulk lock/unlock; bulk resource assignment. These are noted for future phases.
- Persisting selection state in sessions (selection is ephemeral UI state).

Principles
- Single source of truth for selection (`SelectedCaseIds` on the app), with legacy compatibility via `SelectedCaseId` (the last active case).
- Table drives selection; schedule click integrates with table selection semantics.
- Renders re‑apply highlights after any schedule redraw.
- Clear UX on multi‑select: the drawer does not attempt multi‑edit; either closed or showing a neutral message.

Potential Side‑Effects & Mitigations
- Re‑render wipes overlays: hook selection re‑highlight after each render (centralized path already used for single‑select; extend to multi).
- Performance with many selected cases: overlays are lightweight; if selection size > 200, cap highlights or switch to a simple tint (future safeguard).
- Time Control: selection operations must not interfere with NOW‑line, simulated statuses, or lock sets. Bulk remove must clean `LockedCaseIds` and `TimeControlLockedCaseIds`.
- Archive vs active: selection list may contain archived cases. Bulk remove should purge both active (`Cases`) and archived (`CompletedCases`) lists.

---

## Data Model & Events

Add to `ProspectiveSchedulerApp`:
- `SelectedCaseIds string = string.empty(0,1)` — multi‑selection source of truth.
- Keep `SelectedCaseId string` as the last clicked/active id for legacy code (e.g., drawer contents, resize grip ownership).

Eventing:
- Central `onSelectionChanged(app, by)` that:
  - Normalizes/uniquifies `SelectedCaseIds`.
  - Sets `SelectedCaseId` to the last member (or "").
  - Kicks `ScheduleRenderer` to reapply highlights for all selected ids (no full re‑optimize).
  - Updates bulk action enablement (e.g., disable Remove when empty).

Case table <-> app selection:
- Table selection change calls `app.CaseStore.getSelectedCaseIds()`; app assigns `SelectedCaseIds` and raises `onSelectionChanged`.
- Provide `selectCases(app, ids, mode)` helper:
  - mode=replace | add | remove | toggle (for schedule shift‑click integration and tests).

Schedule click semantics:
- Click a case block: replace selection with that id.
- Shift‑click a case block: add/remove that id to/from the selection.
- Double‑click behavior (toggle lock) remains as implemented today.

---

## Phase 1 — Selection State Plumbing (no visuals yet)

Changes
- `ProspectiveSchedulerApp`: add `SelectedCaseIds` (+ simple getters/setters), add `selectCases(app, ids, mode)` and `onSelectionChanged`.
- `CaseStore`: expose `getSelectedCaseIds()` and `setSelectedByIds(ids)`; ensure the table allows multi‑select (if not already enabled).

CLI validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  % Add 3 cases
  app.CaseManager.addCase('Dr A','Proc X',60); \
  app.CaseManager.addCase('Dr B','Proc Y',45); \
  app.CaseManager.addCase('Dr C','Proc Z',30); \
  % Simulate table multi-selection by ids
  ids = strings(3,1); for i=1:3, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids(1:2), 'replace'); \
  assert(numel(app.SelectedCaseIds)==2 && all(app.SelectedCaseIds==ids(1:2))); \
  % Add third via add mode
  app.selectCases(ids(3), 'add'); \
  assert(numel(app.SelectedCaseIds)==3); \
  delete(app);"
```

Acceptance
- `SelectedCaseIds` updates correctly; `SelectedCaseId` mirrors the last member.
- No visuals yet.

---

## Phase 2 — Visual Multi‑Highlight in Schedule

Changes
- `ScheduleRenderer`: add `applyMultiSelectionHighlights(app)` invoked at the end of `renderOptimizedSchedule` and when selection changes. Draw a lightweight selection overlay for each id; keep the resize grip tied to `SelectedCaseId` only.
- `CaseDragController`: expose `showSelectionOverlayForIds(app, ids)` and `hideSelectionOverlay` continues to clear; existing single overlay path generalized internally.

Notes
- Use existing overlay style (expand by lock line thickness); ensure overlays re‑register after any re‑render.

CLI validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  % Prepare a simple schedule with two cases in different labs
  for i=1:2, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  app.OptimizationController.executeOptimization(app); \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids, 'replace'); \
  % Count selection overlays
  h = findobj(app.ScheduleAxes,'Tag','CaseSelectionOverlay'); \
  assert(numel(h)>=2, 'Expected >=2 selection overlays'); \
  % Resize grip rendered at most once
  g = findobj(app.ScheduleAxes,'Tag','CaseResizeHandle'); \
  assert(numel(g)<=1, 'Expected <=1 resize grip'); \
  delete(app);"
```

Acceptance
- Each selected id shows an outline; only one grip (for `SelectedCaseId`).

---

## Phase 3 — Bulk Remove Selected (active + archived)

Behavior
- Remove action deletes all ids found in:
  - Active cases: `CaseManager.Cases`
  - Archived: `CaseManager.CompletedCases`
- Also purges ids from: `LockedCaseIds`, `TimeControlLockedCaseIds`, selection arrays.
- If a schedule exists: remove from `OptimizedSchedule` via `DailySchedule.removeCasesByIds`; mark optimization dirty; re‑render.
- Confirm dialog: “Remove N selected case(s)?”

Changes
- `ProspectiveSchedulerApp`: `removeSelectedCases(app)` orchestrator, marks dirty.
- `CasesWindowController`: bind Remove button to call `removeSelectedCases`.
- `DailySchedule`: already has `removeCasesByIds`; reuse.

CLI validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  % Active (3) + Archived (1) setup
  for i=1:3, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  arcId = app.CaseManager.getCase(1).CaseId; [~,idx]=app.CaseManager.findCaseById(arcId); \
  app.CaseManager.setCaseStatus(idx,'completed'); \
  % Select two active + one archived
  ids = string.empty(0,1); for i=2:3, ids(end+1)=app.CaseManager.getCase(i).CaseId; end; ids(end+1)=arcId; \
  app.selectCases(ids,'replace'); \
  % Invoke remove (non-UI path)
  app.removeSelectedCases(); \
  % Verify removals
  actLeft = app.CaseManager.CaseCount; \
  assert(actLeft==1,'Expected 1 active case remaining'); \
  archLeft = numel(app.CaseManager.getCompletedCases()); \
  assert(archLeft==0,'Expected archived case purged'); \
  % Locks purged
  assert(~any(ismember(app.LockedCaseIds, ids))); \
  delete(app);"
```

Acceptance
- Active and archived selections are removed; locks and selection cleared; schedule re‑rendered.

---

## Phase 4 — Time Control Compatibility

Behavior
- Remove works during Time Control. After delete:
  - Purge from `OptimizedSchedule` (and `SimulatedSchedule` by recompute), 
  - Clear selected ids from lock sets and selection arrays,
  - Mark optimization dirty, refresh visuals via the simulated path.

Changes
- `removeSelectedCases` calls `ScheduleRenderer.updateCaseStatusesByTime` after removal when `IsTimeControlActive` to update `SimulatedSchedule` and keep locks consistent.

CLI validation
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:3, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  app.OptimizationController.executeOptimization(app); \
  app.IsTimeControlActive = true; app.CaseManager.setCurrentTime(9*60); \
  ids = string.empty(0,1); for i=1:2, ids(end+1)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids,'replace'); app.removeSelectedCases(); \
  % Removed in both optimized and simulated views
  optCases = app.OptimizedSchedule.cases(); \
  simCases = app.SimulatedSchedule.cases(); \
  % Collect IDs
  oc = {}; if ~isempty(optCases), oc = {optCases.caseID}; end; \
  sc = {}; if ~isempty(simCases), sc = {simCases.caseID}; end; \
  assert(~any(ismember(ids,string(oc)))) && ~any(ismember(ids,string(sc))); \
  delete(app);"
```

Acceptance
- No exceptions; removed ids absent from both views; locks & selection cleared.

---

## Phase 5 — Schedule Click Integration (shift‑click add)

Behavior
- Click a case block replaces the selection with that id.
- Shift‑click a case block adds/removes that id to/from the selection (MATLAB `SelectionType == 'extend'`).

Changes
- `ScheduleRenderer.invokeCaseBlockClick`: detect `SelectionType == 'extend'` and use `app.selectCases(caseId, 'toggle')`; otherwise `replace`. Keep double‑click (SelectionType== 'open') behavior intact.
- `ProspectiveSchedulerApp.selectCases`: support `toggle` mode (add if absent, remove if present).

CLI validation (headless substitute)
```bash
matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); \
  app = conduction.launchSchedulerGUI(); \
  for i=1:2, app.CaseManager.addCase(sprintf('Dr %d',i),'Proc',30); end; \
  ids = strings(2,1); for i=1:2, ids(i)=app.CaseManager.getCase(i).CaseId; end; \
  app.selectCases(ids(1),'replace'); \
  app.selectCases(ids(2),'toggle'); \
  assert(all(ismember(ids, app.SelectedCaseIds))); \
  app.selectCases(ids(2),'toggle'); \
  assert(~ismember(ids(2), app.SelectedCaseIds)); \
  delete(app);"
```

Acceptance
- Toggle logic works; later the schedule click handler will call into this.

---

## Phase 6 — UX Polish & Future Bulk Actions (not implemented now)

- Keyboard shortcuts: `Delete` to remove selected; `Esc` to clear selection. Provide a small key dispatcher on the figure; guarded feature flag.
- Drawer: when `numel(SelectedCaseIds)>1`, keep the drawer closed or show neutral text (“Multiple cases selected; bulk edits coming soon”).
- Bulk lock/unlock: extend `DrawerLockToggle` or add a dedicated action to apply to all selected (future).
- Bulk assign resources (future): add a resource picker dialog to apply to selected cases, reusing `ResourceController.applyResourcesToCase` in a loop. Plan for command to verify that all selected cases receive the resources and that capacity checks still pass.

---

## File/Hook Inventory (by phase)

- Phase 1: `ProspectiveSchedulerApp.m`, `+stores/CaseStore.m`
- Phase 2: `+controllers/ScheduleRenderer.m`, `+controllers/CaseDragController.m`
- Phase 3: `ProspectiveSchedulerApp.m` (removeSelectedCases), `+controllers/CasesWindowController.m`
- Phase 4: reuse `ScheduleRenderer.updateCaseStatusesByTime` in remove path when `IsTimeControlActive`
- Phase 5: `ScheduleRenderer.invokeCaseBlockClick` (SelectionType == extend) and `ProspectiveSchedulerApp.selectCases`

---

## Rollback/Compatibility
- Legacy single‑select flows keep working through `SelectedCaseId` (set to the last selected id).
- Selection state is not serialized; session files unaffected.
- All guards default to single‑select behavior until multi‑select is wired end‑to‑end.

