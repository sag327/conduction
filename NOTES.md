# Project Notes

## Branches
- `main`: latest stable refactor (visualization + single-day optimizer).
- `datasetOptimization`: current branch adding batch optimization across schedule collections.

## Recent Work
- Added `conduction.DailySchedule` enhancements and adapters to store setup/procedure/post/turnover durations, priorities, lab preferences, and admission status.
- Created modular scheduling pipeline under `+conduction/+scheduling` (options, preprocessing, ILP model builder, solver, assembler, orchestrator).
- Introduced `conduction.optimizeDailySchedule` (replacing `scheduleHistoricalCases`) as the public entry point.
- Added `conduction.configureOptimization` helper for building option structs; optimizer stores used options in `outcome.options`.
- Updated visualization to operate on `DailySchedule`, disambiguate operator labels, and simplify lab labels.

## Usage Examples
```matlab
% Build configuration
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

## Next Steps / TODO
- Integrate optimization results into analytics pipeline once shared metrics module exists.
- Add tests comparing legacy vs. refactored schedules for regression safety.
- Refine `DailySchedule` <-> `CaseRequest` bridge so typed objects feed the optimizer directly without interim structs.

## Batch Optimization
- Added `conduction.batch.Optimizer` to iterate over `ScheduleCollection` daily schedules (sequential or `parfor`).
- Options via `conduction.batch.OptimizationOptions` (`Parallel`, `DateFilter`, `ShowProgress`, etc.).
- Progress output reports total days, per-day completion, and a summary of successes vs. skipped days.
- `DailySchedule` now skips rows lacking procedure start/end timestamps, so days with incomplete data are omitted at ingest.
- `conduction.analytics.DailyAnalyzer` computes per-day metrics (case counts, average lab occupancy ratio = procedure minutes ÷ active window, makespan, lab idle minutes).
- `conduction.analytics.OperatorAnalyzer` returns `operatorMetrics` (per-operator idle/overtime/flip+idle ratios) and `departmentMetrics` (turnover samples, totals, aggregate ratios).
- `conduction.analytics.ProcedureAnalyzer` + `ProcedureMetricsAggregator` capture per-procedure samples and aggregate mean/median/P70/P90 durations for overall and per-operator views.

### Procedure Analytics Usage
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

### Schedule Collection Analyzer Usage
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

### One-Line Collection Analysis
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
summary = conduction.analytics.analyzeScheduleCollection(collection);

fprintf('Days analyzed: %d\n', summary.count);
fprintf('Average lab occupancy mean: %.1f%%\n', summary.dailySummary.averageLabOccupancyMean * 100);
firstKey = summary.procedureSummary.procedures.keys{1};
firstProc = summary.procedureSummary.procedures(firstKey);
fprintf('Procedure %s median: %.1f minutes\n', firstProc.procedureName, firstProc.overall.median);
```

### Inspecting Procedure Names in a DailySchedule
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
dailySchedule = collection.dailyScheduleForDate(datetime(2025,1,7));
cases = dailySchedule.cases();
procNames = unique(string({cases.procedureName}));
procIds = unique(string({cases.procedureId}));
table(procIds', procNames', 'VariableNames', {'ProcedureId', 'ProcedureName'})
```

### Full Collection Analysis
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
```

### Batch Optimization Example
```matlab
addpath(genpath('scripts'));
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
config = conduction.configureOptimization('OptimizationMetric', 'makespan');
batchResult = conduction.optimizeScheduleCollection(collection, config, 'Parallel', false, 'ShowProgress', true);

numDays = numel(batchResult.results) + numel(batchResult.failures);
fprintf('Days optimized: %d (failures: %d)\n', numDays, numel(batchResult.failures));

% batchResult.optimizedCollection is ready for analytics
summary = conduction.analytics.analyzeScheduleCollection(batchResult.optimizedCollection);
conduction.analytics.plotOperatorTurnovers(summary, 'Mode', 'aggregate');
```
