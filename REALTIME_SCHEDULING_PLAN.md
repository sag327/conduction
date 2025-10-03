# Real-Time Dynamic Scheduling - Implementation Plan

**Feature Branch**: `feature/realtime-scheduling`

**Goal**: Enable dynamic re-scheduling throughout the day as cases are completed and new add-on cases arrive

**Approach**: Hybrid Status + Time Window (combines case lifecycle tracking with time-aware constraints)

**Version**: 0.4.0 (target)

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Phase-by-Phase Implementation](#phase-by-phase-implementation)
4. [Data Model Changes](#data-model-changes)
5. [UI/UX Specifications](#uiux-specifications)
6. [Optimizer Modifications](#optimizer-modifications)
7. [File Change Inventory](#file-change-inventory)
8. [Testing Strategy](#testing-strategy)
9. [Future Enhancements](#future-enhancements)

---

## Overview

### Problem Statement
Currently, the scheduler optimizes cases at the beginning of the day, but cannot adapt to:
- Cases completing earlier or later than scheduled
- Add-on cases arriving throughout the day
- Labs becoming available at different times based on actual performance

### Solution Summary
Implement a **case status lifecycle** (Pending → InProgress → Completed) combined with **time window constraints** that respect the current time and actual case completion times.

### Key Principles
1. **Completed cases are immutable** - locked with actual times, excluded from re-optimization
2. **In-progress cases are respected** - locked at scheduled times, not disturbed
3. **Pending cases are flexible** - can be rescheduled based on current conditions
4. **Time flows forward** - no case can be scheduled before current time
5. **Labs freed dynamically** - availability updates as cases complete

### User Workflow
```
Morning:
1. Load all scheduled cases (outpatients + known inpatients)
2. Run initial optimization
3. All cases marked "Pending"

During the day:
4. Case about to start → Mark "InProgress" (auto-locks at scheduled time)
5. Case finishes → Mark "Completed", enter actual end time
6. New add-on case arrives → Add to pending pool
7. Click "Re-Optimize" → Only pending cases rescheduled
8. Repeat steps 4-7 throughout the day

End of day:
9. Export planned vs actual report
10. Review schedule adherence metrics
```

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────┐
│                   ProspectiveSchedulerApp                │
│  (Main GUI - orchestrates all components)                │
└────────────┬────────────────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼──────────┐  ┌──▼─────────────────┐
│ CaseManager  │  │ScheduleRenderer    │
│ + Status     │  │ + StatusIndicators │
│ + ActualTime │  │ + CurrentTimeLine  │
└───┬──────────┘  └──┬─────────────────┘
    │                │
    │            ┌───▼────────────────────┐
    │            │ CaseStatusController   │
    │            │ (NEW - manages status) │
    │            └───┬────────────────────┘
    │                │
┌───▼────────────────▼──────────────────────┐
│        OptimizationController             │
│  + Status-aware filtering                 │
│  + Time window constraints                │
│  + Lab availability tracking              │
└───────────────┬───────────────────────────┘
                │
    ┌───────────┴────────────┐
    │                        │
┌───▼──────────────┐  ┌─────▼─────────────┐
│SchedulingOptions │  │OptimizationModel  │
│ + CurrentTime    │  │Builder            │
│ + LabAvailability│  │ + TimeConstraints │
└──────────────────┘  └───────────────────┘
```

### Data Flow

**Re-optimization Flow**:
```
User clicks "Re-Optimize"
    ↓
CaseManager filters cases by status
    ↓
Pending cases → Optimizer
Completed cases → Locked constraints (excluded from variables)
InProgress cases → Locked constraints (at scheduled times)
    ↓
SchedulingOptions receives:
  - CurrentTime (e.g., 2:30 PM = 870 minutes)
  - LabAvailability Map (per-lab earliest start times)
    ↓
OptimizationModelBuilder adds:
  - Constraint: all case starts >= CurrentTime
  - Constraint: case in lab L starts >= LabAvailability[L]
    ↓
Solver optimizes ONLY pending cases
    ↓
ScheduleAssembler merges:
  - Completed cases (actual times)
  - InProgress cases (scheduled times)
  - Newly optimized pending cases
    ↓
Visualization shows:
  - Completed (blue, checkmark)
  - InProgress (yellow, pulsing)
  - Pending (gray, normal)
  - Current time (red vertical line)
```

---

## Phase-by-Phase Implementation

### Phase 1: Data Model Foundation
**Goal**: Add status tracking and actual time fields

#### 1.1 ProspectiveCase.m - Add Status Properties
```matlab
properties
    % Existing properties...

    % Real-time scheduling properties
    CaseStatus string = "pending"  % "pending", "in_progress", "completed"
    ActualStartTime double = NaN   % Actual setup start (minutes from midnight)
    ActualProcStartTime double = NaN
    ActualProcEndTime double = NaN
    ActualEndTime double = NaN     % Actual post completion time

    % Scheduled times (for comparison)
    ScheduledStartTime double = NaN
    ScheduledProcStartTime double = NaN
    ScheduledEndTime double = NaN
end

methods
    function duration = getActualDuration(obj)
        if ~isnan(obj.ActualProcStartTime) && ~isnan(obj.ActualProcEndTime)
            duration = obj.ActualProcEndTime - obj.ActualProcStartTime;
        else
            duration = NaN;
        end
    end

    function variance = getTimeVariance(obj)
        % Returns +/- minutes from scheduled
        if ~isnan(obj.ScheduledEndTime) && ~isnan(obj.ActualEndTime)
            variance = obj.ActualEndTime - obj.ScheduledEndTime;
        else
            variance = NaN;
        end
    end
end
```

#### 1.2 CaseManager.m - Add Status Management
```matlab
properties (Access = private)
    CompletedCases conduction.gui.models.ProspectiveCase  % Archive
    CurrentTimeMinutes double = NaN  % Current time in minutes from midnight
end

methods
    function setCaseStatus(obj, caseIndex, newStatus, actualTimes)
        % actualTimes: struct with ActualStartTime, ActualProcStartTime, etc.
        if caseIndex > numel(obj.Cases)
            return;
        end

        case = obj.Cases(caseIndex);
        case.CaseStatus = newStatus;

        if nargin >= 4 && ~isempty(actualTimes)
            if isfield(actualTimes, 'ActualStartTime')
                case.ActualStartTime = actualTimes.ActualStartTime;
            end
            % ... set other actual times
        end

        if newStatus == "completed"
            % Move to completed archive
            obj.CompletedCases(end+1) = case;
            obj.Cases(caseIndex) = [];
        end

        obj.notifyChange();
    end

    function pending = getPendingCases(obj)
        pending = obj.Cases([obj.Cases.CaseStatus] == "pending");
    end

    function inProgress = getInProgressCases(obj)
        inProgress = obj.Cases([obj.Cases.CaseStatus] == "in_progress");
    end

    function setCurrentTime(obj, timeMinutes)
        % Can be set manually or from system clock
        obj.CurrentTimeMinutes = timeMinutes;
    end
end
```

#### 1.3 Create CaseStatus Enum (Optional - for type safety)
**File**: `scripts/+conduction/+gui/+models/CaseStatus.m`
```matlab
classdef CaseStatus
    enumeration
        Pending
        InProgress
        Completed
    end
end
```

**Deliverables**:
- [ ] Modified ProspectiveCase.m with status fields
- [ ] Modified CaseManager.m with status methods
- [ ] (Optional) New CaseStatus.m enum
- [ ] Unit tests for status transitions

---

### Phase 2: UI Components for Status Management
**Goal**: Add visual indicators and controls for case status

#### 2.1 Status Badge on Schedule Visualization
**File**: `scripts/+conduction/visualizeDailySchedule.m`

Add status-based visual treatment:
- **Pending**: Normal appearance (current)
- **InProgress**: Yellow border + pulsing animation (optional)
- **Completed**: Blue/green tint + checkmark icon overlay

```matlab
% In plotLabSchedule function, after drawing case rectangles:

% Draw status indicator overlay
if isfield(entry, 'caseStatus')
    switch lower(entry.caseStatus)
        case 'in_progress'
            % Yellow pulsing border
            statusColor = [1, 0.8, 0];  % Yellow
            statusRect = rectangle(ax, 'Position', [xPos - barWidth/2, caseStartHour, barWidth, caseTotalDuration], ...
                'FaceColor', 'none', 'EdgeColor', statusColor, 'LineWidth', 2, 'LineStyle', '--');
            statusRect.PickableParts = 'none';

        case 'completed'
            % Green checkmark overlay
            checkX = xPos + barWidth/4;
            checkY = (caseStartHour + caseEndHour) / 2;
            text(ax, checkX, checkY, '✓', 'FontSize', 20, 'Color', [0, 0.8, 0], ...
                'FontWeight', 'bold', 'HitTest', 'off');
    end
end
```

#### 2.2 Current Time Indicator Line
Add vertical red line at current time:

```matlab
% In plotLabSchedule, after drawing all cases:
if ~isempty(opts) && isfield(opts, 'CurrentTimeMinutes')
    currentTimeMinutes = opts.CurrentTimeMinutes;
    if ~isnan(currentTimeMinutes)
        currentTimeHour = currentTimeMinutes / 60;
        if currentTimeHour >= startHour && currentTimeHour <= endHour
            xLimits = xlim(ax);
            line(ax, xLimits, [currentTimeHour, currentTimeHour], ...
                'Color', [1, 0, 0], 'LineStyle', '-', 'LineWidth', 3);
            text(ax, xLimits(2) - 0.2, currentTimeHour - 0.1, ...
                sprintf('NOW (%s)', minutesToTimeString(currentTimeMinutes)), ...
                'Color', [1, 0, 0], 'FontWeight', 'bold', 'FontSize', 10);
        end
    end
end
```

#### 2.3 Drawer Status Controls
**File**: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

Add UI components to drawer:
```matlab
% In createComponents() method for drawer:

% Status indicator label
DrawerStatusLabel = uilabel(DrawerInspectorGrid);
DrawerStatusLabel.Text = 'Status:';
DrawerStatusLabel.Layout.Row = 8;
DrawerStatusLabel.Layout.Column = 1;

DrawerStatusValueLabel = uilabel(DrawerInspectorGrid);
DrawerStatusValueLabel.Text = 'Pending';
DrawerStatusValueLabel.Layout.Row = 8;
DrawerStatusValueLabel.Layout.Column = 2;

% Status transition buttons
DrawerStartCaseBtn = uibutton(DrawerInspectorGrid, 'Text', 'Start Case');
DrawerStartCaseBtn.Layout.Row = 9;
DrawerStartCaseBtn.Layout.Column = [1 2];
DrawerStartCaseBtn.ButtonPushedFcn = @(~,~) handleStartCase(app);

DrawerCompleteCaseBtn = uibutton(DrawerInspectorGrid, 'Text', 'Complete Case');
DrawerCompleteCaseBtn.Layout.Row = 10;
DrawerCompleteCaseBtn.Layout.Column = [1 2];
DrawerCompleteCaseBtn.ButtonPushedFcn = @(~,~) handleCompleteCase(app);
```

#### 2.4 Actual Time Entry Dialog
**File**: `scripts/+conduction/+gui/+controllers/CaseStatusController.m` (NEW)

```matlab
classdef CaseStatusController < handle
    methods (Static)
        function showCompleteDialog(app, caseId)
            % Create modal dialog for entering actual times
            dlg = uifigure('Name', 'Complete Case', 'Position', [100 100 400 300]);
            grid = uigridlayout(dlg, [6 2]);

            % Case ID display
            uilabel(grid, 'Text', 'Case ID:', 'Layout.Row', 1, 'Layout.Column', 1);
            uilabel(grid, 'Text', char(caseId), 'Layout.Row', 1, 'Layout.Column', 2);

            % Actual procedure start time
            uilabel(grid, 'Text', 'Actual Proc Start:', 'Layout.Row', 2, 'Layout.Column', 1);
            procStartField = uitimepicker(grid, 'Layout.Row', 2, 'Layout.Column', 2);

            % Actual procedure end time
            uilabel(grid, 'Text', 'Actual Proc End:', 'Layout.Row', 3, 'Layout.Column', 2);
            procEndField = uitimepicker(grid, 'Layout.Row', 3, 'Layout.Column', 2);

            % Buttons
            confirmBtn = uibutton(grid, 'Text', 'Confirm', 'Layout.Row', 5, 'Layout.Column', 1);
            cancelBtn = uibutton(grid, 'Text', 'Cancel', 'Layout.Row', 5, 'Layout.Column', 2);

            confirmBtn.ButtonPushedFcn = @(~,~) confirmCompletion(app, caseId, procStartField.Value, procEndField.Value, dlg);
            cancelBtn.ButtonPushedFcn = @(~,~) close(dlg);
        end

        function confirmCompletion(app, caseId, procStart, procEnd, dlg)
            % Convert datetime to minutes from midnight
            actualProcStartMinutes = hour(procStart) * 60 + minute(procStart);
            actualProcEndMinutes = hour(procEnd) * 60 + minute(procEnd);

            actualTimes = struct();
            actualTimes.ActualProcStartTime = actualProcStartMinutes;
            actualTimes.ActualProcEndTime = actualProcEndMinutes;

            % Find case index and update status
            caseIndex = app.CaseStatusController.findCaseIndexById(app, caseId);
            if ~isnan(caseIndex)
                app.CaseManager.setCaseStatus(caseIndex, "completed", actualTimes);
                app.OptimizationController.renderCurrentSchedule(app);
            end

            close(dlg);
        end
    end
end
```

**Deliverables**:
- [ ] Status badges in visualization
- [ ] Current time indicator line
- [ ] Drawer status controls (Start/Complete buttons)
- [ ] Actual time entry dialog
- [ ] CaseStatusController.m (new file)

---

### Phase 3: Time Window Constraints
**Goal**: Modify optimizer to respect current time and lab availability

#### 3.1 SchedulingOptions.m - Add Time Window Parameters
```matlab
properties (SetAccess = immutable)
    % Existing properties...

    % Real-time scheduling properties
    CurrentTimeMinutes (1,1) double = NaN  % Current time constraint (minutes from midnight)
    LabAvailability containers.Map = containers.Map('KeyType','double','ValueType','double')  % lab_id -> earliest_start_minutes
end
```

#### 3.2 OptimizationModelBuilder.m - Add Time Constraints
**File**: `scripts/+conduction/+scheduling/OptimizationModelBuilder.m`

Add new constraint (Constraint 9):
```matlab
% Constraint 9: Case start times must be >= current time (if specified)
if ~isnan(prepared.currentTimeMinutes)
    currentTime = prepared.currentTimeMinutes;
    for caseIdx = 1:numCases
        for labIdx = 1:numLabs
            validSlots = validTimeSlots{labIdx};
            for t = validSlots(:)'
                if timeSlots(t) < currentTime
                    % This time slot is in the past - force to zero
                    varIdx = getVarIndex(caseIdx, labIdx, t);
                    Aeq(end+1, varIdx) = 1; %#ok<AGROW>
                    beq(end+1) = 0; %#ok<AGROW>
                end
            end
        end
    end
end

% Constraint 10: Lab-specific availability times
if ~isempty(prepared.labAvailability)
    labAvailKeys = prepared.labAvailability.keys;
    for i = 1:numel(labAvailKeys)
        labIdx = labAvailKeys{i};
        earliestStart = prepared.labAvailability(labIdx);

        % Force cases to start >= lab's earliest available time
        validSlots = validTimeSlots{labIdx};
        for caseIdx = 1:numCases
            for t = validSlots(:)'
                if timeSlots(t) < earliestStart
                    varIdx = getVarIndex(caseIdx, labIdx, t);
                    Aeq(end+1, varIdx) = 1; %#ok<AGROW>
                    beq(end+1) = 0; %#ok<AGROW>
                end
            end
        end
    end
end
```

#### 3.3 SchedulingPreprocessor.m - Process Status-Based Cases
```matlab
function prepared = prepareDataset(cases, options)
    % ... existing preprocessing

    % Add current time and lab availability
    prepared.currentTimeMinutes = options.CurrentTimeMinutes;
    prepared.labAvailability = options.LabAvailability;

    % ... rest of function
end
```

**Deliverables**:
- [ ] Modified SchedulingOptions with time window params
- [ ] Modified OptimizationModelBuilder with Constraints 9 & 10
- [ ] Modified SchedulingPreprocessor to pass time constraints
- [ ] Unit tests for time constraint enforcement

---

### Phase 4: Case Lifecycle Management
**Goal**: Implement state transition logic and validation

#### 4.1 Status Transition Rules
```
Pending → InProgress:
  - Allowed anytime
  - Auto-locks case at scheduled time
  - Stores scheduled times for later comparison

InProgress → Completed:
  - Requires actual end time entry
  - Validates: actual_end > actual_start
  - Moves to completed archive
  - Updates lab availability

Completed → (immutable):
  - Cannot change status
  - Can only edit actual times (with confirmation)

Invalid transitions:
  - Pending → Completed (must go through InProgress)
  - Completed → any other status
```

#### 4.2 Lab Availability Update Logic
**File**: `scripts/+conduction/+gui/+controllers/OptimizationController.m`

```matlab
function updateLabAvailability(~, app)
    % Recalculate lab availability based on completed cases
    labAvailability = containers.Map('KeyType', 'double', 'ValueType', 'double');

    % Initialize with original lab start times
    for labIdx = 1:numel(app.LabIds)
        labAvailability(labIdx) = app.Opts.labStarts(labIdx);
    end

    % Update based on completed cases
    completedCases = app.CaseManager.CompletedCases;
    if ~isempty(completedCases)
        for i = 1:numel(completedCases)
            case = completedCases(i);
            if ~isnan(case.ActualEndTime) && isfield(case, 'AssignedLab')
                labIdx = case.AssignedLab;
                currentAvail = labAvailability(labIdx);
                labAvailability(labIdx) = max(currentAvail, case.ActualEndTime);
            end
        end
    end

    % Also check in-progress cases
    inProgressCases = app.CaseManager.getInProgressCases();
    if ~isempty(inProgressCases)
        for i = 1:numel(inProgressCases)
            case = inProgressCases(i);
            if ~isnan(case.ScheduledEndTime) && isfield(case, 'AssignedLab')
                labIdx = case.AssignedLab;
                currentAvail = labAvailability(labIdx);
                labAvailability(labIdx) = max(currentAvail, case.ScheduledEndTime);
            end
        end
    end

    app.LabAvailability = labAvailability;
end
```

**Deliverables**:
- [ ] Status transition validation logic
- [ ] Lab availability update function
- [ ] Actual time validation (end > start, reasonable durations)
- [ ] Error handling for invalid transitions

---

### Phase 5: Re-optimization Integration
**Goal**: Filter cases by status and merge results correctly

#### 5.1 Status-Aware Optimization
**File**: `scripts/+conduction/+gui/+controllers/OptimizationController.m`

Modify `runOptimization` method:

```matlab
function runOptimization(obj, app)
    % Get pending cases only (exclude in-progress and completed)
    allCases = app.CaseManager.Cases;
    pendingCases = allCases([allCases.CaseStatus] == "pending");

    if isempty(pendingCases)
        uialert(app.UIFigure, 'No pending cases to optimize', 'Nothing to Optimize');
        return;
    end

    % Convert pending cases to optimization format
    casesStruct = obj.convertProspectiveCasesToOptimizationFormat(pendingCases, app);

    % Build locked constraints from completed + in-progress cases
    completedCases = app.CaseManager.CompletedCases;
    inProgressCases = app.CaseManager.getInProgressCases();
    lockedAssignments = [obj.convertToLockedFormat(completedCases, 'actual'); ...
                         obj.convertToLockedFormat(inProgressCases, 'scheduled')];

    lockedConstraints = obj.buildLockedCaseConstraints(lockedAssignments);

    % Update lab availability
    obj.updateLabAvailability(app);

    % Get current time (from UI or system clock)
    currentTime = app.CurrentTimeMinutes;
    if isnan(currentTime)
        currentTime = hour(datetime('now')) * 60 + minute(datetime('now'));
    end

    % Build options with time constraints
    options = conduction.scheduling.SchedulingOptions.fromArgs( ...
        'NumLabs', app.Opts.numLabs, ...
        'LabStartTimes', app.Opts.labStartTimes, ...
        'OptimizationMetric', app.Opts.metric, ...
        'CaseFilter', app.Opts.caseFilter, ...
        'MaxOperatorTime', app.Opts.maxOperatorTime, ...
        'TurnoverTime', app.Opts.turnover, ...
        'EnforceMidnight', logical(app.Opts.enforceMidnight), ...
        'PrioritizeOutpatient', logical(app.Opts.prioritizeOutpt), ...
        'LockedCaseConstraints', lockedConstraints, ...
        'CurrentTimeMinutes', currentTime, ...
        'LabAvailability', app.LabAvailability);

    % Run optimization (only on pending cases)
    [dailySchedule, outcome] = conduction.scheduleHistoricalCases(casesStruct, options);

    % Merge with locked cases for visualization
    fullSchedule = obj.mergeScheduleWithLockedCases(dailySchedule, lockedAssignments);

    % Store and render
    app.CurrentSchedule = fullSchedule;
    app.LastOptimizationOutcome = outcome;
    obj.renderCurrentSchedule(app);
end
```

#### 5.2 Convert Cases to Locked Format
```matlab
function lockedAssignments = convertToLockedFormat(~, cases, timeSource)
    % timeSource: 'actual' or 'scheduled'
    lockedAssignments = struct([]);

    for i = 1:numel(cases)
        case = cases(i);
        locked = struct();
        locked.caseID = case.OperatorName + "_" + string(i);  % Generate ID
        locked.operator = case.OperatorName;

        if timeSource == "actual"
            locked.startTime = case.ActualStartTime;
            locked.procStartTime = case.ActualProcStartTime;
            locked.procEndTime = case.ActualProcEndTime;
            locked.endTime = case.ActualEndTime;
        else  % scheduled
            locked.startTime = case.ScheduledStartTime;
            locked.procStartTime = case.ScheduledProcStartTime;
            locked.procEndTime = case.ScheduledEndTime;  % Simplified
            locked.endTime = case.ScheduledEndTime;
        end

        if isempty(lockedAssignments)
            lockedAssignments = locked;
        else
            lockedAssignments(end+1) = locked; %#ok<AGROW>
        end
    end
end
```

**Deliverables**:
- [ ] Status-aware case filtering in runOptimization
- [ ] Locked constraint building from completed/in-progress cases
- [ ] Schedule merging logic
- [ ] Testing with mixed-status cases

---

### Phase 6: Visualization Enhancements
**Goal**: Clear visual distinction between case statuses

#### 6.1 Color Coding by Status
In `visualizeDailySchedule.m`:

```matlab
% Define status-based alpha/brightness modifiers
function [faceAlpha, edgeWidth] = getStatusVisualization(caseStatus)
    switch lower(caseStatus)
        case 'pending'
            faceAlpha = 1.0;
            edgeWidth = 1;
        case 'in_progress'
            faceAlpha = 1.0;
            edgeWidth = 2;  % Thicker border
        case 'completed'
            faceAlpha = 0.7;  % Slightly faded
            edgeWidth = 1;
        otherwise
            faceAlpha = 1.0;
            edgeWidth = 1;
    end
end
```

#### 6.2 Variance Indicators
Add small indicator if case is running late/early:

```matlab
% If actual times differ significantly from scheduled
if ~isnan(entry.scheduledEndTime) && ~isnan(entry.actualEndTime)
    variance = entry.actualEndTime - entry.scheduledEndTime;
    if abs(variance) > 15  % More than 15 min variance
        varColor = variance > 0 ? [1, 0, 0] : [0, 1, 0];  % Red=late, Green=early
        % Add small triangle indicator
        plotVarianceIndicator(ax, xPos, procEndHour, variance, varColor);
    end
end
```

**Deliverables**:
- [ ] Status-based visual styling
- [ ] Variance indicators for completed cases
- [ ] Legend showing status colors
- [ ] Tooltip showing actual vs scheduled times

---

### Phase 7: Add-On Case Workflow
**Goal**: Streamline adding urgent cases during the day

#### 7.1 Quick Add Dialog
**File**: `scripts/+conduction/+gui/+controllers/CaseStatusController.m`

```matlab
function showQuickAddDialog(app)
    % Simplified dialog for add-on cases
    dlg = uifigure('Name', 'Add Add-On Case', 'Position', [100 100 350 250]);
    grid = uigridlayout(dlg, [5 2]);

    % Operator dropdown (pre-filled with known operators)
    uilabel(grid, 'Text', 'Operator:', 'Layout.Row', 1, 'Layout.Column', 1);
    opDropdown = uidropdown(grid, 'Items', app.OperatorNames, ...
        'Layout.Row', 1, 'Layout.Column', 2);

    % Procedure dropdown
    uilabel(grid, 'Text', 'Procedure:', 'Layout.Row', 2, 'Layout.Column', 1);
    procDropdown = uidropdown(grid, 'Items', app.ProcedureNames, ...
        'Layout.Row', 2, 'Layout.Column', 2);

    % Admission status
    uilabel(grid, 'Text', 'Admission:', 'Layout.Row', 3, 'Layout.Column', 1);
    admissionDropdown = uidropdown(grid, 'Items', {'outpatient', 'inpatient'}, ...
        'Layout.Row', 3, 'Layout.Column', 2);

    % Urgency checkbox
    urgentCheck = uicheckbox(grid, 'Text', 'Urgent (schedule ASAP)', ...
        'Layout.Row', 4, 'Layout.Column', [1 2]);

    % Add button
    addBtn = uibutton(grid, 'Text', 'Add & Optimize', ...
        'Layout.Row', 5, 'Layout.Column', [1 2]);
    addBtn.ButtonPushedFcn = @(~,~) handleQuickAdd(app, opDropdown.Value, ...
        procDropdown.Value, admissionDropdown.Value, urgentCheck.Value, dlg);
end
```

#### 7.2 Auto-Optimization After Add
```matlab
function handleQuickAdd(app, operator, procedure, admission, isUrgent, dlg)
    % Add case to pending pool
    app.CaseManager.addCase(operator, procedure, NaN, "", false, admission);

    % If urgent, auto-trigger re-optimization
    if isUrgent
        app.OptimizationController.runOptimization(app);
    end

    close(dlg);
end
```

**Deliverables**:
- [ ] Quick add dialog UI
- [ ] Auto-optimization option
- [ ] Urgent case priority handling
- [ ] Notification when add-on scheduled

---

### Phase 8: Analytics & Reporting
**Goal**: Track schedule performance and variance

#### 8.1 Variance Metrics
**File**: `scripts/+conduction/+analytics/ScheduleVarianceAnalyzer.m` (NEW)

```matlab
classdef ScheduleVarianceAnalyzer
    methods (Static)
        function report = analyzeScheduleAdherence(completedCases)
            report = struct();

            % Calculate per-case variance
            variances = arrayfun(@(c) c.getTimeVariance(), completedCases);

            report.meanVariance = mean(variances(~isnan(variances)));
            report.stdVariance = std(variances(~isnan(variances)));
            report.onTimeCount = sum(abs(variances) <= 5);  % Within 5 min
            report.lateCount = sum(variances > 5);
            report.earlyCount = sum(variances < -5);

            % Identify bottleneck operators/procedures
            % ... additional analysis
        end
    end
end
```

#### 8.2 End-of-Day Report
Export planned vs actual report:

```matlab
function exportDailyReport(app, filename)
    allCases = [app.CaseManager.Cases, app.CaseManager.CompletedCases];

    reportTable = table();
    reportTable.CaseID = {allCases.OperatorName}';
    reportTable.Status = {allCases.CaseStatus}';
    reportTable.ScheduledStart = [allCases.ScheduledStartTime]';
    reportTable.ActualStart = [allCases.ActualStartTime]';
    reportTable.Variance = [allCases.getTimeVariance()]';

    writetable(reportTable, filename);
end
```

**Deliverables**:
- [ ] ScheduleVarianceAnalyzer.m (new file)
- [ ] Variance metrics calculation
- [ ] End-of-day report export
- [ ] Dashboard showing real-time adherence

---

## Data Model Changes

### Summary of New Fields

| Class | New Properties | Type | Purpose |
|-------|---------------|------|---------|
| `ProspectiveCase` | `CaseStatus` | string | "pending", "in_progress", "completed" |
| | `ActualStartTime` | double | Actual setup start (minutes) |
| | `ActualProcStartTime` | double | Actual procedure start |
| | `ActualProcEndTime` | double | Actual procedure end |
| | `ActualEndTime` | double | Actual post completion |
| | `ScheduledStartTime` | double | For variance comparison |
| | `ScheduledProcStartTime` | double | For variance comparison |
| | `ScheduledEndTime` | double | For variance comparison |
| | `AssignedLab` | double | Which lab case was assigned to |
| `CaseManager` | `CompletedCases` | ProspectiveCase array | Archive of completed cases |
| | `CurrentTimeMinutes` | double | Current time tracker |
| `ProspectiveSchedulerApp` | `LabAvailability` | containers.Map | Lab → earliest start time |
| | `CurrentTimeMinutes` | double | Synced current time |
| `SchedulingOptions` | `CurrentTimeMinutes` | double | Time constraint for optimizer |
| | `LabAvailability` | containers.Map | Per-lab availability |

---

## UI/UX Specifications

### Visual Indicators

| Element | Description | Visual Style |
|---------|-------------|--------------|
| Pending Case | Normal appearance | Standard operator color, normal borders |
| In-Progress Case | Active indicator | Yellow dashed border (2px), slight glow |
| Completed Case | Finished indicator | Faded opacity (0.7), green checkmark overlay |
| Current Time Line | Shows "now" | Red vertical line (3px), "NOW" label |
| Variance Indicator | Early/late marker | Small triangle: green=early, red=late |
| Status Badge | Case drawer status | Pill badge: gray/yellow/green |

### Drawer Layout (with status controls)

```
┌─────────────────────────────────┐
│ Case Inspector              [×] │
├─────────────────────────────────┤
│ Case ID:        ABC123          │
│ Operator:       Dr. Smith       │
│ Lab:            Lab 2           │
│ Status:         [In Progress]   │  ← New badge
│                                 │
│ Scheduled Times:                │
│   Start:        09:00 AM        │
│   End:          11:30 AM        │
│                                 │
│ Actual Times:                   │  ← New section
│   Start:        09:05 AM        │
│   End:          11:45 AM        │
│   Variance:     +15 min         │
│                                 │
│ [Start Case]    [Complete]      │  ← Action buttons
│                                 │
│ [ ] Lock case                   │
├─────────────────────────────────┤
│ Duration Histogram              │
│ [Chart]                         │
└─────────────────────────────────┘
```

### Keyboard Shortcuts (Future)
- `S` - Mark selected case as Started
- `C` - Mark selected case as Completed
- `R` - Re-optimize pending cases
- `A` - Quick add add-on case
- `T` - Set current time

---

## Optimizer Modifications

### New Constraints

| # | Constraint | Description | Implementation |
|---|------------|-------------|----------------|
| 9 | Current Time | All case starts >= CurrentTime | Force x_ijt = 0 for t < CurrentTime |
| 10 | Lab Availability | Case in lab L starts >= LabAvail[L] | Force x_iLt = 0 for t < LabAvail[L] |

### Modified Variables
- Decision variables only for **pending cases**
- Completed cases excluded entirely
- In-progress cases included as locked constraints

### Performance Considerations
- Fewer decision variables → faster solve times
- Typical reduction: 30-50% fewer variables as day progresses
- Expected solve time: <10 seconds for 20 pending cases

---

## File Change Inventory

### New Files
1. `scripts/+conduction/+gui/+models/CaseStatus.m` - Enum for case status
2. `scripts/+conduction/+gui/+controllers/CaseStatusController.m` - Status management logic
3. `scripts/+conduction/+analytics/ScheduleVarianceAnalyzer.m` - Variance analysis
4. `REALTIME_SCHEDULING_PLAN.md` - This document

### Modified Files
1. `scripts/+conduction/+gui/+models/ProspectiveCase.m`
   - Add status and actual time properties
   - Add variance calculation methods

2. `scripts/+conduction/+gui/+controllers/CaseManager.m`
   - Add status management methods
   - Add completed case archive
   - Add current time tracking

3. `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
   - Add drawer status UI components
   - Add lab availability property
   - Add current time sync

4. `scripts/+conduction/+gui/+controllers/DrawerController.m`
   - Add status display logic
   - Add start/complete button handlers

5. `scripts/+conduction/+gui/+controllers/OptimizationController.m`
   - Add status-aware filtering
   - Add lab availability updates
   - Add locked case merging

6. `scripts/+conduction/+scheduling/SchedulingOptions.m`
   - Add CurrentTimeMinutes property
   - Add LabAvailability property

7. `scripts/+conduction/+scheduling/OptimizationModelBuilder.m`
   - Add Constraint 9 (current time)
   - Add Constraint 10 (lab availability)

8. `scripts/+conduction/+scheduling/SchedulingPreprocessor.m`
   - Pass time constraints to model builder

9. `scripts/+conduction/visualizeDailySchedule.m`
   - Add status-based visual styling
   - Add current time indicator
   - Add variance indicators
   - Add status parameter

10. `scripts/+conduction/+scheduling/ScheduleAssembler.m`
    - Handle merging of status-filtered results

### Configuration Files
1. `VERSION` - Bump to 0.4.0 after completion

---

## Testing Strategy

### Unit Tests

#### Phase 1 Tests
- [ ] `ProspectiveCase` status transitions
- [ ] `CaseManager` status filtering (pending/in-progress/completed)
- [ ] Actual time validation (end > start)

#### Phase 2 Tests
- [ ] Visual indicator rendering for each status
- [ ] Current time line positioning
- [ ] Drawer UI state syncing

#### Phase 3 Tests
- [ ] Current time constraint (no cases before "now")
- [ ] Lab availability constraint (cases start >= lab avail time)
- [ ] Edge case: all cases in the past

#### Phase 5 Tests
- [ ] Status-aware optimization (only pending cases optimized)
- [ ] Locked constraint generation from completed cases
- [ ] Schedule merging (pending + completed + in-progress)

### Integration Tests

#### Scenario 1: Morning Optimization
1. Load 10 pending cases
2. Optimize → all scheduled
3. Verify all cases still marked "pending"

#### Scenario 2: Mid-Day Re-optimization
1. Mark 3 cases as "completed" with actual times
2. Mark 2 cases as "in-progress"
3. Add 1 new add-on case
4. Re-optimize
5. Verify:
   - 3 completed cases unchanged
   - 2 in-progress cases locked at scheduled times
   - 5 pending + 1 add-on rescheduled after current time

#### Scenario 3: Lab Freed Early
1. Case scheduled 10:00-12:00 in Lab 1
2. Case completes at 11:30 (30 min early)
3. Re-optimize
4. Verify next case in Lab 1 can start at 11:30, not 12:00

#### Scenario 4: End-of-Day Report
1. Complete all cases with actual times
2. Export daily report
3. Verify variance calculations correct

### User Acceptance Testing
- [ ] Scheduler can mark cases in-progress during the day
- [ ] Scheduler can enter actual times and complete cases
- [ ] Re-optimization respects completed cases
- [ ] New add-on cases scheduled correctly
- [ ] Visual indicators are clear and intuitive
- [ ] Variance report is accurate

---

## Future Enhancements

### Phase 9: Automation & Intelligence (v0.5.0)
- **Auto-status updates**: Integration with EMR/EHR for automatic case status updates
- **Predictive delays**: ML model to predict if current case will run late
- **Smart alerts**: Notify next patient if previous case delayed
- **Automatic re-optimization**: Trigger re-opt when variance threshold exceeded

### Phase 10: Mobile Companion (v0.6.0)
- **Mobile app**: iOS/Android app for operators to update status
- **Push notifications**: Alert scheduler of case completion
- **Quick status toggle**: One-tap start/complete from phone
- **Voice commands**: "Complete case 123"

### Phase 11: Advanced Analytics (v0.7.0)
- **Operator performance metrics**: Average variance by operator
- **Procedure benchmarking**: Compare durations across operators
- **Bottleneck detection**: Identify systemic delays
- **Predictive scheduling**: Suggest buffer times based on historical variance
- **Resource utilization**: Track equipment, staff, room usage

### Phase 12: Multi-Day Planning (v0.8.0)
- **Rolling schedule**: Optimize across multiple days
- **Case carryover**: Handle cases that don't fit in current day
- **Block scheduling**: Reserve time blocks for specific case types
- **Vacation planning**: Adjust for operator availability

---

## Implementation Timeline (Estimated)

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Data Model | 2-3 days | None |
| Phase 2: UI Components | 3-4 days | Phase 1 |
| Phase 3: Time Constraints | 2-3 days | Phase 1 |
| Phase 4: Lifecycle Management | 2 days | Phases 1, 3 |
| Phase 5: Re-optimization | 3-4 days | Phases 1, 3, 4 |
| Phase 6: Visualization | 2-3 days | Phases 1, 2, 5 |
| Phase 7: Add-On Workflow | 1-2 days | Phases 2, 5 |
| Phase 8: Analytics | 2-3 days | Phases 1, 4 |
| **Total** | **17-24 days** | (3-5 weeks) |

---

## Migration Path

### From Current System
1. **Backwards compatible**: Existing schedules continue to work
2. **Opt-in status tracking**: Cases default to "pending" if no status set
3. **Gradual adoption**: Users can start using real-time features incrementally
4. **Data preservation**: No loss of existing case/schedule data

### Deployment Strategy
1. Complete Phases 1-3 (foundation)
2. Deploy to staging for internal testing
3. Complete Phases 4-6 (core functionality)
4. Beta test with 1-2 schedulers
5. Complete Phases 7-8 (enhancements)
6. Full production deployment
7. Monitor and iterate

---

## Open Questions & Decisions Needed

### Technical Decisions
- [ ] Should `CaseStatus` be string or enum? (Recommendation: string for simplicity)
- [ ] Store completed cases in memory or persist to disk? (Recommendation: memory for now, export to CSV at EOD)
- [ ] Auto-set current time from system clock or manual override? (Recommendation: auto with manual override option)
- [ ] How to handle case status if user closes app mid-day? (Recommendation: auto-save status to .mat file)

### UX Decisions
- [ ] Should "Start Case" auto-lock the case? (Recommendation: yes)
- [ ] Allow editing actual times after case completed? (Recommendation: yes, with confirmation dialog)
- [ ] Show variance indicators immediately or only at EOD? (Recommendation: immediately for real-time feedback)
- [ ] Keyboard shortcuts for status changes? (Recommendation: Phase 9 enhancement)

### Workflow Decisions
- [ ] Who updates case status: physician, nurse, or scheduler? (User-specific)
- [ ] Automatically re-optimize when case completes early? (Recommendation: optional setting)
- [ ] Alert if case running >15 min late? (Recommendation: Phase 9 enhancement)

---

## Success Metrics

### Primary Goals
- Reduce schedule variance by 30%
- Enable same-day add-on scheduling
- Increase lab utilization by 10%
- Decrease patient wait times

### Measurable Outcomes
- % of cases completed within 10 min of scheduled time
- # of add-on cases successfully scheduled same-day
- Average time from case completion to next case start
- User satisfaction (survey after 1 month)

---

## References

### Related Documents
- `CASE_LOCKING_PROGRESS.md` - Case locking implementation (dependency)
- `METHOD_MAPPING.md` - Architecture reference
- `REFACTORING_SUMMARY.md` - Code structure overview

### Key Code Files
- `ProspectiveSchedulerApp.m` - Main GUI application
- `OptimizationController.m` - Optimization orchestration
- `OptimizationModelBuilder.m` - ILP constraint generation
- `visualizeDailySchedule.m` - Schedule rendering

---

**Document Version**: 1.0
**Created**: 2025-10-02
**Last Updated**: 2025-10-02
**Status**: Planning Phase
**Next Review**: After Phase 1 completion
