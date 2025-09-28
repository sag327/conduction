# Prospective Scheduler GUI

An interactive MATLAB GUI for adding and managing prospective surgical cases before optimization.

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

### ✅ **Implemented (Phase 1)**
- **Case Input Form**: Dropdown menus for operators and procedures
- **Clinical Data Loading**: Interactive file picker or programmatic loading of historical datasets
- **Smart Duration Estimation**: Uses operator-specific procedure statistics from clinical data
- **Statistical Integration**: Shows historical case counts and data sources for duration estimates
- **Custom Entries**: "Other..." option for unlisted operators/procedures
- **Case Management Table**: View, edit, and remove added cases
- **Historical Analytics Integration**: Leverages existing procedure analytics for accurate estimates
- **Input Validation**: Prevents invalid case entries
- **Progress Indicators**: Loading status and data validation feedback

### 🚧 **Coming Next (Phase 2)**
- **Real-time Schedule Optimization**: Integration with existing optimization pipeline
- **Timeline Visualization**: Gantt chart showing lab assignments and case schedules
- **Optimization Metrics Display**: Live updates of makespan, utilization, idle time
- **Schedule Export**: Save prospective schedules for further analysis

## Architecture

```
+conduction/+gui/
├── ProspectiveSchedulerApp.m          # Main GUI (MATLAB App Designer style)
├── launchSchedulerGUI.m               # Launch function
├── demoSchedulerGUI.m                 # Demo with sample data
├── +models/
│   └── ProspectiveCase.m              # Case data model
└── +controllers/
    └── CaseManager.m                  # Business logic for case management
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

The GUI is designed to integrate seamlessly with the existing conduction framework:

- **Data Models**: Uses existing `Operator` and `Procedure` classes
- **Historical Data**: Loads from `ScheduleCollection` format
- **Future Integration**: `CaseManager.Cases` can be converted to `CaseRequest` objects for optimization

## Development Notes

- Built using programmatic MATLAB GUI components (no .mlapp file needed)
- Follows MVC pattern: GUI (View) → CaseManager (Controller) → ProspectiveCase (Model)
- Extensible design for adding optimization integration
- Event-driven updates using callback system