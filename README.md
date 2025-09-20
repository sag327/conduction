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
