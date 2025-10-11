# Prospective Scheduler GUI

An interactive MATLAB GUI for adding and managing prospective surgical cases, optimising the day, and analysing outcomes.

## Quick Start

```matlab
% Launch with default settings (tomorrow's date, no historical data)
app = conduction.launchSchedulerGUI();

% Launch with historical data for operator/procedure options
app = conduction.launchSchedulerGUI(datetime('2025-01-15'), 'clinicalData/procedures.xlsx');

% Try the demo with sample data
conduction.gui.demoSchedulerGUI();
```

## Features

- Case input form with operator/procedure lists (historical‑data aware)
- Duration selector (median/P70/P90/custom) with mini histogram
- Case table with selection, removal, and persistent IDs
- Optimisation controls and status, KPI bar, and analyse tab
- Drawer inspector for case details, solver diagnostics, and history plot
- Save/Load sessions with auto‑save rotation
- Time Control mode with draggable NOW line (simulated status updates)

## Architecture

```
scripts/+conduction/+gui/
├── ProspectiveSchedulerApp.m           # Thin app shell (wiring + forwards)
├── launchSchedulerGUI.m                # Launch function
├── demoSchedulerGUI.m                  # Sample data demo
├── +controllers/                       # Logic modules
│   ├── ScheduleRenderer.m              # Schedule drawing + NOW drag
│   ├── OptimizationController.m        # Options, execute, status
│   ├── DrawerController.m              # Drawer and lock toggling
│   ├── CaseManager.m                   # Case CRUD, current time, archive
│   ├── TestingModeController.m         # Testing dataset support
│   ├── DurationSelector.m              # Duration option logic
│   └── CaseStatusController.m          # Status helpers
└── +app/                               # View helpers
    ├── buildDateSection.m              # Add/Edit tab sections
    ├── buildCaseDetailsSection.m
    ├── buildConstraintSection.m
    ├── buildCaseManagementSection.m    # Cases tab
    ├── buildOptimizationTab.m          # Optimization tab controls
    ├── +drawer/buildDrawerUI.m         # Drawer UI
    └── +testingMode/buildTestingPanel.m
```

## GUI Layout

```
┌─────────────────────┬─────────────────────────────────────┐
│ Clinical Data       │           Schedule View             │
│ [Load Data File...] │                                     │
│ Status: 23 ops, 8 procs        (Coming in Phase 2)             │
│                     │                                     │
│ Add New Case        │  • Timeline visualization           │
│ Operator: [Dr. A ▼] │  • Lab assignments                  │
│ Procedure:[PCI  ▼]  │  • Optimization metrics             │
│ Duration: [90] min (from 12 cases) • Real-time updates                │
│                     │                                     │
│ [Add Case]          │                                     │
│                     │                                     │
├─────────────────────┤                                     │
│   Added Cases       │                                     │
│                     │                                     │
│ ┌─── Cases Table ──┐│                                     │
│ │Dr.A - PCI - 90m  ││                                     │
│ │Dr.B - Ablation   ││                                     │
│ └─────────────────────┘                                     │
│ [Remove] [Clear All]│                                     │
└─────────────────────┴─────────────────────────────────────┘
```

## Usage Examples

### Basic Usage
```matlab
% Launch GUI
app = conduction.launchSchedulerGUI();

% Add cases through the GUI interface:
% 1. Select operator from dropdown
% 2. Select procedure from dropdown
% 3. Adjust duration if needed
% 4. Click "Add Case"
```

### With Historical Data
```matlab
% Load historical data for smart suggestions
app = conduction.launchSchedulerGUI(datetime('2025-01-15'), 'clinicalData/procedures.xlsx');

% GUI will populate dropdowns with known operators/procedures
% Duration estimates will use operator-specific historical statistics
% Shows "Duration: [125] min (from 8 cases)" for data-driven estimates

% Alternative: Load data interactively through GUI
app = conduction.launchSchedulerGUI();
% Then click "Load Data File..." button to select clinical data
```

### Clinical Data Integration Features
```matlab
% After loading clinical data, the GUI provides:
% • Operator-specific procedure duration estimates
% • Historical case counts for reliability assessment
% • Visual indicators showing data source (historical vs estimated vs default)
% • Automatic fallback to procedure averages when operator-specific data unavailable
```

### Programmatic Case Access
```matlab
% Get reference to case manager
caseManager = app.CaseManager;

% Check current case count
fprintf('Current cases: %d\n', caseManager.CaseCount);

% Access individual cases
for i = 1:caseManager.CaseCount
    case = caseManager.getCase(i);
    fprintf('%s - %s (%d min)\n', case.OperatorName, case.ProcedureName, case.EstimatedDurationMinutes);
end
```

## Integration Points

- Data models: `Operator`, `Procedure`, and `gui.models.ProspectiveCase`
- Schedules: `conduction.DailySchedule` for optimised and simulated states
- Visualisation: `conduction.visualizeDailySchedule` (schedule axes renderer)
- Sessions: `scripts/+conduction/+session/*` for save/load serde

## Development Notes

- Built using programmatic MATLAB UI components (no .mlapp file)
- App shell delegates to controllers and `+app` view helpers
- Helper‑built UI uses function handle callbacks (not `createCallbackFcn`)
- Time Control: NOW drag ends call `ScheduleRenderer.updateCaseStatusesByTime`
  - Simulated statuses applied to `ProspectiveCase.CaseStatus`
  - Completed cases remain in main list; `getCompletedCases()` is the archive for real completion

See also: `docs/ProspectiveSchedulerApp-Refactor-Plan.md`, `docs/TimeControl-Design.md`.
