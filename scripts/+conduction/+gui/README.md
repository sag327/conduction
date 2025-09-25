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
- **Smart Duration Estimation**: Automatic duration suggestions based on procedure type
- **Custom Entries**: "Other..." option for unlisted operators/procedures
- **Case Management Table**: View, edit, and remove added cases
- **Historical Data Integration**: Loads known operators/procedures from ScheduleCollection
- **Input Validation**: Prevents invalid case entries

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
│   Case Input        │           Schedule View             │
│                     │                                     │
│ Operator: [Dr. A ▼] │     (Coming in Phase 2)             │
│ Procedure:[PCI  ▼]  │                                     │
│ Duration: [90] min  │  • Timeline visualization           │
│                     │  • Lab assignments                  │
│ [Add Case]          │  • Optimization metrics             │
│                     │  • Real-time updates                │
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
collection = conduction.ScheduleCollection.fromFile('data.xlsx');
app = conduction.launchSchedulerGUI(datetime('2025-01-15'), collection);

% GUI will populate dropdowns with known operators/procedures
% Duration estimates will be based on historical averages
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