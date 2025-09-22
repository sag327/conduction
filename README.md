# EP Scheduling Refactor

## Overview
This repository tracks the refactor of a mature MATLAB workflow used to plan and analyze electrophysiology (EP) lab schedules. The legacy code in `oldScripts/` loads historical case data, rebuilds day-by-day lab schedules, optimizes future schedules with integer programming, and produces analytics on lab utilization, operator idle time, and procedure throughput. The goal of this project is to replace that MATLAB toolchain with a modern, modular implementation while preserving the validated behaviour and outputs.

## What the legacy MATLAB suite does
- **Data ingestion** – `loadHistoricalDataFromFile.m` reads historical procedure datasets and supporting lab metadata into rich MATLAB structures keyed by case, operator, and date.
- **Schedule reconstruction** – Utilities such as `reconstructHistoricalSchedule.m`, `getCasesByDate.m`, and `createHistoricalScheduleContainer` rebuild daily schedules so they can be analysed or used as baselines for optimization.
- **Optimization engine** – `optimizeDailySchedule.m` formulates an integer linear program to assign cases to labs, balance operator workloads, respect turnover times, and optionally prioritise outpatient cases.
- **Analysis & reporting** – `analyzeHistoricalData.m` and `analyzeStatisticalDataset.m` generate comprehensive metrics (idle time, lab flips, throughput, surgeon/operator stats) and can persist structured reports for downstream visualization.
- **Experiment automation** – Scripts such as `runSchedulingExperiment.m`, `configureExperiment.m`, and `batchProcessHistoricalCases.m` coordinate multi-day experiments, capture results, and write summaries into `.mat` files for further analysis.

Understanding these behaviours is the baseline for the refactor: each new module must accept the same inputs, produce comparable metrics, and support the same experiment flows.

## Repository layout
- `oldScripts/` – Reference MATLAB implementation to be dissected and rewritten.
- `clinicalData/` – Sample datasets, lab mappings, and historical experiment outputs the refactor will use for parity testing.
- `scripts/` – Placeholder for new refactored code (language/architecture to be defined as the project evolves). Legacy MATLAB scripts remain in the original project at `../epScheduling/scripts` and can be referenced via `addpath` when comparisons are needed.

## Refactor objectives
- Document and modularise the functional areas above before porting them into the new stack.
- Create automated tests and parity checks that compare refactored outputs to the MATLAB references.
- Gradually retire `oldScripts/` once feature coverage and validation thresholds are met.

As the refactor progresses, this README should be updated with implementation specifics, run instructions, and verification steps for the new codebase.

## Planned Object Model

- **Operator**: encapsulates provider identity, specialties, availability windows, and tracked performance metrics used by the optimizer and analytics.
- **Lab**: captures lab identity, capabilities, daily open/close windows, turnover policies, and equipment constraints.
- **Procedure**: describes procedure templates including expected setup/procedure/post durations, required lab capabilities, and operator qualifications.
- **CaseRequest**: represents a specific case drawn from historical or live demand, linking a procedure template to a date, patient class, and preferred operators.
- **DailyLabSchedule**: owns the timeline for a single lab-day, maintaining ordered case assignments, state transitions, and derived idle/turnover metrics.
- **ScheduleDay**: aggregates all `DailyLabSchedule` instances for a calendar day, ensuring inter-lab constraints (shared operators, resources) stay consistent.
- **ScheduleOptimizer**: strategy object that transforms a pool of `CaseRequest` instances into a `ScheduleDay` using chosen objective functions and solver backends.
- **ScheduleAnalyzer**: computes utilization, idle/turnover ratios, flip counts, and other KPIs, replacing the reporting logic in `analyzeHistoricalData.m`.
- **ScheduleCollection**: coordinates data ingestion/cleansing and exposes typed collections of operators, procedures, labs, and case requests for experiments.
- **ExperimentRunner**: orchestrates end-to-end scenarios (data load, optimization run, analytics, persistence) mirroring `runSchedulingExperiment.m`.
- **ParityValidator**: compares refactored outputs to MATLAB references to ensure behavioural fidelity during migration.

Future refactor tasks will map each MATLAB script or workflow to one or more of the classes above, enabling gradual porting while preserving validated behaviour.

### Optimization Configuration

Use `config = conduction.configureOptimization(...)` to build an options struct, then call:

```matlab
config = conduction.configureOptimization('NumLabs',5,'OptimizationMetric','operatorIdle');
[newDaily, outcome] = conduction.optimizeDailySchedule(oldDaily, config);
```

### Batch Optimization

Use `conduction.ScheduleCollection.fromFile` to load a dataset and `conduction.batch.Optimizer` to run `optimizeDailySchedule` across each day. Example:

```matlab
collection = conduction.ScheduleCollection.fromFile('clinicalData/testProcedureDurations-7day.xlsx');
config = conduction.configureOptimization('NumLabs',5,'OptimizationMetric','operatorIdle');
batchOptions = conduction.batch.OptimizationOptions.fromArgs('SchedulingConfig', config, 'Parallel', true);
optimizer = conduction.batch.Optimizer(batchOptions);
batchResult = optimizer.run(collection);
```

`batchResult.results` is an array of `OptimizationResult` objects; `batchResult.failures` lists any days skipped prior to optimization. Progress messages show the number of days processed, which dates were skipped for missing procedure timestamps, and a final success/skip summary.

### Analytics

- Legacy vs. Refactor note: The refactored analyzers drop cases that are missing procedure start/end timestamps or lab assignments. Legacy scripts counted those rows when estimating turnovers, which tends to inflate the turnover denominator and lower flip-per-turnover ratios. Expect conduction’s aggregate ratios to be slightly higher (more accurate) in data sets with incomplete clinical rows.

- `conduction.analytics.DailyAnalyzer.analyze(dailySchedule)` produces per-day metrics (case counts, average lab occupancy ratio = procedure minutes ÷ active window) and lab idle minutes.
- `conduction.analytics.OperatorAnalyzer.analyze(dailySchedule)` returns `operatorMetrics` (per-operator idle, overtime, flip/idle ratios) and `departmentMetrics` (turnover samples, totals, aggregate ratios).
- `conduction.analytics.ProcedureAnalyzer.analyze(dailySchedule)` captures raw procedure duration samples per procedure and per operator; pair it with `conduction.analytics.ProcedureMetricsAggregator` to accumulate days and compute mean/median/P70/P90 statistics.
- `conduction.analytics.ScheduleCollectionAnalyzer.run(schedules)` orchestrates analyzers across many days; by default it produces `procedureMetrics` via the procedure aggregator, and you can register additional analyzers as needed.
- `conduction.analytics.runProcedureAnalysis(collection)` wraps the collection analyzer for the common case of aggregating procedure metrics across an entire dataset.
- `conduction.analytics.analyzeDailySchedule(dailySchedule)` bundles all per-day analyzers into a single call, returning daily/operator/procedure results.
- `conduction.analytics.analyzeScheduleCollection(collection)` iterates every day in a schedule collection (or array of schedules) and returns consolidated procedure, operator (including per-operator turnover ratios), and daily summaries.
- `conduction.analytics.plotOperatorTurnovers(summary, 'Mode', mode)` plots idle/flip per turnover for each operator using the summary returned by `analyzeScheduleCollection`; use `Mode='median'` (default) or `'aggregate'` to switch between day medians and overall collection percentages.
- `conduction.plotting.applyStandardStyle(fig, axes, ...)` applies the standard white background / black text styling used by all analytics plots.
- `conduction.optimizeScheduleCollection(collection, config, ...)` wraps the batch optimizer so you can optimize every day in a collection (or load from file) with a single call; `config` is the struct returned by `conduction.configureOptimization`. The result struct now includes `optimizedSchedules` (array of `DailySchedule`) and `optimizedCollection` (a `ScheduleCollection` view over those schedules) so you can pass the output straight into analytics.
