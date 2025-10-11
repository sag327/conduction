Architecture Overview

Purpose
- Provide a concise map of the GUI codebase so contributors can navigate quickly.

Layers
- App Shell: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
  - Creates the figure and top-level layouts
  - Wires UI controls and forwards events
  - Holds references to controllers and app-wide state
- Controllers: `scripts/+conduction/+gui/+controllers/`
  - `ScheduleRenderer`: schedule drawing, NOW line drag, analytics refresh
  - `OptimizationController`: options management, execute, status UI updates
  - `DrawerController`: drawer UI content, histogram, locks
  - `CaseManager`: case list, current time, completed archive, operators/procedures
  - `TestingModeController`, `DurationSelector`, `CaseStatusController`
- View Helpers: `scripts/+conduction/+gui/+app/`
  - Tab layouts and section builders (date, case details, constraints, cases table, optimization tab)
  - Drawer builder and testing panel builder
  - Available lab checkbox utilities and analytics tab renderer
- Sessions: `scripts/+conduction/+session/`
  - Serialize/deserialize daily schedules, cases, and operator colors

Key Data Structures
- `conduction.DailySchedule`: date + lab assignments
- `conduction.gui.models.ProspectiveCase`: persistent `CaseId` + status fields

Rendering Flow
1) `OptimizationController.executeOptimization` computes `dailySchedule`
2) `ScheduleRenderer.renderOptimizedSchedule` calls `visualizeDailySchedule`
3) Drawer and KPI bar updated; NOW line bound if Time Control is ON

Time Control
- ON: `app.IsTimeControlActive = true`, `CaseManager.setCurrentTime(start)`
- NOW drag end: `ScheduleRenderer.updateCaseStatusesByTime(app, minutes)`
  - Updates `ProspectiveCase.CaseStatus` and builds `app.SimulatedSchedule`
  - Re-renders using the simulated schedule

Conventions
- Keep `ProspectiveSchedulerApp` thin; push logic into controllers / `+app`
- Use function-handle callbacks in helpers (not `createCallbackFcn`)
- Use `CaseId` for lookups via `CaseManager.findCaseById`

