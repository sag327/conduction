# Developer Quickstart

## Start Here

### Launch GUI
```matlab
conduction.launchSchedulerGUI

% With historical data for Testing Mode
conduction.launchSchedulerGUI(datetime('2025-01-15'), 'clinicalData/exampleDataset.xlsx')
```

### Headless Smoke Test
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('<repo_root>'); app = conduction.launchSchedulerGUI(); pause(5); delete(app);"
```

### Run Tests
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('<repo_root>'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"
```

### Re‑optimization Preview (GUI Smoke)
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes;\
app = conduction.launchSchedulerGUI(); pause(2);\
app.OptLabsSpinner.Value = 2; app.OptimizationController.updateOptimizationOptionsFromTab(app);\
for i=1:4, app.CaseManager.addCase(string('Op')+i, string('Proc')+i, 30); end;\
app.OptimizationRunButtonPushed(app.RunBtn); pause(2);\
labs = app.OptimizedSchedule.labAssignments();\
firstEnd = labs{1}(1).procEndTime + labs{1}(1).postTime + labs{1}(1).turnoverTime;\
app.setNowPosition(firstEnd + 5); app.OptimizationRunButtonPushed(app.RunBtn); pause(2);\
assert(~isempty(app.ProposedSchedule), 'Proposed schedule missing');\
delete(app); disp('✅ Re-optimize preview smoke PASS');"
```

## Common Tasks

### Add a UI Control to Add/Edit Tab
**Files to Edit**:
- `scripts/+conduction/+gui/+app/buildCaseDetailsSection.m` (for case details fields)
- `scripts/+conduction/+gui/+app/buildConstraintSection.m` (for constraint fields)
- `scripts/+conduction/+gui/+app/buildResourcesTab.m` (for resource management)

**Wiring**: UI setup lives in `ProspectiveSchedulerApp.setupUI` via `conduction.gui.app.*` helpers

**Example**:
```matlab
% In buildCaseDetailsSection.m
app.MyNewField = uieditfield(grid, 'text');
app.MyNewField.Layout.Row = 5;
app.MyNewField.Layout.Column = 2;
app.MyNewField.ValueChangedFcn = @(~,~) app.onMyFieldChanged();
```

### Change Schedule Visuals
**Files**:
- `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m` (renderOptimizedSchedule)
- `scripts/+conduction/visualizeDailySchedule.m` (underlying Gantt drawer)

**Example**:
```matlab
% In ScheduleRenderer.renderOptimizedSchedule
conduction.visualizeDailySchedule(schedule, ...
    'Parent', app.ScheduleAxes, ...
    'Title', 'My Custom Title', ...
    'ShowResourceIndicators', true);
```

### Time Control Behavior
**Files**:
- Toggle: `scripts/+conduction/+gui/+app/toggleTimeControl.m`
- NOW line drag: `ScheduleRenderer.enableNowLineDrag/startDragNowLine/updateNowLinePosition/endDragNowLine`
- Status simulation: `ScheduleRenderer.updateCaseStatusesByTime`

**Flow**:
1. User enables Time Control → `toggleTimeControl.m` sets `app.IsTimeControlActive = true`
2. `CaseManager.setCurrentTime(startMinutes)` initializes timeline
3. NOW line appears on schedule via `ScheduleRenderer.renderNowLine`
4. User drags NOW line → `endDragNowLine` calls `updateCaseStatusesByTime`
5. Cases marked as completed/in-progress based on timeline position
6. Schedule re-rendered with simulated statuses

### Optimization Options/Execution
**File**: `scripts/+conduction/+gui/+controllers/OptimizationController.m`

**Key Methods**:
- `updateOptimizationOptionsSummary(app)` – Refresh options display
- `buildSchedulingOptions(app)` – Convert UI state to options struct
- `executeOptimization(app)` – Run ILP solver
- `updateOptimizationStatus(app)` – Update status label
- `updateOptimizationActionAvailability(app)` – Enable/disable optimize button

Re‑optimization routing (NOW > first case):
- Proposed tab preview via `app.showProposedTab()` with frozen context before NOW
- Per‑lab earliest start enforcement threaded through:
  - `SchedulingOptions.LabEarliestStartMinutes` (scheduling layer)
  - `SchedulingPreprocessor` → `prepared.earliestStartMinutes`
  - `OptimizationModelBuilder` → valid time slots per lab

### Drawer Inspector
**Files**:
- Controller: `scripts/+conduction/+gui/+controllers/DrawerController.m`
- UI builder: `scripts/+conduction/+gui/+app/+drawer/buildDrawerUI.m`

**Key Methods**:
- `populateDrawer(app, caseId)` – Fill drawer with case details
- `extractLockedCaseAssignments(app)` – Get locked labs for optimization constraints
- `gatherSolverMessages(app)` – Aggregate solver diagnostics

### Case Management
**Files**:
- Controller: `scripts/+conduction/+gui/+controllers/CaseManager.m`
- Model: `scripts/+conduction/+gui/+models/ProspectiveCase.m`
- Store: `scripts/+conduction/+gui/+stores/CaseStore.m`

**CRUD Operations**:
```matlab
% Create
caseId = app.CaseManager.createCase('operator', op, 'procedure', proc, ...
    'setupMinutes', 30, 'procedureMinutes', 90, 'postMinutes', 15);

% Read
caseObj = app.CaseManager.findCaseById(caseId);

% Update
app.CaseManager.updateCase(caseId, 'procedureMinutes', 120);

% Delete
app.CaseManager.deleteCase(caseId);
```

**Batch Operations**:
```matlab
app.CaseStore.beginBatchUpdate();
try
    app.CaseManager.createCase(...);
    app.CaseManager.createCase(...);
finally
    app.CaseStore.endBatchUpdate();  % Fires single CasesChanged event
end
```

### Resource Management
**Files**:
- Store: `scripts/+conduction/+gui/+stores/ResourceStore.m`
- Model: `scripts/+conduction/+gui/+models/ResourceType.m`
- Tab builder: `scripts/+conduction/+gui/+app/buildResourcesTab.m`

**Operations**:
```matlab
% Create resource
store = app.CaseManager.getResourceStore();
store.create('Equipment X', 5, false);  % name, capacity, isDefault

% Update resource
store.update(resourceId, 'Capacity', 10);
store.update(resourceId, 'IsDefault', true);

% Delete resource
store.remove(resourceId);

% Get all resources
types = store.list();  % Returns array of ResourceType objects
```

### Save/Load Sessions
**Files**:
- App methods: `ProspectiveSchedulerApp.exportAppState` / `importAppState`
- Serializers: `scripts/+conduction/+session/*`

**Usage**:
```matlab
% Export
state = app.exportAppState();
save('session.mat', 'state');

% Import
load('session.mat', 'state');
app.importAppState(state);
```

### Available Labs Selection
**Files**: `scripts/+conduction/+gui/+app/+availableLabs/*`

**Utilities**:
- `bindSelectAllCheckbox(app)` – Wire select-all checkbox
- `getAvailableLabSelection(app)` – Get currently selected labs
- `applyAvailableLabSelection(app, labIds)` – Set selected labs

### Analyze Tab
**Files**:
- Builder: `scripts/+conduction/+gui/+app/renderAnalyticsTab.m`
- Controller: `scripts/+conduction/+gui/+controllers/AnalyticsRenderer.m`

**Rendering**:
```matlab
app.AnalyticsRenderer.drawOperatorUtilizationCharts(app, dailySchedule);
```

## Tips: Unified Timeline & Scope Controls
- NOW is always visible; moving NOW recomputes case status.
- Smart Optimize button label updates automatically via `app.refreshOptimizeButtonLabel()`.
- Scope controls (Optimization tab) appear when NOW > first case:
  - Include: Unscheduled only vs Unscheduled + scheduled future
  - Respect user locks (on/off)
  - Prefer current labs (soft preference)
- “Advance NOW to Actual” shows if NOW differs from clock by ≥ 5 minutes; “Reset to Planning” rewinds to start and clears manual completions.

## Patterns & Conventions

### Controller Pattern
- `ProspectiveSchedulerApp` stays thin
- Controllers hold business logic
- `+app` helpers hold UI construction
- Controllers accept `app` as first parameter
- Use persistent `CaseId` via `CaseManager.findCaseById(caseId)`

### UI Builder Pattern
- Helper-built UI uses function handles: `@(src,evt) app.onCallback(evt)`
- **NOT** `createCallbackFcn` (keeps builders independent)
- Builders return components, caller wires them into layout

### Event-Driven Pattern
- Stores fire events on mutations (`CasesChanged`, `TypesChanged`)
- App listens and refreshes UI
- Batch updates prevent redundant refreshes

### FormStateManager Pattern
**Use case**: Forms with Save/Reset buttons that should only enable when dirty

**Usage**:
```matlab
% 1. Create form fields
app.NameField = uieditfield(grid, 'text');
app.ValueSpinner = uispinner(grid);

% 2. Create Save/Reset buttons
app.SaveButton = uibutton(grid, 'push');
app.ResetButton = uibutton(grid, 'push');

% 3. Create FormStateManager
fields = {app.NameField, app.ValueSpinner};
app.FormManager = conduction.gui.utils.FormStateManager(fields, ...
    app.SaveButton, app.ResetButton);

% 4. Set pristine values when loading data
app.FormManager.setPristineValues({'Initial Name', 42});

% 5. FormStateManager automatically enables/disables buttons on field changes
```

### Time Control Pattern
- **Simulation mode**: Time Control ON
  - `app.IsTimeControlActive = true`
  - `app.SimulatedSchedule` holds schedule with simulated statuses
  - Cases marked completed/in-progress are NOT archived
- **Real mode**: Time Control OFF
  - Use `app.OptimizedSchedule` for rendering
  - Completed cases can be archived via `CaseManager.archiveCompletedCases()`

**Rules**:
- Locks: baseline locks captured on Time Control enable
- Time-control-added locks tracked in `app.TimeControlLockedCaseIds`
- Simulated completion does NOT trigger archiving

## Testing & Debugging

### Clear Cached Classes
Always run before launching GUI after code changes:
```matlab
clear classes
```

### Run Save/Load Tests
```matlab
addpath(genpath('tests'))
results = runtests('tests/save_load');
disp(results);
```

### NOW Line Debug
```matlab
% Find NOW line object
nowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
timeMinutes = get(nowLine, 'UserData');

% Check current time
currentTime = app.CaseManager.getCurrentTime();

% Inspect schedule assignment
asgn = app.OptimizedSchedule.labAssignments();
caseEntry = asgn{find(~cellfun(@isempty,asgn),1)}(1);
fieldnames(caseEntry)  % Should include: caseID, procStartTime, procEndTime
```

### Re-render Schedule
```matlab
% Force re-render with current schedule
app.ScheduleRenderer.renderOptimizedSchedule(app, ...
    app.getScheduleForRendering(), ...
    app.OptimizationOutcome);
```

### Inspect Store State
```matlab
% Case store
cases = app.CaseStore.list();
fprintf('Cases: %d\n', numel(cases));

% Resource store
resources = app.CaseManager.getResourceStore().list();
fprintf('Resources: %d\n', numel(resources));
```

## File Pointers

### Core Files
- **App shell**: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
- **Controllers**: `scripts/+conduction/+gui/+controllers/*.m`
- **Stores**: `scripts/+conduction/+gui/+stores/*.m`
- **Models**: `scripts/+conduction/+gui/+models/*.m`
- **Components**: `scripts/+conduction/+gui/+components/*.m`
- **Utilities**: `scripts/+conduction/+gui/+utils/*.m`
- **View helpers**: `scripts/+conduction/+gui/+app/**/*.m`
- **Sessions**: `scripts/+conduction/+session/*.m`
- **Tests**: `tests/save_load/*.m`

### Key View Helpers
- `buildCaseDetailsSection.m` – Operator, procedure, duration fields
- `buildConstraintSection.m` – Must-go-first, preferred lab
- `buildResourcesTab.m` – Resource type management UI
- `renderAnalyticsTab.m` – Operator utilization charts
- `+drawer/buildDrawerUI.m` – Case inspector drawer
- `+availableLabs/*` – Lab selection checkboxes

## Tracing an Optimization Run

### Execution Flow
1. **Button press**: `ProspectiveSchedulerApp.OptimizationRunButtonPushed` → `app.OptimizationController.executeOptimization(app)`

2. **Case preparation**: `CaseManager.buildOptimizationCases()`
   - Applies defaults (admission type, resources)
   - Returns cases struct + metadata

3. **Locked constraints**:
   - `DrawerController.extractLockedCaseAssignments()` → locked lab assignments
   - `OptimizationController.buildLockedCaseConstraints()` → constraint struct

4. **Options build**: `OptimizationController.buildSchedulingOptions(app)`
   - Reads `app.Opts` (UI state)
   - Gets available labs from checkboxes
   - Includes turnover times, objective metric, admission defaults, first-case constraints

5. **Execute**: `conduction.optimizeDailySchedule(casesStruct, scheduleOptions, lockedConstraints)`
   - Preprocessing: `conduction.scheduling.SchedulingPreprocessor.prepareDataset(...)`
   - ILP solve: Returns `[dailySchedule, outcome]`

6. **Render**: `ScheduleRenderer.renderOptimizedSchedule(app, dailySchedule, outcome)`
   - Calls `conduction.visualizeDailySchedule` to draw Gantt
   - Updates drawer and KPI footer
   - Refreshes analytics tab

7. **Drawer/KPI refresh**: Within `ScheduleRenderer` and `AnalyticsRenderer`

8. **Error handling**: `OptimizationController` catches exceptions
   - Logs context: option snapshot, locks, case count
   - Shows `uialert` with error details

### Where Solver Messages Appear in Drawer

**Source**: `app.OptimizationOutcome` (structure returned by `conduction.optimizeDailySchedule`)

**Drawer build path**:
1. `DrawerController.populateDrawer(app, caseId)` populates text fields
2. Calls `DrawerController.gatherSolverMessages(app)`
   - Reads `app.OptimizationOutcome`
   - Aggregates messages from phases
   - Uses `DrawerController.extractMessagesFromOutcome(outcome, label)` for summaries
3. `OptimizationController.updateDrawerOptimizationSection(app)` keeps drawer's optimization section in sync after runs

**To debug**: Inspect `app.OptimizationOutcome` before calling `populateDrawer`

### OptimizationOutcome Structure

Typical top-level fields:
- `objectiveValue` (double) – Final objective value
- `exitflag` (numeric or string) – Solver exit summary
- `output` (struct or string) – Solver message text and metadata
- `phase1`, `phase2` (optional structs) – Each with same fields: `objectiveValue`, `exitflag`, `output`

**Note**: `DrawerController` uses these fields to build readable lines. Additional fields ignored unless `extractMessagesFromOutcome` is extended.

## Adding New Features

### Add a New Tab
1. Add property in `ProspectiveSchedulerApp.m`: `TabMyFeature matlab.ui.container.Tab`
2. Create tab in `setupUI`: `app.TabMyFeature = uitab(app.TabGroup, 'Title', 'My Feature');`
3. Create builder: `scripts/+conduction/+gui/+app/buildMyFeatureTab.m`
4. Call builder: `conduction.gui.app.buildMyFeatureTab(app, gridLayout);`

### Add a New Controller
1. Create class: `scripts/+conduction/+gui/+controllers/MyController.m`
   ```matlab
   classdef MyController < handle
       methods
           function myMethod(obj, app)
               % Logic here
           end
       end
   end
   ```
2. Add property to `ProspectiveSchedulerApp.m`: `MyController conduction.gui.controllers.MyController`
3. Instantiate in `setupComponents`: `app.MyController = conduction.gui.controllers.MyController();`
4. Wire callbacks: `app.MyButton.ButtonPushedFcn = @(~,~) app.MyController.myMethod(app);`

### Add a New Store
1. Create class: `scripts/+conduction/+gui/+stores/MyStore.m`
   ```matlab
   classdef MyStore < handle
       events
           DataChanged
       end
       methods
           function create(obj, ...)
               % Add item
               notify(obj, 'DataChanged');
           end
       end
   end
   ```
2. Add property to `ProspectiveSchedulerApp.m`: `MyStore conduction.gui.stores.MyStore`
3. Instantiate: `app.MyStore = conduction.gui.stores.MyStore();`
4. Add listener: `addlistener(app.MyStore, 'DataChanged', @(~,~) app.onMyStoreChanged());`

### Add FormStateManager to a Form
See "FormStateManager Pattern" above for complete example.

## Debugging Tips

### Breakpoint Locations
- **Before optimization**: `OptimizationController.executeOptimization` (line ~50)
- **After optimization**: `ScheduleRenderer.renderOptimizedSchedule` (line ~10)
- **Drawer population**: `DrawerController.populateDrawer` (line ~20)
- **Case creation**: `CaseManager.createCase` (line ~30)
- **Resource mutation**: `ResourceStore.create` / `update` / `remove`

### Common Issues
- **GUI not updating**: Run `clear classes` before launching
- **Solver failures**: Check drawer for exit flags/messages
- **Locked cases not honored**: Verify `DrawerController.extractLockedCaseAssignments()` returns correct labs
- **Resource panel not refreshing**: Check `onResourceStoreChanged` listener is firing
- **FormStateManager buttons not enabling**: Verify `setPristineValues` called after loading data

## See Also
- `docs/Architecture-Overview.md` – System architecture and design patterns
- `README.md` – Project overview and feature highlights
- `NOTES.md` – Recent changes and usage examples
