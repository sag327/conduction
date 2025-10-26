# Project Notes

## Current Version
**v0.7.0** – Latest stable release with resource management, drag-and-drop reordering, and FormStateManager utilities

## Branches
- `main`: latest stable refactor (visualization + single-day optimizer + GUI + resources)
- Tag releases on `main` with semantic version numbers (`vMAJOR.MINOR.PATCH`) and update the root `VERSION` file alongside the tag
- Use `conduction.bumpVersion('patch'|'minor'|'major')` to automate the bump/commit/tag steps (add `'DryRun', true` to preview, `'Push', true` to push immediately)

## Recent Work (v0.7.0 and Later)
- **FormStateManager utility** (v0.7.0) – Reusable dirty state tracking for forms with Save/Reset buttons
  - Save/Reset buttons only enable when form has unsaved changes
  - Used in Resources tab for resource type editing
  - Pattern can be reused for other forms requiring dirty state tracking
- **Resource management system**
  - User-configurable resource types (name, capacity, color, default status)
  - Default resources automatically assigned to new cases
  - Visual resource legend with color-coded indicators
  - Resource capacity constraints enforced during optimization
  - Anesthesia resource created automatically on app initialization
- **Drag-and-drop case reordering**
  - Visual case resequencing on schedule canvas
  - Automatic overlap detection for locked cases
  - CaseDragController manages drag state and validation
- **Outpatient/Inpatient mode improvements**
  - Info button with explanation dialog
  - Clearer default status labels
- **Bug fixes**
  - Fixed false overlap detection for locked cases during re-optimization
  - Fixed default resources panel not updating when resources deleted
  - Improved first-case constraint validation

## Earlier Enhancements
- Added `conduction.DailySchedule` enhancements and adapters to store setup/procedure/post/turnover durations, priorities, lab preferences, and admission status
- Created modular scheduling pipeline under `+conduction/+scheduling` (options, preprocessing, ILP model builder, solver, assembler, orchestrator)
- Introduced `conduction.optimizeDailySchedule` (replacing `scheduleHistoricalCases`) as the public entry point
- Added `conduction.configureOptimization` helper for building option structs; optimizer stores used options in `outcome.options`
- Updated visualization to operate on `DailySchedule`, disambiguate operator labels, and simplify lab labels
- Session save/load with complete state persistence

## Usage Examples

### Launch GUI with Testing Mode
```matlab
% Basic launch
conduction.launchSchedulerGUI

% With historical data for Testing Mode
conduction.launchSchedulerGUI(datetime('2025-01-15'), 'clinicalData/exampleDataset.xlsx')
```

### Build Optimization Configuration
```matlab
config = conduction.configureOptimization( ...
    'NumLabs', 5, ...
    'LabStartTimes', {'08:00','08:00','08:00','08:00','08:00'}, ...
    'OptimizationMetric', 'operatorIdle', ...
    'TurnoverTime', 15, ...
    'PrioritizeOutpatient', true);

% Load historical day and optimize
dataset = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
daily = dataset.dailyScheduleForDate('2025-01-02');
[newSchedule, outcome] = conduction.optimizeDailySchedule(daily, config);
conduction.visualizeDailySchedule(newSchedule, 'Title', 'Rescheduled Jan 2, 2025');
```

### Batch Optimization Example
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
config = conduction.configureOptimization('OptimizationMetric', 'makespan');
batchResult = conduction.optimizeScheduleCollection(collection, config, 'Parallel', false, 'ShowProgress', true);

numDays = numel(batchResult.results) + numel(batchResult.failures);
fprintf('Days optimized: %d (failures: %d)\n', numDays, numel(batchResult.failures));
fprintf('Run metadata: version %s (%s) at %s UTC\n', ...
    batchResult.metadata.version.Version, ...
    batchResult.metadata.version.Commit, ...
    string(batchResult.metadata.generatedAt));

% batchResult.optimizedCollection is ready for analytics
summary = conduction.analytics.analyzeScheduleCollection(batchResult.optimizedCollection);
conduction.analytics.plotOperatorTurnovers(summary, 'Mode', 'aggregate');
```

## Analytics Usage

### Procedure Analytics
```matlab
addpath(genpath('scripts'));
dataset = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');

summary = conduction.analytics.runProcedureAnalysis(dataset);
keys = summary.procedures.keys;
firstProc = summary.procedures(keys{1});
fprintf('Procedure: %s (count=%d, mean=%.1f, median=%.1f)\n', ...
    firstProc.procedureName, firstProc.overall.count, ...
    firstProc.overall.mean, firstProc.overall.median);
```

### Schedule Collection Analysis
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
summary = conduction.analytics.analyzeScheduleCollection(collection);

procedureSummary = summary.procedureSummary;
keys = procedureSummary.procedures.keys;
firstProc = procedureSummary.procedures(keys{1});
fprintf('Procedure %s mean duration: %.1f minutes\n', ...
    firstProc.procedureName, firstProc.overall.mean);

dailySummary = summary.dailySummary;
fprintf('Average lab occupancy across days: %.1f%%\n', dailySummary.averageLabOccupancyMean*100);
```

### One-Line Daily Analysis
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
dailySchedule = collection.dailyScheduleForDate(datetime(2025,1,7));
result = conduction.analytics.analyzeDailySchedule(dailySchedule);
fprintf('Daily occupancy: %.1f%%\n', result.dailyMetrics.averageLabOccupancyRatio * 100);
dailyProcKeys = result.procedureMetrics.ProcedureMetrics.keys;
fprintf('Procedures analyzed: %d\n', numel(dailyProcKeys));
```

### Full Collection Analysis with Plotting
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
summary = conduction.analytics.analyzeScheduleCollection(collection);

fprintf('Days analyzed: %d\n', summary.count);
firstProcKey = summary.procedureSummary.procedures.keys{1};
firstProc = summary.procedureSummary.procedures(firstProcKey);
fprintf('Procedure %s mean: %.1f minutes\n', ...
    firstProc.procedureName, firstProc.overall.mean);

fprintf('Average lab occupancy mean: %.1f%%\n', summary.dailySummary.averageLabOccupancyMean * 100);
operatorKeys = summary.operatorSummary.operatorNames.keys;
firstOperator = operatorKeys{1};
fprintf('Operator %s total overtime: %.1f minutes (flip ratio %.2f)\n', ...
    summary.operatorSummary.operatorNames(firstOperator), ...
    summary.operatorSummary.operatorOvertimeMinutes(firstOperator), ...
    summary.operatorSummary.operatorFlipPerTurnoverRatio(firstOperator));

% Plotting example (requires the summary above)
conduction.analytics.plotOperatorTurnovers(summary);
% (Internally uses conduction.plotting.applyStandardStyle for consistent styling.)

% To plot collection-wide totals rather than medians:
conduction.analytics.plotOperatorTurnovers(summary, 'Mode', 'aggregate');
```

## GUI Architecture Notes

### Data Stores
- **CaseStore** – Manages ProspectiveCase collection, fires `CasesChanged` event on mutations
- **ResourceStore** – Manages ResourceType collection, fires `TypesChanged` event on mutations
- Both support batch updates to prevent redundant UI refreshes

### Controllers
- **ScheduleRenderer** – Schedule drawing, drag-and-drop, NOW line, analytics refresh
- **OptimizationController** – Options management, execution, status updates, batch update coordination
- **DrawerController** – Drawer UI content, case locks, solver diagnostics
- **CaseManager** – Case CRUD, current time tracking, completed archive
- **CaseDragController** – Drag-and-drop case reordering with overlap detection
- **TestingModeController** – Historical data loading and operator/procedure statistics
- **DurationSelector** – Duration field management
- **CaseStatusController** – Real-time case status tracking
- **AnalyticsRenderer** – Operator utilization charts

### Components
- **ResourceChecklist** – Multi-select resource assignment UI
- **CaseTableView** – Sortable, filterable case queue table with column sorting
- **ResourceLegend** – Visual resource indicators on schedule

### Utilities
- **FormStateManager** – Reusable dirty state tracking for forms with Save/Reset buttons
  - Attaches ValueChanged listeners to form fields
  - Enables/disables buttons based on hasChanges()
  - Can be reused for any form requiring Save/Reset pattern
- **Icons** – SVG icon rendering for UI buttons

### Design Patterns
- **Event-driven updates** – Stores fire events, app listens and refreshes UI
- **Batch update pattern** – `beginBatchUpdate()`/`endBatchUpdate()` to prevent redundant refreshes during multi-operation changes
- **Controller pattern** – Business logic separated into controllers, app shell stays thin
- **Builder pattern** – UI construction delegated to `+app` helpers that return components and bind callbacks
- **FormStateManager pattern** – Reusable dirty state tracking with automatic button enable/disable

## Next Steps / TODO
- Consider extending FormStateManager pattern to other forms if needed (e.g., case details, optimization options)
- Integrate optimization results into analytics pipeline for pre/post comparison
- Add tests comparing legacy vs. refactored schedules for regression safety
- Refine `DailySchedule` <-> `CaseRequest` bridge so typed objects feed the optimizer directly without interim structs

## Batch Optimization
- Added `conduction.batch.Optimizer` to iterate over `ScheduleCollection` daily schedules (sequential or `parfor`)
- Options via `conduction.batch.OptimizationOptions` (`Parallel`, `DateFilter`, `ShowProgress`, etc.)
- Progress output reports total days, per-day completion, and a summary of successes vs. skipped days
- `DailySchedule` now skips rows lacking procedure start/end timestamps, so days with incomplete data are omitted at ingest
- Each batch run returns `batchResult.metadata` containing the refactor version (from `conduction.version()`) and the UTC timestamp of the run; every `OptimizationResult` object carries the same metadata in its `Metadata` field
- `conduction.analytics.DailyAnalyzer` computes per-day metrics (case counts, average lab occupancy ratio = procedure minutes ÷ active window, makespan, lab idle minutes)
- `conduction.analytics.OperatorAnalyzer` returns `operatorMetrics` (per-operator idle/overtime/flip+idle ratios) and `departmentMetrics` (turnover samples, totals, aggregate ratios)
- `conduction.analytics.ProcedureAnalyzer` + `ProcedureMetricsAggregator` capture per-procedure samples and aggregate mean/median/P70/P90 durations for overall and per-operator views

## Testing Notes
- Save/load tests in `tests/save_load/` verify session persistence
- Run via CLI: `/Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"`
- Always `clear classes` before launching GUI after code changes to flush cached class definitions
