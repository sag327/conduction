# Conduction

Conduction is a MATLAB toolbox for scheduling and analysing electrophysiology (EP) lab activity. It combines an interactive GUI for prospective planning with a composable optimisation and analytics library that can be scripted for batch experimentation.

## Feature Highlights
- **Prospective Scheduler GUI** – Build a day-of-surgery plan, optimise with ILP, and inspect results without leaving MATLAB.
- **Right‑hand case inspector** – Click any schedule block to view detailed timing, lab assignment, and solver diagnostics in a slide‑in drawer.
- **Analyze tab** – Switch to the utilisation view to plot operator procedure, idle, and overtime hours for the optimised day.
- **Configurable optimisation engine** – Tune lab counts, turnover/setup/post durations, objective metrics, admission defaults, and filtering straight from the UI (or scripts).
- **Rich analytics** – Daily and operator analysers expose KPIs (idle time, flips, makespan, utilisation ratios) for GUI display or downstream reporting.
- **Dark‑mode visualisation** – `conduction.visualizeDailySchedule` supports embedding into existing axes (used by the GUI) or standalone figure generation.

## Requirements
- MATLAB R2023b or newer (tested on R2024a).
- Optimization Toolbox (required by the ILP scheduler).
- Access to the project root on the MATLAB path.

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

### Layout
- **Left column** – Case creation (Add/Edit), queue management (Cases tab), and optimisation parameters.
- **Top bar** – Date picker, optimisation trigger, testing toggle, and undo placeholder.
- **Center canvas** – Two-tab control with:
  - **Schedule** tab: the optimised day rendered by `visualizeDailySchedule`.
  - **Analyze** tab: operator utilisation bar chart (procedure, idle, overtime hours).
- **Drawer inspector** – Click any schedule block to reveal case, timing, lab assignment, and solver logs.
- **KPI footer** – Live metrics for case count, last-out, operator idle, lab idle, and flip ratio.

### Typical Workflow
1. Load historical/clinical data (optional) to seed procedure statistics.
2. Add prospective cases (operator, procedure, duration selection, constraints).
3. Adjust optimisation options (labs, turnover, objective metric, admission defaults).
4. Click **Optimize Schedule**.
5. Review the **Schedule** tab; click blocks to inspect details in the drawer.
6. Switch to **Analyze** to compare operator utilisation.
7. Iterate on options or case mix as needed.

### Drawer Tips
- Case drawer opens automatically on schedule block click and animates closed via the **Close** button or when a new optimisation is required.
- Diagnostics include objective value, exit flags, and solver messages (two-phase runs are summarised per phase).

## Command-Line Usage

### Optimise a Single Day Programmatically
```matlab
% Prepare cases (struct array with required optimisation fields)
cases = conduction.examples.sampleCases();   % replace with your loader

% Configure scheduling options
options = conduction.scheduling.SchedulingOptions.fromArgs( ...
    'NumLabs', 4, ...
    'TurnoverTime', 25, ...
    'OptimizationMetric', "operatorIdle", ...
    'PrioritizeOutpatient', true);

% Run the optimiser
[dailySchedule, outcome] = conduction.optimizeDailySchedule(cases, options);

% Visualise and inspect
conduction.visualizeDailySchedule(dailySchedule, 'Title', 'Prospective Plan');
disp(outcome.objectiveValue);
```

### Run Analytics on an Optimised Day
```matlab
metrics = conduction.analytics.DailyAnalyzer.analyze(dailySchedule);
operator = conduction.analytics.OperatorAnalyzer.analyze(dailySchedule);

fprintf('Cases: %d\n', metrics.caseCount);
lastOutMinutes = metrics.lastCaseEnd;
fprintf('Last case ends at: %02d:%02d\n', floor(lastOutMinutes/60), mod(round(lastOutMinutes), 60));
fprintf('Total operator idle minutes: %.1f\n', operator.departmentMetrics.totalOperatorIdleMinutes);
```

### Batch Optimisation Across a Collection
```matlab
collection = conduction.ScheduleCollection.fromFile('clinicalData/exampleDataset.mat');
batchOptions = conduction.configureOptimization('NumLabs', 5, 'TurnoverTime', 30);
optimizer = conduction.batch.Optimizer(collection, 'SchedulingOptions', batchOptions);
results = optimizer.run();

summaryTable = results.toTable();
head(summaryTable)
```

## Directory Layout
- `scripts/+conduction/+gui/` – App Designer implementation, controllers, and GUI helpers.
- `scripts/+conduction/+analytics/` – Daily and operator analyzers, KPI utilities.
- `scripts/+conduction/+scheduling/` – ILP scheduler, preprocessing, and result assembly.
- `scripts/+conduction/+plotting/` – Shared plotting utilities and operator trend charts.
- `scripts/+conduction/batch/` – Batch optimisation workflows.
- `clinicalData/` – Sample datasets for testing and regression comparisons.

## Versioning
- Project version is tracked in the root `VERSION` file and surfaced via `conduction.version()`.
- Releases are tagged on `main` (`vMAJOR.MINOR.PATCH`); the latest is **v0.2.1** (drawer inspector + analyse tab).

## Contributing
1. Create a feature branch from `main`.
2. Make changes, add targeted tests or examples.
3. Run the GUI smoke test and relevant analytics scripts.
4. Open a pull request; prefer squash merges for concise history.

## Support & Troubleshooting
- **GUI does not update after code changes** – Run `clear classes` before relaunching the app to flush cached class definitions.
- **Optimiser failures** – Check the drawer log for solver messages; ensure the Optimization Toolbox is licensed and cases include required fields (`operator`, `procTime`, etc.).
- **Dark-mode readability** – All embedded axes (schedule and analyse tabs) adopt a black background with light labels; if you embed visuals elsewhere, reuse the provided plotting helpers.

For additional examples or questions, open an issue or contact the maintainers.

## Testing and Developer Notes

### Run Save/Load Tests in CLI MATLAB

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('$(pwd)'); addpath(genpath('tests')); results = runtests('tests/save_load'); disp(results); exit(~all([results.Passed]));"
```

### Architecture At A Glance

- App shell: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
- Controllers: `scripts/+conduction/+gui/+controllers/` (renderer, optimization, drawer, testing, duration, case status)
- View helpers: `scripts/+conduction/+gui/+app/` (tab layouts, drawer UI, testing panel, available labs, analytics tab)
- Session serde: `scripts/+conduction/+session/`

Design notes:
- Helper-built UI binds callbacks using function handles (not `createCallbackFcn`) so builders can live outside the app class.
- Time Control uses a NOW line; drag end triggers `ScheduleRenderer.updateCaseStatusesByTime` and re-renders with `app.SimulatedSchedule`.
- Completed archive vs simulated status: `CaseManager.getCompletedCases()` is persistent; simulated completion is reflected via `ProspectiveCase.CaseStatus == "completed"`.

See also: `docs/Architecture-Overview.md`, `docs/TimeControl-Design.md`, `docs/Developer-Quickstart.md`.
