Developer Quickstart

Start Here
- Launch GUI: conduction.launchSchedulerGUI
- Headless smoke: /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('<repo_root>'); app = conduction.launchSchedulerGUI(); pause(5); delete(app);"
- Run tests: /Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('<repo_root>'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"

Common Tasks
- Add a UI control to Add/Edit tab
  - Edit: scripts/+conduction/+gui/+app/buildCaseDetailsSection.m (or buildConstraintSection.m)
  - Wiring lives in ProspectiveSchedulerApp.setupUI via conduction.gui.app.* helpers
- Change schedule visuals
  - scripts/+conduction/+gui/+controllers/ScheduleRenderer.m (renderOptimizedSchedule)
  - Underlying drawer of blocks: scripts/+conduction/visualizeDailySchedule.m
- Time Control behavior
  - Toggle: scripts/+conduction/+gui/+app/toggleTimeControl.m
  - NOW drag: ScheduleRenderer.enableNowLineDrag/startDragNowLine/updateNowLinePosition/endDragNowLine
  - Status simulation: ScheduleRenderer.updateCaseStatusesByTime
- Optimisation options/execution
  - scripts/+conduction/+gui/+controllers/OptimizationController.m (update options, execute, status)
- Drawer inspector
  - scripts/+conduction/+gui/+controllers/DrawerController.m
  - UI builder: scripts/+conduction/+gui/+app/+drawer/buildDrawerUI.m
- Case management
  - scripts/+conduction/+gui/+controllers/CaseManager.m (CRUD, current time, completed archive)
  - Model: scripts/+conduction/+gui/+models/ProspectiveCase.m (CaseId, CaseStatus)
- Save/Load
  - App export/import: ProspectiveSchedulerApp (exportAppState/importAppState)
  - Serde: scripts/+conduction/+session/* (DailySchedule, ProspectiveCase, OperatorColors)
- Available labs selection
  - scripts/+conduction/+gui/+app/+availableLabs/* (bind select-all, get/apply selection)
- Analyse tab
  - scripts/+conduction/+gui/+app/renderAnalyticsTab.m; AnalyticsRenderer controller draws charts

Patterns & Conventions
- ProspectiveSchedulerApp stays thin; controllers hold logic; `+app` holds UI builders
- Helper-built UI uses function handles (e.g., @(src,evt) app.X(evt)), not createCallbackFcn
- Controllers accept `app` as first parameter; prefer persistent `CaseId` via CaseManager.findCaseById
- Time Control uses simulated schedule (`app.SimulatedSchedule`) when ON; do not archive in simulation
- Locks: baseline locks captured on enable; time-control-added locks tracked in app.TimeControlLockedCaseIds

Testing & Debugging
- Add `addpath(genpath('tests'))` before calling runtests
- Clear cached classes if behavior seems stale: clear classes
- NOW line debug:
  - findobj(app.ScheduleAxes,'Tag','NowLine'); get(ans,'UserData') -> timeMinutes after drop
  - app.CaseManager.getCurrentTime() should match drop time
  - Inspect one assignment: asgn = app.OptimizedSchedule.labAssignments(); ce = asgn{find(~cellfun(@isempty,asgn),1)}(1); fieldnames(ce)
  - Expect fields: caseID (string), procStartTime, procEndTime
- Re-render helpers
  - app.ScheduleRenderer.renderOptimizedSchedule(app, app.getScheduleForRendering(), app.OptimizationOutcome)

File Pointers
- App shell: scripts/+conduction/+gui/ProspectiveSchedulerApp.m
- Controllers: scripts/+conduction/+gui/+controllers/*.m
- View helpers: scripts/+conduction/+gui/+app/**/*.m
- Sessions: scripts/+conduction/+session/*.m
- Tests: tests/save_load/*.m

Tracing an Optimization Run
- Button press: ProspectiveSchedulerApp.OptimizationRunButtonPushed -> app.OptimizationController.executeOptimization(app)
- Case prep: CaseManager.buildOptimizationCases (applies defaults; returns cases struct + metadata)
- Locked constraints: DrawerController.extractLockedCaseAssignments -> OptimizationController.buildLockedCaseConstraints
- Options build: OptimizationController.buildSchedulingOptions (reads app.Opts and available labs)
- Execute: conduction.optimizeDailySchedule(casesStruct, scheduleOptions)
  - Preprocess: conduction.scheduling.SchedulingPreprocessor.prepareDataset(...)
- Render: ScheduleRenderer.renderOptimizedSchedule(app, dailySchedule, metadata)
- Drawer/KPI refresh: within ScheduleRenderer and AnalyticsRenderer
- Errors: OptimizationController catches, logs context (option snapshot, locks, case count) and shows uialert
