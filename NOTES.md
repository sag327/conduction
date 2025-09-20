# Project Notes

## Branches
- `main`: includes visualization refactor and scheduling framework merged from `visualization-scripts`.
- `scheduleOptimization`: current working branch for daily schedule optimization workflow.

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
- Added conduction.batch.Optimizer to iterate over ScheduleCollection daily schedules.
- Supports parallel execution (set 'Parallel', true) with automatic filtering of days missing procedure durations.
