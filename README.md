# Conduction

Conduction is a MATLAB toolbox for scheduling and analyzing electrophysiology (EP) lab activity. It combines an interactive GUI for prospective planning with a composable optimization and analytics library that can be scripted for batch experimentation.

## Feature Highlights

### Prospective Scheduler GUI
- **Interactive case management** – Add, edit, and manage prospective cases with operators, procedures, durations, and constraints
- **Four-tab workflow** – Add cases, review queue (Cases tab), configure resources, and tune optimization parameters
- **Drag-and-drop case reordering** – Re-sequence cases visually on the schedule with automatic overlap detection
- **Resource management** – Define custom resource types (e.g., Anesthesia, Equipment) with capacity limits and assign to cases
- **Right-hand case inspector** – Click any schedule block to view detailed timing, lab assignment, resource usage, and solver diagnostics in a slide-in drawer
- **Dual canvas tabs** – Switch between Schedule view (Gantt chart) and Analyze view (operator utilization bar charts)
- **Configurable optimization** – Tune lab counts, turnover/setup/post durations, objective metrics (operator idle, lab idle, makespan, operator overtime), admission defaults, and first‑case constraints directly in the UI
- **Unified timeline (NOW always visible)** – Case status is derived from the NOW position; no separate time‑control mode.
- **Smart Optimize button** – Context‑aware: “Optimize Schedule” (applies directly) when NOW is before first case; “Re‑optimize Remaining” (opens preview) when NOW is after first case.
- **Proposed tab (preview)** – Mid‑day re‑optimization shows a Proposed tab with frozen context before NOW. Accept, Discard, or Re‑run with scope options.
- **Re‑optimization scope controls** – Collapsible panel appears when NOW > first case (include unscheduled only vs future, respect locks, prefer current labs).
- **Per‑lab earliest‑start enforcement** – The optimizer cannot place new work before each lab’s earliest available minute (computed from NOW and frozen context). Future lab open/close times will feed this directly.
- **Session save/load** – Export and import complete sessions including cases, schedules, optimization results, and resource definitions
- **Testing mode** – Load historical clinical data to pre-populate operators, procedures, and statistics

### Resource System
- **Resource types** – Create and manage shared resources with custom names, capacities, and color coding
- **Default resources** – Mark resources as defaults to automatically assign them to new cases
- **Visual resource legend** – Highlight cases by resource assignment with color-coded indicators
- **Resource constraints in optimization** – Capacity limits enforced during scheduling

### Rich Analytics
- **Daily metrics** – Case counts, makespan, lab utilization ratios, idle time
- **Operator analysis** – Per-operator idle time, overtime, flip ratios, turnover statistics
- **Procedure analysis** – Mean, median, P70, P90 durations overall and per-operator
- **Batch optimization** – Run optimization across multiple days in a schedule collection
- **Collection-level analytics** – Aggregate statistics across date ranges

### Dark-Mode Visualization
- `conduction.visualizeDailySchedule` supports embedding into existing axes (used by the GUI) or standalone figure generation
- Consistent dark background with light labels across all charts

## Requirements
- MATLAB R2025a or newer (tested on R2025a)
- Optimization Toolbox (required by the ILP scheduler)
- Access to the project root on the MATLAB path

## Setup
1. Clone the repository and open MATLAB in the project root.
2. Add the `scripts` folder to the path (once per session):
   ```matlab
   addpath(genpath(fullfile(pwd, 'scripts')));
   ```
3. Optional: create a startup script or save the path for future sessions (`savepath`).

## Launching the GUI
```matlab
clear classes
conduction.launchSchedulerGUI
```

Or with historical data for Testing Mode:
```matlab
conduction.launchSchedulerGUI(datetime('2025-01-15'), 'clinicalData/exampleDataset.xlsx')
```

### GUI Layout
- **Left column (4 tabs)**:
  - **Add** – Create new cases with operator, procedure, duration, admission type, constraints, and resource assignments
  - **Cases** – Queue management table with edit/delete, undock to separate window
  - **Optimization** – Configure labs, turnover times, objective metric, admission defaults, first-case constraints
  - **Resources** – Define resource types, set capacities, mark defaults for new cases
- **Top bar** – Date picker, Save/Load Session buttons, optimization trigger, Testing Mode toggle
  - “Advance NOW to Actual” appears when NOW lags the clock; “Reset to Planning” appears when NOW advanced or manual completions exist.
- **Center canvas (2 tabs)**:
  - **Schedule** – Gantt chart rendered by `visualizeDailySchedule`, drag cases to reorder
  - **Analyze** – Operator utilization bar charts (procedure, idle, overtime hours)
- **Drawer inspector** – Click any schedule block to reveal case details, timing breakdown, lab assignment, resource usage, and solver logs
- **KPI footer** – Live metrics for case count, last-out time, operator idle, lab idle, and flip ratio

### Typical Workflow
1. **(Optional)** Load historical/clinical data via Testing Mode to seed operator/procedure statistics
2. **Add prospective cases** – Use Add tab to define cases with operators, procedures, durations, constraints
3. **Assign resources** – Select required resources (e.g., Anesthesia) for each case or set defaults in Resources tab
4. **Configure optimization** – Adjust labs available, turnover times, objective metric (operator idle, makespan, etc.)
5. **Click Optimize Schedule** – Run ILP solver (applies directly when NOW is before first case)
6. **Advance NOW during the day** – Drag NOW or click “Advance NOW to Actual”
7. **Click Re‑optimize Remaining** – Opens the Proposed tab (preview) when NOW is after first case; review summary chips and layout
8. **Accept / Discard / Re‑run** – Apply proposed changes, keep current schedule, or re‑run with adjusted scope
9. **Switch to Analyze tab** – Compare operator utilization
10. **Save session** – Export complete state for later resumption
11. **Iterate** – Modify cases, resources, or options as needed

### Drawer Inspector
- Opens automatically on schedule block click
- Displays case ID, operator, procedure, admission type, assigned lab
- Shows timing breakdown (setup, procedure, post, turnover)
- Lists assigned resources
- Provides solver diagnostics (objective value, exit flags, messages) for two-phase runs
- Lock button to freeze lab assignment for re-optimization

### Resource Management
- **Resources tab** – Create/edit/delete resource types
- **Details panel** – Name and capacity fields with Save/Reset buttons (enabled only when changes exist)
- **Default for New Cases** – Checkboxes to mark resources as defaults
- **Resource legend** – Visual indicators on schedule for resource-constrained cases
- **Capacity enforcement** – Optimization respects resource limits across concurrent cases

## Command-Line Usage

### Optimize a Single Day Programmatically
```matlab
% Prepare cases (struct array with required optimization fields)
cases = conduction.examples.sampleCases();   % replace with your loader

% Configure scheduling options
options = conduction.scheduling.SchedulingOptions.fromArgs( ...
    'NumLabs', 4, ...
    'TurnoverTime', 15, ...
    'OptimizationMetric', "operatorIdle", ...
    'PrioritizeOutpatient', true);

% Run the optimizer
[dailySchedule, outcome] = conduction.optimizeDailySchedule(cases, options);

% Visualize and inspect
conduction.visualizeDailySchedule(dailySchedule, 'Title', 'Prospective Plan');
disp(outcome.objectiveValue);
```

### Run Analytics on an Optimized Day
```matlab
metrics = conduction.analytics.DailyAnalyzer.analyze(dailySchedule);
operator = conduction.analytics.OperatorAnalyzer.analyze(dailySchedule);

fprintf('Cases: %d\n', metrics.caseCount);
lastOutMinutes = metrics.lastCaseEnd;
fprintf('Last case ends at: %02d:%02d\n', floor(lastOutMinutes/60), mod(round(lastOutMinutes), 60));
fprintf('Total operator idle minutes: %.1f\n', operator.departmentMetrics.totalOperatorIdleMinutes);
```

### Batch Optimization Across a Collection
```matlab
collection = conduction.ScheduleCollection.fromFile('clinicalData/exampleDataset.xlsx');
config = conduction.configureOptimization('NumLabs', 5, 'TurnoverTime', 15);
batchResult = conduction.optimizeScheduleCollection(collection, config, 'Parallel', false, 'ShowProgress', true);

% Analyze optimized collection
summary = conduction.analytics.analyzeScheduleCollection(batchResult.optimizedCollection);
conduction.analytics.plotOperatorTurnovers(summary);
```

## Directory Layout
- `scripts/+conduction/+gui/` – GUI implementation
  - `ProspectiveSchedulerApp.m` – Main app shell
  - `+controllers/` – Business logic (ScheduleRenderer, OptimizationController, DrawerController, CaseManager, etc.)
  - `+components/` – Reusable UI components (ResourceChecklist, CaseTableView, ResourceLegend)
  - `+stores/` – Data stores (CaseStore, ResourceStore)
  - `+models/` – Data models (ProspectiveCase, ResourceType)
  - `+utils/` – Utilities (FormStateManager, Icons)
  - `+app/` – UI builders for tabs, sections, and panels
  - `+session/` – Session save/load serializers
- `scripts/+conduction/+analytics/` – Daily, operator, and procedure analyzers, KPI utilities
- `scripts/+conduction/+scheduling/` – ILP scheduler, preprocessing, and result assembly
- `scripts/+conduction/+plotting/` – Shared plotting utilities and operator trend charts
- `scripts/+conduction/batch/` – Batch optimization workflows
- `clinicalData/` – Sample datasets for testing and regression comparisons
- `tests/` – Unit and integration tests
- `docs/` – Architecture and developer documentation

## Versioning
- Project version is tracked in the root `VERSION` file and surfaced via `conduction.version()`.
- Releases are tagged on `main` (`vMAJOR.MINOR.PATCH`); the latest is **v0.7.0**.
- Use `conduction.bumpVersion('patch'|'minor'|'major')` to automate the bump/commit/tag steps (add `'DryRun', true` to preview, `'Push', true` to push immediately).

## Contributing
1. Create a feature branch from `main`.
2. Make changes, add targeted tests or examples.
3. Run the GUI smoke test and relevant analytics scripts.
4. Open a pull request; prefer squash merges for concise history.

## Support & Troubleshooting
- **GUI does not update after code changes** – Run `clear classes` before relaunching the app to flush cached class definitions.
- **Optimizer failures** – Check the drawer log for solver messages; ensure the Optimization Toolbox is licensed and cases include required fields (`operator`, `procTime`, etc.).
- **Dark-mode readability** – All embedded axes (schedule and analyze tabs) adopt a black background with light labels; if you embed visuals elsewhere, reuse the provided plotting helpers.
- **Resource checkboxes not updating** – The Default Resources panel refreshes automatically when resources are created/deleted; if issues persist, check ResourceStore event listeners.

For additional examples or questions, open an issue or contact the maintainers.

## Testing and Developer Notes

### Run Save/Load Tests in CLI MATLAB

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"
```

### Architecture At A Glance

- **App shell**: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
- **Controllers**: `scripts/+conduction/+gui/+controllers/`
  - ScheduleRenderer – Schedule drawing, drag-and-drop, NOW line, analytics refresh
  - OptimizationController – Options management, execution, status updates
  - DrawerController – Drawer UI content, case locks, solver diagnostics
  - CaseManager – Case CRUD, current time tracking, completed archive
  - CaseDragController – Drag-and-drop case reordering with overlap detection
  - TestingModeController – Historical data loading and operator/procedure statistics
  - DurationSelector – Duration field management
  - CaseStatusController – Real-time case status tracking
  - AnalyticsRenderer – Operator utilization charts
- **Stores**: `scripts/+conduction/+gui/+stores/`
  - CaseStore – Manages ProspectiveCase collection with event notifications
  - ResourceStore – Manages ResourceType collection with capacity tracking
- **Components**: `scripts/+conduction/+gui/+components/`
  - ResourceChecklist – Multi-select resource assignment UI
  - CaseTableView – Sortable, filterable case queue table
  - ResourceLegend – Visual resource indicators on schedule
- **Utilities**: `scripts/+conduction/+gui/+utils/`
  - FormStateManager – Reusable dirty state tracking for Save/Reset buttons
  - Icons – SVG icon rendering for UI buttons
- **View helpers**: `scripts/+conduction/+gui/+app/` – Tab layouts, drawer UI, testing panel, available labs, analytics tab
- **Session serde**: `scripts/+conduction/+session/` – Save/load serializers for DailySchedule, ProspectiveCase, OperatorColors, ResourceTypes

**Design notes**:
- Helper-built UI binds callbacks using function handles (not `createCallbackFcn`) so builders can live outside the app class
- Controllers are instantiated in `ProspectiveSchedulerApp` and accept `app` as first parameter
- CaseStore and ResourceStore fire events (`CasesChanged`, `TypesChanged`) to trigger UI updates
- FormStateManager pattern enables reusable dirty state tracking for forms with Save/Reset buttons
- Time Control uses a NOW line; drag triggers `ScheduleRenderer.updateCaseStatusesByTime` and re-renders with `app.SimulatedSchedule`
- Completed archive vs simulated status: `CaseManager.getCompletedCases()` is persistent; simulated completion is reflected via `ProspectiveCase.CaseStatus == "completed"`

See also: `docs/Architecture-Overview.md`, `docs/Developer-Quickstart.md`.
