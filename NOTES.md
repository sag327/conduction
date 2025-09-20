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
- `conduction.analytics.DailyAnalyzer` computes per-day metrics (case counts, lab utilization, makespan, operator idle/overtime).
