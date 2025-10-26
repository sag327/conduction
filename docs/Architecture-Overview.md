# Architecture Overview

## Purpose
Provide a concise map of the GUI codebase so contributors can navigate quickly and understand the system architecture.

## High-Level Architecture

### Layers
1. **App Shell** – `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
   - Creates the figure and top-level layouts
   - Wires UI controls and forwards events to controllers
   - Holds references to controllers, stores, and app-wide state
   - Manages session save/load

2. **Controllers** – `scripts/+conduction/+gui/+controllers/`
   - Encapsulate business logic and coordinate between app and stores
   - Accept `app` as first parameter
   - Examples: ScheduleRenderer, OptimizationController, DrawerController, CaseManager

3. **Stores** – `scripts/+conduction/+gui/+stores/`
   - Manage domain data with event notifications
   - Fire events on mutations (`CasesChanged`, `TypesChanged`)
   - Support batch updates to prevent redundant UI refreshes

4. **Components** – `scripts/+conduction/+gui/+components/`
   - Reusable UI widgets with encapsulated behavior
   - Examples: ResourceChecklist, CaseTableView, ResourceLegend

5. **View Helpers** – `scripts/+conduction/+gui/+app/`
   - Tab layouts and section builders
   - Return UI components and bind callbacks using function handles
   - Examples: buildCaseDetailsSection, buildResourcesTab, drawer builders

6. **Utilities** – `scripts/+conduction/+gui/+utils/`
   - Shared helper classes
   - FormStateManager for dirty state tracking
   - Icons for SVG rendering

7. **Sessions** – `scripts/+conduction/+session/`
   - Serialize/deserialize app state for save/load
   - Handles DailySchedule, ProspectiveCase, OperatorColors, ResourceTypes

## Key Controllers

### ScheduleRenderer
**Purpose**: Manage schedule visualization and interactions

**Responsibilities**:
- Render optimized schedule using `visualizeDailySchedule`
- Handle drag-and-drop case reordering
- Manage NOW line (Time Control)
- Update case statuses by time
- Refresh resource highlights

**Key Methods**:
- `renderOptimizedSchedule(app, schedule, outcome)`
- `enableDragAndDrop(app)` / `disableDragAndDrop(app)`
- `updateCaseStatusesByTime(app, currentMinutes)`

### OptimizationController
**Purpose**: Manage optimization configuration and execution

**Responsibilities**:
- Build scheduling options from UI state
- Execute `conduction.optimizeDailySchedule`
- Update optimization status and action availability
- Coordinate batch updates with CaseStore
- Handle locked case constraints

**Key Methods**:
- `executeOptimization(app)`
- `updateOptimizationOptionsSummary(app)`
- `buildSchedulingOptions(app)`
- `beginBatchUpdate()` / `endBatchUpdate(app)`

### DrawerController
**Purpose**: Manage case inspector drawer

**Responsibilities**:
- Populate drawer with case details
- Display timing breakdowns
- Show assigned resources
- Present solver diagnostics
- Handle case locks

**Key Methods**:
- `populateDrawer(app, caseId)`
- `extractLockedCaseAssignments(app)`
- `gatherSolverMessages(app)`

### CaseManager
**Purpose**: Central case lifecycle management

**Responsibilities**:
- CRUD operations for ProspectiveCase instances
- Track current time for Time Control
- Maintain completed case archive
- Build optimization case structs
- Manage operator and procedure lists

**Key Methods**:
- `createCase(...)` / `updateCase(...)` / `deleteCase(...)`
- `buildOptimizationCases()`
- `setCurrentTime(minutes)` / `getCurrentTime()`
- `getCompletedCases()`

### CaseDragController
**Purpose**: Handle drag-and-drop case reordering

**Responsibilities**:
- Validate drag operations
- Detect overlaps with locked cases
- Update case sequence after successful drops
- Trigger re-optimization

**Key Methods**:
- `onDragStart(app, caseId)`
- `onDragEnd(app, caseId, newStartMinutes)`
- `detectOverlaps(app, caseId, proposedStart, proposedEnd)`

## Key Data Structures

### Stores

#### CaseStore
- Manages collection of `ProspectiveCase` instances
- Fires `CasesChanged` event on create/update/delete
- Supports batch updates via `beginBatchUpdate()` / `endBatchUpdate()`
- Provides filtering and counting utilities

#### ResourceStore
- Manages collection of `ResourceType` instances
- Fires `TypesChanged` event on create/update/delete
- Tracks resource capacities and default status
- Auto-assigns colors from palette

### Models

#### ProspectiveCase
**Path**: `scripts/+conduction/+gui/+models/ProspectiveCase.m`

**Key Properties**:
- `CaseId` (string) – Unique persistent identifier
- `Operator`, `Procedure`, `AdmissionType`
- `SetupMinutes`, `ProcedureMinutes`, `PostMinutes`
- `ResourceIds` (string array) – Assigned resources
- `CaseStatus` (string) – pending, in_progress, completed
- `MustGoFirst`, `PreferredLab`

#### ResourceType
**Path**: `scripts/+conduction/+gui/+models/ResourceType.m`

**Key Properties**:
- `Id` (string) – Unique identifier
- `Name` (string) – Display name
- `Capacity` (double) – Maximum concurrent usage
- `Color` (1×3 double) – RGB color for visuals
- `IsDefault` (logical) – Auto-assign to new cases

### DailySchedule
**Path**: `scripts/+conduction/DailySchedule.m`

- Encapsulates date + lab assignments
- Used by optimizer and visualization
- Supports resource constraints

## Rendering Flow

1. **Optimization Triggered**
   - User clicks "Optimize Schedule" button
   - `ProspectiveSchedulerApp.OptimizationRunButtonPushed` → `OptimizationController.executeOptimization(app)`

2. **Case Preparation**
   - `CaseManager.buildOptimizationCases()` converts ProspectiveCases to optimizer struct format
   - Applies defaults, validates required fields

3. **Build Constraints**
   - `DrawerController.extractLockedCaseAssignments()` → locked lab assignments
   - `OptimizationController.buildLockedCaseConstraints()` → constraint struct

4. **Build Options**
   - `OptimizationController.buildSchedulingOptions(app)` reads UI state
   - Includes labs, turnover times, objective metric, admission defaults, first-case constraints

5. **Execute Optimization**
   - `conduction.optimizeDailySchedule(casesStruct, scheduleOptions, lockedConstraints)`
   - Returns `[dailySchedule, outcome]`

6. **Render Results**
   - `ScheduleRenderer.renderOptimizedSchedule(app, dailySchedule, outcome)`
   - Calls `conduction.visualizeDailySchedule` to draw Gantt chart
   - Updates drawer and KPI footer
   - Refreshes analytics tab if visible

7. **Post-Render**
   - Drawer content refreshed if case selected
   - Resource legend updated with highlights
   - Time Control NOW line re-attached if active

## Time Control System

### Activation
- **ON**: `app.IsTimeControlActive = true`
- `CaseManager.setCurrentTime(startMinutes)` initializes timeline
- NOW line appears on schedule

### NOW Line Drag
- `ScheduleRenderer.enableNowLineDrag(app)` attaches drag listeners
- `startDragNowLine(app)` → `updateNowLinePosition(app, newMinutes)` → `endDragNowLine(app)`
- On drop: `ScheduleRenderer.updateCaseStatusesByTime(app, currentMinutes)`
  - Updates `ProspectiveCase.CaseStatus` based on timeline position
  - Builds `app.SimulatedSchedule` with updated statuses
  - Re-renders using simulated schedule

### Status Tracking
- **Persistent archive**: `CaseManager.getCompletedCases()` stores truly completed cases
- **Simulated status**: Reflected in `ProspectiveCase.CaseStatus` during Time Control
- Simulated cases are NOT archived until Time Control is turned off and user confirms

## Event-Driven Updates

### Store Events
- **CaseStore** fires `CasesChanged` when cases mutate
  - App listens: `app.onCaseStoreChanged()`
  - Refreshes case table, updates optimization status

- **ResourceStore** fires `TypesChanged` when resources mutate
  - App listens: `app.onResourceStoreChanged()`
  - Refreshes resource table, legend, checklists, default panel

### Batch Updates
Pattern to prevent redundant UI refreshes during multi-operation changes:

```matlab
app.CaseStore.beginBatchUpdate();
app.OptimizationController.beginBatchUpdate();
try
    % Perform multiple operations
    app.CaseStore.createCase(...);
    app.CaseStore.createCase(...);
finally
    app.OptimizationController.endBatchUpdate(app);  % Triggers UI refresh once
    app.CaseStore.endBatchUpdate();  % Fires single event
end
```

## Design Conventions

### Controllers
- Keep `ProspectiveSchedulerApp` thin; push logic into controllers
- Controllers accept `app` as first parameter
- Use `CaseId` for lookups via `CaseManager.findCaseById(caseId)`

### UI Builders (View Helpers)
- Helper-built UI uses function handles (e.g., `@(src,evt) app.onButtonClick(evt)`)
- **Do NOT use `createCallbackFcn`** – keeps builders independent of app class
- Builders live in `+app` subpackages and return components

### Components
- Encapsulate UI widgets with behavior
- Provide public methods for external state updates
- Example: `ResourceChecklist.setSelection(resourceIds)`

### Utilities
- **FormStateManager** pattern for Save/Reset button state tracking
  - Attaches ValueChanged listeners to form fields
  - Automatically enables/disables buttons based on dirty state
  - Reusable across any form requiring Save/Reset pattern

## File Organization

```
scripts/+conduction/+gui/
├── ProspectiveSchedulerApp.m          # Main app shell
├── +controllers/
│   ├── ScheduleRenderer.m             # Schedule visuals, drag-drop, NOW line
│   ├── OptimizationController.m       # Optimization config & execution
│   ├── DrawerController.m             # Case inspector drawer
│   ├── CaseManager.m                  # Case lifecycle management
│   ├── CaseDragController.m           # Drag-and-drop reordering
│   ├── TestingModeController.m        # Historical data loading
│   ├── DurationSelector.m             # Duration field management
│   ├── CaseStatusController.m         # Real-time status tracking
│   └── AnalyticsRenderer.m            # Operator utilization charts
├── +stores/
│   ├── CaseStore.m                    # ProspectiveCase collection
│   └── ResourceStore.m                # ResourceType collection
├── +models/
│   ├── ProspectiveCase.m              # Case data model
│   └── ResourceType.m                 # Resource data model
├── +components/
│   ├── ResourceChecklist.m            # Multi-select resource UI
│   ├── CaseTableView.m                # Sortable case table
│   └── ResourceLegend.m               # Visual resource indicators
├── +utils/
│   ├── FormStateManager.m             # Dirty state tracking
│   └── Icons.m                        # SVG icon rendering
├── +app/                              # UI builders
│   ├── buildCaseDetailsSection.m
│   ├── buildResourcesTab.m
│   ├── renderAnalyticsTab.m
│   ├── +drawer/                       # Drawer UI builders
│   ├── +availableLabs/                # Lab selection utilities
│   └── ...
└── +session/                          # Save/load serializers
    ├── DailyScheduleSerializer.m
    ├── ProspectiveCaseSerializer.m
    └── ...
```

## Common Patterns

### Adding a New UI Control
1. Edit appropriate builder in `+app/` (e.g., `buildCaseDetailsSection.m`)
2. Bind callback using function handle: `control.ValueChangedFcn = @(~,~) app.onMyCallback()`
3. Implement callback in `ProspectiveSchedulerApp.m` or relevant controller

### Adding a New Controller
1. Create new class in `+controllers/` extending `handle`
2. Add controller property to `ProspectiveSchedulerApp.m`
3. Instantiate in app's `setupComponents` method
4. Wire up callbacks to controller methods

### Adding a New Store
1. Create new class in `+stores/` extending `handle`
2. Define events (e.g., `events; DataChanged; end`)
3. Fire events on mutations: `notify(obj, 'DataChanged')`
4. Add listener in app: `addlistener(app.MyStore, 'DataChanged', @(~,~) app.onMyStoreChanged())`

### Using FormStateManager
1. Create form fields (EditField, Spinner, etc.)
2. Create FormStateManager instance:
   ```matlab
   fields = {app.NameField, app.ValueSpinner};
   app.FormManager = conduction.gui.utils.FormStateManager(fields, saveButton, resetButton);
   ```
3. FormStateManager automatically:
   - Attaches ValueChanged listeners
   - Enables/disables buttons based on changes
4. Set pristine values when loading data:
   ```matlab
   app.FormManager.setPristineValues({'Name', 42});
   ```

## Testing Strategy
- Save/load tests in `tests/save_load/` verify session persistence
- Run via CLI for CI integration
- Always `clear classes` before GUI launch after code changes to flush cached definitions

## See Also
- `docs/Developer-Quickstart.md` – Common development tasks and workflows
- `README.md` – Project overview and feature highlights
- `NOTES.md` – Recent changes and usage examples
