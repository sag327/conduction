# Unified Timeline Framework – Implementation Plan

**Status:** Phases 1–4 COMPLETE; Phase 5 IN PROGRESS
**Current Focus:** Phase 5 – Polish & Testing (staleness banner + undo toast complete; conflict details + tests pending)
**Last Updated:** 2025-11-16
**Recent Commits:** 3061b1f (unscheduled-only overlay preserves post/turnover), 3b86c93 (per‑lab earliest start), 86ed8c4 (docs updates)

---

## Table of Contents

1. [Overview](#overview)
2. [Phase 0: Analysis & Preparation](#phase-0-analysis--preparation) ✅
3. [Phase 1: Foundation - Unify Timeline](#phase-1-foundation---unify-timeline)
4. [Phase 2: Smart Optimize Button](#phase-2-smart-optimize-button)
5. [Phase 3: Proposed Tab Workflow](#phase-3-proposed-tab-workflow)
6. [Phase 4: Progressive Disclosure](#phase-4-progressive-disclosure)
7. [Phase 5: Polish & Testing](#phase-5-polish--testing)
8. [Testing Strategy](#testing-strategy)
9. [Rollback Procedures](#rollback-procedures)

---

## Overview

### Goals
- Eliminate Time Control toggle complexity
- Make NOW line always visible (defaults to start of day)
- Derive case status from NOW position (not stored)
- Unify dual schedule objects into single schedule
- Simplify lock management (auto-locks vs user locks)
- Implement smart context-aware optimize button
- Add Proposed tab for mid-day rescheduling preview

### Principles
- **DRY (Don't Repeat Yourself):** Extract reusable functions, avoid duplication
- **KISS (Keep It Simple, Stupid):** Simplify state management, reduce branches
- **Modularity:** Keep controllers focused, extract helpers to utilities
- **Avoid Bloat:** Refactor large functions into smaller composable pieces
- **Incremental:** Each sub-task is testable independently
- **Safe:** Maintain backward compatibility during migration

### Risk Mitigation
- Branch protection: Work on `improve-dynamic-rescheduling` branch
- Frequent commits: Commit after each sub-task completion
- Testing: CLI tests after each sub-task
- Rollback: Clear rollback instructions for each phase
- Backward compatibility: Support old session files during migration

---

## Phase 0: Analysis & Preparation

**Status:** ✅ **COMPLETE**

### Completed Tasks
1. ✅ Analyzed current Time Control implementation
2. ✅ Mapped IsTimeControlActive usage (4 files, 10+ locations)
3. ✅ Documented NOW line rendering and dragging
4. ✅ Identified dual schedule pattern (OptimizedSchedule vs SimulatedSchedule)
5. ✅ Analyzed lock management (3 arrays: LockedCaseIds, TimeControlLockedCaseIds, TimeControlBaselineLockedIds)
6. ✅ Documented status management (stored in ProspectiveCase.CaseStatus)
7. ✅ Traced optimization execution flow
8. ✅ Created detailed implementation plan document

### Deliverables
- ✅ Current Implementation Analysis (agent report)
- ✅ This implementation plan document
- ✅ Identified 23 specific code locations requiring changes

---

## Phase 1: Foundation - Unify Timeline

**Goal:** Remove Time Control toggle, make NOW line always visible, derive status from NOW position, unify schedule objects.

**Estimated Duration:** 3-5 days
**Risk Level:** HIGH (fundamental state management changes)
**Status:** COMPLETE

### Sub-Phase 1.1: Add NOW Position to App State

**Objective:** Create persistent NOW position storage separate from Time Control.

#### Tasks

**1.1.1 Add NowPositionMinutes property**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After line 911 (in properties block)

**Code to add:**
```matlab
NowPositionMinutes double = 480  % NOW line position (default 8:00 AM = 480 minutes)
```

**Why:** Replaces implicit coupling to `CaseManager.CurrentTimeMinutes` (which resets on Time Control toggle). NOW position is now first-class state.

**1.1.2 Add NOW position getter/setter methods**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** In methods section (after line 2500)

**Code to add:**
```matlab
function setNowPosition(app, timeMinutes)
    % Set NOW line position (in minutes from midnight)
    % Clamps to valid range [0, 1440]
    if isnan(timeMinutes)
        timeMinutes = 480;  % Default to 8:00 AM
    end
    timeMinutes = max(0, min(1440, timeMinutes));
    app.NowPositionMinutes = timeMinutes;
    app.markDirty();  % Session state changed
end

function timeMinutes = getNowPosition(app)
    % Get current NOW line position
    timeMinutes = app.NowPositionMinutes;
end
```

**Why:** Centralized NOW position management with validation. Ensures NOW stays within day bounds.

**Testing:**
```bash
# Launch MATLAB CLI test
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
% Test getter
assert(app.getNowPosition() == 480, 'Default NOW should be 8:00 AM (480 min)');
% Test setter
app.setNowPosition(600);
assert(app.getNowPosition() == 600, 'NOW should update to 600 min');
% Test clamping
app.setNowPosition(-100);
assert(app.getNowPosition() == 0, 'NOW should clamp to 0');
app.setNowPosition(2000);
assert(app.getNowPosition() == 1440, 'NOW should clamp to 1440');
% Test NaN default
app.setNowPosition(NaN);
assert(app.getNowPosition() == 480, 'NaN should reset to default');
delete(app);
disp('✅ Sub-task 1.1.1-1.1.2 PASSED');
"
```

**Success Criteria:**
- ✅ Property added to app
- ✅ Getter/setter work correctly
- ✅ Clamping to [0, 1440] enforced
- ✅ NaN resets to default (480)
- ✅ markDirty() called on change

**Rollback:** Remove property and methods, revert commit.

---

### Sub-Phase 1.2: Always Show NOW Line

**Objective:** NOW line visible even when Time Control is off. Rendering decoupled from IsTimeControlActive.

#### Tasks

**1.2.1 Update ScheduleRenderer to always render NOW line**

**File:** `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m`

**Location:** Line 95-113 (in `renderOptimizedSchedule` method)

**Current code:**
```matlab
% Line 95-97
if app.IsTimeControlActive
    currentTimeMinutes = app.CaseManager.getCurrentTime();
    % ... render NOW line ...
end
```

**Replace with:**
```matlab
% Always render NOW line (use app.NowPositionMinutes)
currentTimeMinutes = app.getNowPosition();
```

**Location:** Line 112 (parameter to visualizeDailySchedule)

**Keep:**
```matlab
'CurrentTimeMinutes', currentTimeMinutes, ...
```

**Why:** Removes conditional rendering. NOW line always shown, positioned by `app.NowPositionMinutes`.

**1.2.2 Update empty schedule render to show NOW line**

**File:** `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m`

**Location:** Line 54-56 (in `renderEmptySchedule` method)

**Current code:**
```matlab
if app.IsTimeControlActive
    obj.enableNowLineDrag(app);
end
```

**Replace with:**
```matlab
% Always enable NOW line drag
obj.enableNowLineDrag(app);
```

**Why:** NOW line always interactive, even with no schedule.

**1.2.3 Update NOW line drag to use NowPositionMinutes**

**File:** `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m`

**Location:** Line 1017-1019 (in `endDragNowLine` method)

**Current code:**
```matlab
app.CaseManager.setCurrentTime(finalTimeMinutes);
```

**Replace with:**
```matlab
app.setNowPosition(finalTimeMinutes);
```

**Why:** NOW position now managed by app state, not CaseManager.

**Testing:**
```bash
# Launch GUI and verify NOW line visible
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Check NOW line exists on schedule axes
nowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
assert(~isempty(nowLine), 'NOW line should exist on empty schedule');
% Check default position
assert(app.getNowPosition() == 480, 'Default NOW position should be 480');
% Add a case and optimize
app.OperatorField.Value = 'Operator1';
app.ProcedureField.Value = 'Procedure1';
app.ProcedureTimeField.Value = 60;
app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Check NOW line still exists
nowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
assert(~isempty(nowLine), 'NOW line should exist after optimization');
delete(app);
disp('✅ Sub-task 1.2.1-1.2.3 PASSED');
"
```

**Success Criteria:**
- ✅ NOW line visible on empty schedule
- ✅ NOW line visible after optimization
- ✅ NOW line always draggable
- ✅ Dragging updates `app.NowPositionMinutes`
- ✅ No dependency on `IsTimeControlActive` for rendering

**Rollback:** Revert ScheduleRenderer.m changes, restore conditional rendering.

---

### Sub-Phase 1.3: Derive Status from NOW Position

**Objective:** Replace stored `CaseStatus` with computed status based on NOW position.

#### Tasks

**1.3.1 Add status computation utility**

**File:** `scripts/+conduction/+gui/+utils/StatusComputer.m` (NEW FILE)

**Create new file:**
```matlab
classdef StatusComputer
    % StatusComputer - Compute case status from NOW position
    % Follows Design Principle #3: Status is Derived, Not Stored

    methods (Static)
        function status = computeStatus(scheduledStartTime, scheduledEndTime, nowMinutes, manuallyCompleted)
            % Compute case status based on NOW position and schedule times
            %
            % Args:
            %   scheduledStartTime (double): Case start time in minutes from midnight
            %   scheduledEndTime (double): Case end time in minutes from midnight
            %   nowMinutes (double): Current NOW position in minutes from midnight
            %   manuallyCompleted (logical): Manual completion override flag
            %
            % Returns:
            %   status (string): "completed", "in_progress", or "pending"

            arguments
                scheduledStartTime double
                scheduledEndTime double
                nowMinutes double
                manuallyCompleted logical = false
            end

            % Manual completion overrides
            if manuallyCompleted
                status = "completed";
                return;
            end

            % No schedule times = pending
            if isnan(scheduledStartTime) || isnan(scheduledEndTime)
                status = "pending";
                return;
            end

            % Derive from NOW position
            if scheduledEndTime <= nowMinutes
                status = "completed";
            elseif scheduledStartTime <= nowMinutes && nowMinutes < scheduledEndTime
                status = "in_progress";
            else
                status = "pending";
            end
        end

        function shouldBeLocked = computeAutoLock(status)
            % Determine if case should be auto-locked based on status
            %
            % Args:
            %   status (string): Case status
            %
            % Returns:
            %   shouldBeLocked (logical): True if in-progress or completed

            shouldBeLocked = ismember(status, ["in_progress", "completed"]);
        end
    end
end
```

**Why:** Centralized, testable status computation. Follows KISS principle. Extracted from ScheduleRenderer.updateCaseStatusesByTime (DRY).

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
addpath(genpath('scripts'));
% Test pending (NOW before case)
status = conduction.gui.utils.StatusComputer.computeStatus(600, 660, 500, false);
assert(status == 'pending', 'Case starting at 10:00 should be pending at 8:20');
% Test in-progress (NOW during case)
status = conduction.gui.utils.StatusComputer.computeStatus(600, 660, 630, false);
assert(status == 'in_progress', 'Case 10:00-11:00 should be in-progress at 10:30');
% Test completed (NOW after case)
status = conduction.gui.utils.StatusComputer.computeStatus(600, 660, 700, false);
assert(status == 'completed', 'Case ending at 11:00 should be completed at 11:40');
% Test manual completion override
status = conduction.gui.utils.StatusComputer.computeStatus(600, 660, 500, true);
assert(status == 'completed', 'Manually completed should override time-based logic');
% Test auto-lock
assert(conduction.gui.utils.StatusComputer.computeAutoLock('in_progress'), 'In-progress should auto-lock');
assert(conduction.gui.utils.StatusComputer.computeAutoLock('completed'), 'Completed should auto-lock');
assert(~conduction.gui.utils.StatusComputer.computeAutoLock('pending'), 'Pending should NOT auto-lock');
disp('✅ Sub-task 1.3.1 PASSED');
"
```

**1.3.2 Add ManuallyCompleted flag to ProspectiveCase**

**File:** `scripts/+conduction/+gui/+models/ProspectiveCase.m`

**Location:** After line 32 (CaseStatus property)

**Code to add:**
```matlab
ManuallyCompleted logical = false  % Manual completion override (for marking complete without advancing NOW)
```

**Why:** Allows user to manually mark cases complete independent of NOW position.

**1.3.3 Add computed status getter to ProspectiveCase**

**File:** `scripts/+conduction/+gui/+models/ProspectiveCase.m`

**Location:** In methods section (after line 95)

**Code to add:**
```matlab
function status = getComputedStatus(obj, nowMinutes)
    % Get case status derived from NOW position and schedule times
    %
    % Args:
    %   nowMinutes (double): Current NOW position in minutes
    %
    % Returns:
    %   status (string): "completed", "in_progress", or "pending"

    status = conduction.gui.utils.StatusComputer.computeStatus(...
        obj.ScheduledStartTime, obj.ScheduledEndTime, nowMinutes, obj.ManuallyCompleted);
end

function shouldBeLocked = shouldBeAutoLocked(obj, nowMinutes)
    % Determine if case should be auto-locked at given NOW position
    %
    % Args:
    %   nowMinutes (double): Current NOW position
    %
    % Returns:
    %   shouldBeLocked (logical): True if case is in-progress or completed

    status = obj.getComputedStatus(nowMinutes);
    shouldBeLocked = conduction.gui.utils.StatusComputer.computeAutoLock(status);
end
```

**Why:** Encapsulates computation in model. Keeps CaseStatus property for backward compatibility but adds computed getter.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
addpath(genpath('scripts'));
% Create test case
caseObj = conduction.gui.models.ProspectiveCase( ...
    'Operator', 'TestOp', ...
    'Procedure', 'TestProc', ...
    'SetupMinutes', 15, ...
    'ProcedureMinutes', 60, ...
    'PostMinutes', 15);
% Simulate scheduled at 10:00
caseObj.ScheduledStartTime = 600;  % 10:00 AM
caseObj.ScheduledEndTime = 690;    % 11:30 AM
% Test before case (8:00 AM)
status = caseObj.getComputedStatus(480);
assert(status == 'pending', 'Should be pending before case');
assert(~caseObj.shouldBeAutoLocked(480), 'Should not be locked before case');
% Test during case (10:30 AM)
status = caseObj.getComputedStatus(630);
assert(status == 'in_progress', 'Should be in-progress during case');
assert(caseObj.shouldBeAutoLocked(630), 'Should be locked during case');
% Test after case (12:00 PM)
status = caseObj.getComputedStatus(720);
assert(status == 'completed', 'Should be completed after case');
assert(caseObj.shouldBeAutoLocked(720), 'Should be locked after case');
% Test manual completion
caseObj.ManuallyCompleted = true;
status = caseObj.getComputedStatus(480);
assert(status == 'completed', 'Manual completion should override');
disp('✅ Sub-task 1.3.2-1.3.3 PASSED');
"
```

**Success Criteria:**
- ✅ StatusComputer utility created and tested
- ✅ ManuallyCompleted flag added to model
- ✅ Computed status getter works correctly
- ✅ Auto-lock logic works correctly
- ✅ Manual completion overrides time-based logic

**Rollback:** Delete StatusComputer.m, remove ManuallyCompleted and computed methods from ProspectiveCase.m.

---

### Sub-Phase 1.4: Unify Schedule Objects

**Objective:** Eliminate dual OptimizedSchedule/SimulatedSchedule pattern. Single schedule with derived rendering.

#### Tasks

**1.4.1 Create schedule annotation helper**

**File:** `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m`

**Location:** Add new method (after line 1450)

**Code to add:**
```matlab
function annotatedSchedule = annotateScheduleWithDerivedStatus(~, app, schedule)
    % Annotate schedule with status derived from NOW position
    % Replaces updateCaseStatusesByTime pattern
    %
    % Args:
    %   app: App instance
    %   schedule: DailySchedule to annotate
    %
    % Returns:
    %   annotatedSchedule: DailySchedule with caseStatus fields updated

    if isempty(schedule)
        annotatedSchedule = schedule;
        return;
    end

    nowMinutes = app.getNowPosition();
    labs = schedule.Labs;
    assignments = schedule.labAssignments();

    % Iterate through all lab assignments
    for labIdx = 1:numel(labs)
        labCases = assignments{labIdx};
        if isempty(labCases)
            continue;
        end

        for caseIdx = 1:numel(labCases)
            caseId = string(labCases(caseIdx).caseID);
            caseObj = app.CaseStore.findById(caseId);

            if isempty(caseObj)
                continue;
            end

            % Compute status
            status = caseObj.getComputedStatus(nowMinutes);

            % Update schedule struct (for visualization only)
            labCases(caseIdx).caseStatus = char(status);
        end

        % Update assignment
        assignments{labIdx} = labCases;
    end

    % Create new schedule with updated assignments
    annotatedSchedule = conduction.DailySchedule(schedule.Date, labs, assignments, schedule.metrics());
end
```

**Why:** Extracted helper for schedule annotation. Replaces complex updateCaseStatusesByTime logic. Follows DRY (used during rendering). KISS (simple iteration, no lock management).

**1.4.2 Remove SimulatedSchedule property**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** Line 902

**Current code:**
```matlab
SimulatedSchedule conduction.DailySchedule  % REALTIME-SCHEDULING: Simulated schedule with derived case statuses (time control mode)
```

**Action:** Delete this line.

**Why:** No longer needed. Single schedule (OptimizedSchedule) is annotated on-demand.

**1.4.3 Update getScheduleForRendering()**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** Lines 1459-1467

**Current code:**
```matlab
function schedule = getScheduleForRendering(app)
    % REALTIME-SCHEDULING: Get the appropriate schedule for rendering
    % Returns SimulatedSchedule if time control is active, otherwise OptimizedSchedule
    if app.IsTimeControlActive && ~isempty(app.SimulatedSchedule)
        schedule = app.SimulatedSchedule;
    else
        schedule = app.OptimizedSchedule;
    end
end
```

**Replace with:**
```matlab
function schedule = getScheduleForRendering(app)
    % Get schedule for rendering with derived status annotations
    % Status is computed from NOW position, not stored
    if isempty(app.OptimizedSchedule)
        schedule = conduction.DailySchedule.empty;
    else
        % Annotate schedule with derived statuses
        schedule = app.ScheduleRenderer.annotateScheduleWithDerivedStatus(app, app.OptimizedSchedule);
    end
end
```

**Why:** Single schedule source. Annotation happens on-demand during rendering. Follows Design Principle #4 (single schedule, context-aware rendering).

**1.4.4 Remove SimulatedSchedule updates**

**Files to modify:**
- `scripts/+conduction/+gui/+controllers/OptimizationController.m`
- `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Search for:** `app.SimulatedSchedule =`

**Action:** Delete all lines that assign to SimulatedSchedule. (8 locations found in analysis)

**Locations:**
1. `toggleTimeControl.m` line 27 - DELETE
2. `OptimizationController.m` lines 136-142 - DELETE
3. `OptimizationController.m` line 146 - DELETE (clear line)
4. `OptimizationController.m` line 176 - DELETE (clear on failure)
5. `ScheduleRenderer.m` line 1037 - DELETE (NOW drag update)
6. `ProspectiveSchedulerApp.m` line 1675-1680 - DELETE (date change)
7. `ProspectiveSchedulerApp.m` line 1914 - DELETE (clear all)
8. `ProspectiveSchedulerApp.m` line 2009-2010 - DELETE (case removal)
9. `ProspectiveSchedulerApp.m` line 2023 - DELETE (status update)
10. `ProspectiveSchedulerApp.m` line 2744 - DELETE (clear all)

**Why:** Eliminates dual schedule pattern. Reduces state complexity. Follows KISS.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Add cases
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
% Optimize
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Verify single schedule
assert(~isempty(app.OptimizedSchedule), 'OptimizedSchedule should exist');
assert(~isprop(app, 'SimulatedSchedule') || isempty(app.SimulatedSchedule), 'SimulatedSchedule should be removed or empty');
% Get schedule for rendering
schedule = app.getScheduleForRendering();
assert(~isempty(schedule), 'Rendered schedule should exist');
% Move NOW forward
app.setNowPosition(600);  % 10:00 AM
% Get schedule again (should re-annotate)
schedule2 = app.getScheduleForRendering();
assert(~isempty(schedule2), 'Rendered schedule should update after NOW move');
% Check status annotation (first case should be completed if ended before NOW)
labs = schedule2.labAssignments();
if ~isempty(labs{1})
    firstCase = labs{1}(1);
    if firstCase.procEndTime < 600
        assert(strcmp(firstCase.caseStatus, 'completed'), 'Cases before NOW should be completed');
    end
end
delete(app);
disp('✅ Sub-task 1.4.1-1.4.4 PASSED');
"
```

**Success Criteria:**
- ✅ annotateScheduleWithDerivedStatus() helper created
- ✅ SimulatedSchedule property removed
- ✅ getScheduleForRendering() uses single schedule
- ✅ All SimulatedSchedule assignments removed
- ✅ Schedule renders with derived status
- ✅ Status updates when NOW changes

**Rollback:** Restore SimulatedSchedule property, restore getScheduleForRendering() logic, restore all SimulatedSchedule assignments.

---

### Sub-Phase 1.5: Simplify Lock Management

**Objective:** Replace 3 lock arrays with 2: IsUserLocked (per-case flag) and computed auto-lock.

#### Tasks

**1.5.1 Add IsUserLocked flag to ProspectiveCase**

**File:** `scripts/+conduction/+gui/+models/ProspectiveCase.m`

**Location:** After ManuallyCompleted property

**Code to add:**
```matlab
IsUserLocked logical = false  % Manual user lock (persists across NOW movements)
```

**Why:** Per-case lock flag is more modular than app-level array. Easier to serialize/deserialize.

**1.5.2 Deprecate IsLocked property (keep for migration)**

**File:** `scripts/+conduction/+gui/+models/ProspectiveCase.m`

**Location:** Line 42

**Current code:**
```matlab
IsLocked logical = false
```

**Replace with:**
```matlab
IsLocked logical = false  % DEPRECATED: Use IsUserLocked + auto-lock computation instead
```

**Why:** Keep for backward compatibility during migration, but mark as deprecated.

**1.5.3 Add computed lock getter to ProspectiveCase**

**File:** `scripts/+conduction/+gui/+models/ProspectiveCase.m`

**Location:** After shouldBeAutoLocked method

**Code to add:**
```matlab
function isLocked = getComputedLock(obj, nowMinutes)
    % Get effective lock state (user lock OR auto-lock)
    %
    % Args:
    %   nowMinutes (double): Current NOW position
    %
    % Returns:
    %   isLocked (logical): True if user locked OR auto-locked

    isLocked = obj.IsUserLocked || obj.shouldBeAutoLocked(nowMinutes);
end
```

**Why:** Centralized lock computation. User locks always active, auto-locks derived from NOW.

**1.5.4 Create lock migration helper**

**File:** `scripts/+conduction/+gui/+utils/LockMigration.m` (NEW FILE)

**Create new file:**
```matlab
classdef LockMigration
    % LockMigration - Utilities for migrating from old lock arrays to new per-case flags

    methods (Static)
        function migrateLocksToPerCaseFlags(app)
            % Migrate LockedCaseIds array to IsUserLocked per-case flags
            %
            % Args:
            %   app: App instance with CaseStore and LockedCaseIds

            if isempty(app.LockedCaseIds)
                return;
            end

            % Iterate through locked case IDs
            for i = 1:numel(app.LockedCaseIds)
                caseId = app.LockedCaseIds(i);
                caseObj = app.CaseStore.findById(caseId);

                if ~isempty(caseObj)
                    caseObj.IsUserLocked = true;
                end
            end

            % Clear old arrays (will be removed in later phase)
            app.LockedCaseIds = string.empty(1, 0);
            if isprop(app, 'TimeControlLockedCaseIds')
                app.TimeControlLockedCaseIds = string.empty(1, 0);
            end
            if isprop(app, 'TimeControlBaselineLockedIds')
                app.TimeControlBaselineLockedIds = string.empty(1, 0);
            end
        end

        function lockedCaseIds = extractLockedCaseIds(caseStore, nowMinutes)
            % Extract IDs of all locked cases (user OR auto)
            %
            % Args:
            %   caseStore: CaseStore instance
            %   nowMinutes: Current NOW position
            %
            % Returns:
            %   lockedCaseIds: Array of locked case IDs

            allCases = caseStore.list();
            lockedCaseIds = string.empty(1, 0);

            for i = 1:numel(allCases)
                caseObj = allCases(i);
                if caseObj.getComputedLock(nowMinutes)
                    lockedCaseIds = [lockedCaseIds; caseObj.CaseId]; %#ok<AGROW>
                end
            end
        end
    end
end
```

**Why:** Centralized migration logic. Extracted from app to keep app class focused. Reusable for session loading.

**1.5.5 Add lock migration to app startup**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** In `startupFcn` method (after line 1586)

**Code to add:**
```matlab
% Migrate old lock arrays to per-case flags
if ~isempty(app.LockedCaseIds)
    conduction.gui.utils.LockMigration.migrateLocksToPerCaseFlags(app);
end
```

**Why:** Automatic migration on app launch. Existing sessions with LockedCaseIds will migrate transparently.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
addpath(genpath('scripts'));
% Create mock case
caseObj = conduction.gui.models.ProspectiveCase( ...
    'Operator', 'TestOp', ...
    'Procedure', 'TestProc', ...
    'SetupMinutes', 15, ...
    'ProcedureMinutes', 60, ...
    'PostMinutes', 15);
caseObj.ScheduledStartTime = 600;  % 10:00 AM
caseObj.ScheduledEndTime = 660;    % 11:00 AM
% Test user lock
assert(~caseObj.getComputedLock(480), 'Should not be locked at 8:00 (pending, no user lock)');
caseObj.IsUserLocked = true;
assert(caseObj.getComputedLock(480), 'Should be locked at 8:00 (user lock active)');
caseObj.IsUserLocked = false;
% Test auto-lock
assert(~caseObj.getComputedLock(480), 'Should not be locked at 8:00 (pending)');
assert(caseObj.getComputedLock(630), 'Should be locked at 10:30 (in-progress = auto-lock)');
assert(caseObj.getComputedLock(700), 'Should be locked at 11:40 (completed = auto-lock)');
% Test user lock + auto-lock
caseObj.IsUserLocked = true;
assert(caseObj.getComputedLock(480), 'User lock should work at 8:00');
assert(caseObj.getComputedLock(630), 'User lock + auto-lock at 10:30');
assert(caseObj.getComputedLock(700), 'User lock + auto-lock at 11:40');
disp('✅ Sub-task 1.5.1-1.5.5 PASSED');
"
```

**Success Criteria:**
- ✅ IsUserLocked flag added to model
- ✅ getComputedLock() method works correctly
- ✅ LockMigration utility created
- ✅ Migration runs on app startup
- ✅ User locks and auto-locks computed correctly

**Rollback:** Remove IsUserLocked, remove LockMigration, remove startup migration call.

---

### Sub-Phase 1.6: Update Lock Extraction for Optimizer

**Objective:** Update DrawerController.extractLockedCaseAssignments() to use computed locks.

#### Tasks

**1.6.1 Update extractLockedCaseAssignments to use computed locks**

**File:** `scripts/+conduction/+gui/+controllers/DrawerController.m`

**Location:** Lines 436-491 (extractLockedCaseAssignments method)

**Current pattern:**
```matlab
if ismember(caseId, app.LockedCaseIds)
    % Extract case data
end
```

**Replace with:**
```matlab
nowMinutes = app.getNowPosition();
caseObj = app.CaseStore.findById(caseId);
if ~isempty(caseObj) && caseObj.getComputedLock(nowMinutes)
    % Extract case data
end
```

**Why:** Uses computed lock instead of array lookup. Respects both user locks and auto-locks.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Add and optimize cases
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Lock one case manually
cases = app.CaseStore.list();
cases(1).IsUserLocked = true;
% Extract locked assignments
lockedAssignments = app.DrawerController.extractLockedCaseAssignments(app);
assert(numel(lockedAssignments) >= 1, 'Should have at least 1 locked case (user locked)');
% Move NOW to lock more cases via auto-lock
app.setNowPosition(600);  % 10:00 AM
lockedAssignments2 = app.DrawerController.extractLockedCaseAssignments(app);
assert(numel(lockedAssignments2) > numel(lockedAssignments), 'Should have more locked cases after NOW advance (auto-locks)');
delete(app);
disp('✅ Sub-task 1.6.1 PASSED');
"
```

**Success Criteria:**
- ✅ extractLockedCaseAssignments uses computed locks
- ✅ User-locked cases extracted
- ✅ Auto-locked cases (in-progress/completed) extracted
- ✅ Lock extraction updates when NOW changes

**Rollback:** Restore original extractLockedCaseAssignments logic using LockedCaseIds array.

---

### Sub-Phase 1.7: Remove Time Control Toggle UI

**Objective:** Remove Time Control switch and related UI elements (keep backend flag for now).

#### Tasks

**1.7.1 Comment out Time Control switch**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** Line ~810 (TimeControlSwitch property)

**Current code:**
```matlab
TimeControlSwitch matlab.ui.control.Switch
```

**Replace with:**
```matlab
% TimeControlSwitch matlab.ui.control.Switch  % DEPRECATED: Removed in unified timeline
```

**Location:** Search for TimeControlSwitch creation (in buildUI or similar)

**Action:** Comment out switch creation and label.

**Why:** UI toggle no longer needed. NOW line always visible. Keep property commented (not deleted) for easy rollback.

**1.7.2 Keep IsTimeControlActive flag (set to true always)**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** Line 900

**Current code:**
```matlab
IsTimeControlActive logical = false
```

**Replace with:**
```matlab
IsTimeControlActive logical = true  % Always true in unified timeline (flag kept for migration compatibility)
```

**Why:** Some code still checks this flag. Setting to true always ensures NOW line features work. Will remove flag entirely in Phase 2 after all references updated.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Verify Time Control switch is gone or disabled
assert(app.IsTimeControlActive == true, 'IsTimeControlActive should always be true');
% Verify NOW line is visible
nowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
assert(~isempty(nowLine), 'NOW line should be visible');
% Verify NOW line is draggable
assert(~isempty(nowLine.ButtonDownFcn), 'NOW line should be draggable');
delete(app);
disp('✅ Sub-task 1.7.1-1.7.2 PASSED');
"
```

**Success Criteria:**
- ✅ Time Control switch removed from UI
- ✅ IsTimeControlActive = true always
- ✅ NOW line visible and draggable
- ✅ No UI toggle to enable/disable Time Control

**Rollback:** Uncomment TimeControlSwitch, restore UI creation, set IsTimeControlActive = false default.

---

### Phase 1 Summary

**What Changed:**
1. ✅ Added `NowPositionMinutes` to app state
2. ✅ NOW line always visible (decoupled from Time Control toggle)
3. ✅ Status derived from NOW position (`StatusComputer` utility)
4. ✅ Single schedule object (`SimulatedSchedule` removed)
5. ✅ Simplified locks (per-case `IsUserLocked` + auto-lock computation)
6. ✅ Time Control toggle UI removed
7. ✅ `IsTimeControlActive` = true always (kept for compatibility)

**Files Modified:**
- `ProspectiveSchedulerApp.m` - Added NowPositionMinutes, removed SimulatedSchedule, deprecated TimeControlSwitch
- `ScheduleRenderer.m` - Always render NOW, annotate schedule with derived status
- `ProspectiveCase.m` - Added ManuallyCompleted, IsUserLocked, computed getters
- `DrawerController.m` - Updated lock extraction
- `StatusComputer.m` (NEW) - Centralized status computation
- `LockMigration.m` (NEW) - Lock migration utility

**Lines Changed:** ~150 additions, ~80 deletions

**Testing:** All sub-tasks tested via CLI

**Rollback:** Revert all changes in reverse order, restore SimulatedSchedule pattern

---

## Phase 2: Smart Optimize Button

**Goal:** Make optimize button context-aware. Change label and behavior based on NOW position.

**Estimated Duration:** 1-2 days
**Risk Level:** MEDIUM (UI changes, routing logic)
**Status:** COMPLETE

### Sub-Phase 2.1: Add Button Label Logic

#### Tasks

**2.1.1 Add getOptimizeButtonLabel() method**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After getNowPosition() method

**Code to add:**
```matlab
function label = getOptimizeButtonLabel(app)
    % Get context-aware label for optimize button
    %
    % Returns:
    %   label (string): "Optimize Schedule" or "Re-optimize Remaining"

    if isempty(app.OptimizedSchedule)
        % No schedule yet
        label = "Optimize Schedule";
        return;
    end

    nowMinutes = app.getNowPosition();

    % Get first scheduled case start time
    labs = app.OptimizedSchedule.labAssignments();
    firstCaseStart = inf;

    for labIdx = 1:numel(labs)
        labCases = labs{labIdx};
        if ~isempty(labCases)
            for caseIdx = 1:numel(labCases)
                procStartTime = labCases(caseIdx).procStartTime;
                if ~isnan(procStartTime) && procStartTime < firstCaseStart
                    firstCaseStart = procStartTime;
                end
            end
        end
    end

    % NOW before first case = full optimization
    % NOW after first case = re-optimize remaining
    if nowMinutes <= firstCaseStart
        label = "Optimize Schedule";
    else
        label = "Re-optimize Remaining";
    end
end
```

**Why:** Centralized button label logic. Context-aware based on NOW position vs schedule.

**2.1.2 Update button label on NOW change**

**File:** `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m`

**Location:** In endDragNowLine() method (after line 1045)

**Code to add:**
```matlab
% Update optimize button label
app.OptimizationRunButton.Text = app.getOptimizeButtonLabel();
```

**Why:** Button label updates when NOW moves.

**2.1.3 Update button label after optimization**

**File:** `scripts/+conduction/+gui/+controllers/OptimizationController.m`

**Location:** In executeOptimization() method (after line 150)

**Code to add:**
```matlab
% Update optimize button label
app.OptimizationRunButton.Text = app.getOptimizeButtonLabel();
```

**Why:** Button label updates when schedule changes.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% No schedule = 'Optimize Schedule'
label = app.getOptimizeButtonLabel();
assert(label == 'Optimize Schedule', 'Should be Optimize Schedule with no schedule');
% Add cases and optimize
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% NOW at start = 'Optimize Schedule'
app.setNowPosition(480);  % 8:00 AM
label = app.getOptimizeButtonLabel();
assert(label == 'Optimize Schedule', 'Should be Optimize Schedule when NOW before cases');
% NOW after first case = 'Re-optimize Remaining'
app.setNowPosition(600);  % 10:00 AM
label = app.getOptimizeButtonLabel();
assert(label == 'Re-optimize Remaining', 'Should be Re-optimize Remaining when NOW after cases');
delete(app);
disp('✅ Sub-task 2.1.1-2.1.3 PASSED');
"
```

**Success Criteria:**
- ✅ Button label is "Optimize Schedule" when NOW ≤ first case
- ✅ Button label is "Re-optimize Remaining" when NOW > first case
- ✅ Label updates when NOW changes
- ✅ Label updates after optimization

**Rollback:** Remove getOptimizeButtonLabel(), remove label update calls.

---

### Sub-Phase 2.2: Add Re-optimization Mode Flag

#### Tasks

**2.2.1 Add isReoptimizationMode() method**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After getOptimizeButtonLabel() method

**Code to add:**
```matlab
function isReoptMode = isReoptimizationMode(app)
    % Check if in re-optimization mode (NOW past first scheduled case)
    %
    % Returns:
    %   isReoptMode (logical): True if should trigger Proposed tab workflow

    isReoptMode = (app.getOptimizeButtonLabel() == "Re-optimize Remaining");
end
```

**Why:** Centralized mode detection. Used to route to Proposed tab vs direct apply.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% No schedule = not reopt mode
assert(~app.isReoptimizationMode(), 'Should not be reopt mode with no schedule');
% Add and optimize
for i = 1:2
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% NOW before = not reopt mode
app.setNowPosition(480);
assert(~app.isReoptimizationMode(), 'Should not be reopt mode when NOW before cases');
% NOW after = reopt mode
app.setNowPosition(600);
assert(app.isReoptimizationMode(), 'Should be reopt mode when NOW after cases');
delete(app);
disp('✅ Sub-task 2.2.1 PASSED');
"
```

**Success Criteria:**
- ✅ isReoptimizationMode() returns false when NOW ≤ first case
- ✅ isReoptimizationMode() returns true when NOW > first case

**Rollback:** Remove isReoptimizationMode() method.

---

### Sub-Phase 2.3: Filter Cases by NOW Position

#### Tasks

**2.3.1 Add filterCasesByNowPosition() helper**

**File:** `scripts/+conduction/+gui/+controllers/CaseManager.m`

**Location:** After buildOptimizationCases() method

**Code to add:**
```matlab
function [filteredCases, excludedCount] = filterCasesByNowPosition(obj, casesStruct, nowMinutes)
    % Filter cases to only include those scheduled after NOW
    % Used for re-optimization mode
    %
    % Args:
    %   casesStruct: Array of case structs for optimizer
    %   nowMinutes: Current NOW position
    %
    % Returns:
    %   filteredCases: Cases with startTime > NOW
    %   excludedCount: Number of cases excluded

    if isempty(casesStruct)
        filteredCases = casesStruct;
        excludedCount = 0;
        return;
    end

    % Find cases that start after NOW
    includeMask = true(size(casesStruct));

    for i = 1:numel(casesStruct)
        % If case has scheduled start time and it's before NOW, exclude
        if isfield(casesStruct(i), 'scheduledStartTime') && ...
           ~isnan(casesStruct(i).scheduledStartTime) && ...
           casesStruct(i).scheduledStartTime <= nowMinutes
            includeMask(i) = false;
        end
    end

    filteredCases = casesStruct(includeMask);
    excludedCount = sum(~includeMask);
end
```

**Why:** Extracted case filtering logic. Keeps OptimizationController focused. Reusable for scope controls.

**2.3.2 Update executeOptimization to filter cases in reopt mode**

**File:** `scripts/+conduction/+gui/+controllers/OptimizationController.m`

**Location:** After buildOptimizationCases() call (after line 41)

**Code to add:**
```matlab
% In re-optimization mode, filter cases by NOW position
if app.isReoptimizationMode()
    nowMinutes = app.getNowPosition();
    [casesStruct, excludedCount] = app.CaseManager.filterCasesByNowPosition(casesStruct, nowMinutes);

    if excludedCount > 0
        fprintf('Re-optimization: Excluded %d cases (before NOW at %.0f minutes)\n', excludedCount, nowMinutes);
    end

    if isempty(casesStruct)
        uialert(app.UIFigure, ...
            'No cases to re-optimize after current time.', ...
            'Re-optimization Info', 'Icon', 'info');
        return;
    end
end
```

**Why:** Filters cases when in reopt mode. Only schedules cases after NOW.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Add 3 cases
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
% Optimize
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Count scheduled cases
labs = app.OptimizedSchedule.labAssignments();
totalCases = 0;
for i = 1:numel(labs)
    totalCases = totalCases + numel(labs{i});
end
assert(totalCases == 3, 'Should schedule all 3 cases');
% Move NOW past first case
firstCaseEnd = labs{1}(1).procEndTime;
app.setNowPosition(firstCaseEnd + 10);
% Re-optimize (should exclude first case)
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% First case should still be in schedule (locked/completed)
% Only future cases should be rescheduled
% (Full validation in Phase 3 with Proposed tab)
delete(app);
disp('✅ Sub-task 2.3.1-2.3.2 PASSED');
"
```

**Success Criteria:**
- ✅ filterCasesByNowPosition() filters cases correctly
- ✅ Re-optimization excludes cases before NOW
- ✅ Alert shown if no cases to re-optimize
- ✅ Full optimization (NOW at start) includes all cases

**Rollback:** Remove filterCasesByNowPosition(), remove filtering logic from executeOptimization.

---

### Phase 2 Summary

**What Changed:**
1. ✅ Optimize button label changes based on NOW position
2. ✅ Re-optimization mode detection logic
3. ✅ Case filtering by NOW position in reopt mode

**Files Modified:**
- `ProspectiveSchedulerApp.m` - Added getOptimizeButtonLabel(), isReoptimizationMode()
- `ScheduleRenderer.m` - Update button label on NOW drag
- `OptimizationController.m` - Update button label after optimization, filter cases in reopt mode
- `CaseManager.m` - Added filterCasesByNowPosition()

**Lines Changed:** ~80 additions

**Testing:** All sub-tasks tested via CLI

**Next:** Phase 3 will add Proposed tab to preview re-optimization changes.

---

## Phase 3: Proposed Tab Workflow

**Goal:** Add Proposed tab for non-destructive re-optimization preview.

**Estimated Duration:** 3-4 days
**Risk Level:** MEDIUM (new UI component, state management)
**Status:** COMPLETE

### Sub-Phase 3.1: Create Proposed Tab Structure

#### Tasks

**3.1.1 Add ProposedTab UI component**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After AnalyzeTab property (around line 780)

**Code to add:**
```matlab
ProposedTab matlab.ui.container.Tab  % Proposed schedule preview tab
ProposedAxes matlab.ui.control.UIAxes  % Axes for proposed schedule visualization
ProposedSchedule conduction.DailySchedule  % Proposed schedule (before acceptance)
ProposedAcceptButton matlab.ui.control.Button  % Accept proposed changes
ProposedDiscardButton matlab.ui.control.Button  % Discard proposal
ProposedRerunButton matlab.ui.control.Button  % Re-run with adjusted options
ProposedSummaryLabel matlab.ui.control.Label  % Summary: "X moved, Y unchanged, Z conflicts"
```

**Why:** Properties for Proposed tab UI elements. Keeps structure similar to Analyze tab.

**3.1.2 Create Proposed tab builder**

**File:** `scripts/+conduction/+gui/+app/buildProposedTab.m` (NEW FILE)

**Create new file:**
```matlab
function buildProposedTab(app, tabGroup)
    % Build Proposed schedule preview tab
    % Created on-demand when re-optimization is triggered

    % Create tab
    app.ProposedTab = uitab(tabGroup, 'Title', 'Proposed');

    % Create grid layout
    grid = uigridlayout(app.ProposedTab, [2, 1]);
    grid.RowHeight = {'fit', '1x'};
    grid.Padding = [10, 10, 10, 10];

    % Header panel with actions and summary
    headerPanel = uipanel(grid);
    headerPanel.Layout.Row = 1;
    headerPanel.Layout.Column = 1;
    headerPanel.BorderType = 'none';
    headerPanel.BackgroundColor = [0.15, 0.15, 0.15];

    headerGrid = uigridlayout(headerPanel, [1, 4]);
    headerGrid.ColumnWidth = {'1x', 'fit', 'fit', 'fit'};
    headerGrid.Padding = [10, 10, 10, 10];

    % Summary label
    app.ProposedSummaryLabel = uilabel(headerGrid);
    app.ProposedSummaryLabel.Layout.Row = 1;
    app.ProposedSummaryLabel.Layout.Column = 1;
    app.ProposedSummaryLabel.Text = 'Summary: ...';
    app.ProposedSummaryLabel.FontSize = 14;
    app.ProposedSummaryLabel.FontColor = [1, 1, 1];

    % Re-run button
    app.ProposedRerunButton = uibutton(headerGrid, 'push');
    app.ProposedRerunButton.Layout.Row = 1;
    app.ProposedRerunButton.Layout.Column = 2;
    app.ProposedRerunButton.Text = 'Re-run Options';
    app.ProposedRerunButton.ButtonPushedFcn = @(~,~) app.onProposedRerun();

    % Discard button
    app.ProposedDiscardButton = uibutton(headerGrid, 'push');
    app.ProposedDiscardButton.Layout.Row = 1;
    app.ProposedDiscardButton.Layout.Column = 3;
    app.ProposedDiscardButton.Text = 'Discard';
    app.ProposedDiscardButton.ButtonPushedFcn = @(~,~) app.onProposedDiscard();

    % Accept button
    app.ProposedAcceptButton = uibutton(headerGrid, 'push');
    app.ProposedAcceptButton.Layout.Row = 1;
    app.ProposedAcceptButton.Layout.Column = 4;
    app.ProposedAcceptButton.Text = 'Accept';
    app.ProposedAcceptButton.ButtonPushedFcn = @(~,~) app.onProposedAccept();
    app.ProposedAcceptButton.FontWeight = 'bold';
    app.ProposedAcceptButton.BackgroundColor = [0.2, 0.6, 0.2];
    app.ProposedAcceptButton.FontColor = [1, 1, 1];

    % Axes for proposed schedule
    app.ProposedAxes = uiaxes(grid);
    app.ProposedAxes.Layout.Row = 2;
    app.ProposedAxes.Layout.Column = 1;
    app.ProposedAxes.BackgroundColor = [0, 0, 0];
    app.ProposedAxes.XColor = [1, 1, 1];
    app.ProposedAxes.YColor = [1, 1, 1];
end
```

**Why:** Extracted UI builder. Follows existing pattern (buildAnalyticsTab). Keeps ProspectiveSchedulerApp.m from bloating.

**3.1.3 Call builder in setupUI**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** In setupUI() method (after Analyze tab creation)

**Code to add:**
```matlab
% Create Proposed tab (initially hidden)
conduction.gui.app.buildProposedTab(app, app.CanvasTabGroup);
app.ProposedTab.Parent = [];  % Detach until needed
```

**Why:** Tab created but hidden. Attached on-demand when re-optimization triggered.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Verify Proposed tab components exist but detached
assert(~isempty(app.ProposedTab), 'ProposedTab should exist');
assert(isempty(app.ProposedTab.Parent), 'ProposedTab should be detached initially');
assert(~isempty(app.ProposedAcceptButton), 'Accept button should exist');
assert(~isempty(app.ProposedDiscardButton), 'Discard button should exist');
assert(~isempty(app.ProposedRerunButton), 'Re-run button should exist');
delete(app);
disp('✅ Sub-task 3.1.1-3.1.3 PASSED');
"
```

**Success Criteria:**
- ✅ Proposed tab created
- ✅ Tab initially detached (not visible)
- ✅ Accept, Discard, Re-run buttons exist
- ✅ Summary label and axes exist

**Rollback:** Delete buildProposedTab.m, remove properties, remove builder call.

---

### Sub-Phase 3.2: Show Proposed Tab on Re-optimization

#### Tasks

**3.2.1 Update executeOptimization to show Proposed tab in reopt mode**

**File:** `scripts/+conduction/+gui/+controllers/OptimizationController.m`

**Location:** After successful optimization (after line 128)

**Current code:**
```matlab
app.OptimizedSchedule = dailySchedule;
app.OptimizationOutcome = outcome;
% ... render schedule ...
```

**Replace with:**
```matlab
% In re-optimization mode, store as proposed schedule
if app.isReoptimizationMode()
    app.ProposedSchedule = dailySchedule;
    app.OptimizationOutcome = outcome;  % Keep for drawer

    % Show Proposed tab
    app.showProposedTab();
else
    % Full optimization: apply directly
    app.OptimizedSchedule = dailySchedule;
    app.OptimizationOutcome = outcome;
    app.IsOptimizationDirty = false;
    app.OptimizationLastRun = datetime('now');
    app.markDirty();

    % Render schedule
    obj.renderOptimizationResults(app, dailySchedule, outcome);
end
```

**Why:** Routing logic. Full optimization applies directly, re-optimization opens preview.

**3.2.2 Add showProposedTab() method**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After isReoptimizationMode() method

**Code to add:**
```matlab
function showProposedTab(app)
    % Show Proposed tab with proposed schedule preview

    % Attach tab to tab group
    app.ProposedTab.Parent = app.CanvasTabGroup;

    % Switch to Proposed tab
    app.CanvasTabGroup.SelectedTab = app.ProposedTab;

    % Render proposed schedule
    app.renderProposedSchedule();

    % Update summary
    app.updateProposedSummary();
end
```

**Why:** Encapsulates Proposed tab activation. Centralized in app class.

**3.2.3 Add renderProposedSchedule() method**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After showProposedTab() method

**Code to add:**
```matlab
function renderProposedSchedule(app)
    % Render proposed schedule in Proposed tab axes

    if isempty(app.ProposedSchedule)
        cla(app.ProposedAxes);
        return;
    end

    % Annotate with derived status
    annotatedSchedule = app.ScheduleRenderer.annotateScheduleWithDerivedStatus(app, app.ProposedSchedule);

    % Visualize
    nowMinutes = app.getNowPosition();
    conduction.visualizeDailySchedule(annotatedSchedule, ...
        'Parent', app.ProposedAxes, ...
        'Title', 'Proposed Schedule', ...
        'CurrentTimeMinutes', nowMinutes, ...
        'ShowResourceIndicators', false);

    % NOW line should be read-only in Proposed view (no drag)
    nowLine = findobj(app.ProposedAxes, 'Tag', 'NowLine');
    if ~isempty(nowLine)
        nowLine.ButtonDownFcn = [];  % Disable drag
    end
end
```

**Why:** Renders proposed schedule. Similar to main schedule rendering. NOW line shown but not draggable.

**3.2.4 Add updateProposedSummary() stub**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After renderProposedSchedule() method

**Code to add:**
```matlab
function updateProposedSummary(app)
    % Update summary label in Proposed tab
    % IMPLEMENTED: moved/unchanged/conflicts computed in ProspectiveSchedulerApp.updateProposedSummary

    app.ProposedSummaryLabel.Text = 'Summary: Analyzing changes...';
end
```

**Why:** Stub for summary computation. Implemented in next sub-phase.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Add cases
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
% Optimize
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Should apply directly (not in reopt mode)
assert(~isempty(app.OptimizedSchedule), 'Full optimization should apply directly');
assert(isempty(app.ProposedTab.Parent), 'Proposed tab should not show for full optimization');
% Move NOW to trigger reopt mode
labs = app.OptimizedSchedule.labAssignments();
firstCaseEnd = labs{1}(1).procEndTime;
app.setNowPosition(firstCaseEnd + 10);
% Re-optimize
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Should show Proposed tab
assert(~isempty(app.ProposedTab.Parent), 'Proposed tab should show for re-optimization');
assert(app.CanvasTabGroup.SelectedTab == app.ProposedTab, 'Proposed tab should be selected');
assert(~isempty(app.ProposedSchedule), 'ProposedSchedule should exist');
delete(app);
disp('✅ Sub-task 3.2.1-3.2.4 PASSED');
"
```

**Success Criteria:**
- ✅ Full optimization applies directly (no Proposed tab)
- ✅ Re-optimization shows Proposed tab
- ✅ Proposed schedule rendered in tab
- ✅ NOW line visible but not draggable in Proposed view

**Rollback:** Remove showProposedTab(), renderProposedSchedule(), routing logic from executeOptimization.

---

### Sub-Phase 3.3: Implement Accept/Discard Actions

#### Tasks

**3.3.1 Add onProposedAccept() callback**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After updateProposedSummary() method

**Code to add:**
```matlab
function onProposedAccept(app)
    % Accept proposed schedule and apply changes

    if isempty(app.ProposedSchedule)
        return;
    end

    % Store previous schedule for undo
    app.UndoSchedule = app.OptimizedSchedule;

    % Apply proposed schedule
    app.OptimizedSchedule = app.ProposedSchedule;
    app.IsOptimizationDirty = false;
    app.OptimizationLastRun = datetime('now');
    app.markDirty();

    % Hide Proposed tab
    app.ProposedTab.Parent = [];

    % Switch back to Schedule tab
    app.CanvasTabGroup.SelectedTab = app.ScheduleTab;

    % Render schedule
    schedule = app.getScheduleForRendering();
    app.ScheduleRenderer.renderOptimizedSchedule(app, schedule, app.OptimizationOutcome);

    % Clear proposed schedule
    app.ProposedSchedule = conduction.DailySchedule.empty;

    % Show undo toast
    app.showUndoToast('Remaining cases rescheduled');
end
```

**Why:** Applies proposed changes to main schedule. Stores undo state. Returns to main view.

**3.3.2 Add onProposedDiscard() callback**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After onProposedAccept() method

**Code to add:**
```matlab
function onProposedDiscard(app)
    % Discard proposed schedule and keep current state

    % Store proposed schedule for undo
    app.UndoProposedSchedule = app.ProposedSchedule;

    % Clear proposed schedule
    app.ProposedSchedule = conduction.DailySchedule.empty;

    % Hide Proposed tab
    app.ProposedTab.Parent = [];

    % Switch back to Schedule tab
    app.CanvasTabGroup.SelectedTab = app.ScheduleTab;

    % Show undo toast
    app.showUndoToast('Proposal discarded');
end
```

**Why:** Discards proposed changes. Keeps current schedule. Stores proposal for undo recovery.

**3.3.3 Add undo state properties**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After ProposedSchedule property

**Code to add:**
```matlab
UndoSchedule conduction.DailySchedule  % Previous schedule (for undo after Accept)
UndoProposedSchedule conduction.DailySchedule  % Discarded proposal (for undo after Discard)
```

**Why:** State for single-step undo.

**3.3.4 Add showUndoToast() stub**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After onProposedDiscard() method

**Code to add:**
```matlab
function showUndoToast(app, message)
    % Show toast notification with undo button
    % IMPLEMENTED: see ProspectiveSchedulerApp.showUndoToast + triggerUndoAction

    fprintf('[Undo Toast] %s\n', message);
end
```

**Why:** Stub for undo toast. Implemented in Phase 5.

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Add and optimize
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
originalSchedule = app.OptimizedSchedule;
% Trigger reopt
labs = app.OptimizedSchedule.labAssignments();
firstCaseEnd = labs{1}(1).procEndTime;
app.setNowPosition(firstCaseEnd + 10);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Proposed tab should be visible
assert(~isempty(app.ProposedTab.Parent), 'Proposed tab should be visible');
proposedSchedule = app.ProposedSchedule;
% Test Accept
app.onProposedAccept();
pause(1);
assert(isempty(app.ProposedTab.Parent), 'Proposed tab should be hidden after Accept');
assert(app.OptimizedSchedule == proposedSchedule, 'Optimized schedule should match proposed');
assert(app.UndoSchedule == originalSchedule, 'Undo should store original schedule');
% Test Discard (trigger reopt again)
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
proposedSchedule2 = app.ProposedSchedule;
app.onProposedDiscard();
pause(1);
assert(isempty(app.ProposedTab.Parent), 'Proposed tab should be hidden after Discard');
assert(app.UndoProposedSchedule == proposedSchedule2, 'Undo should store discarded proposal');
delete(app);
disp('✅ Sub-task 3.3.1-3.3.4 PASSED');
"
```

**Success Criteria:**
- ✅ Accept applies proposed schedule
- ✅ Accept hides Proposed tab and returns to Schedule tab
- ✅ Accept stores undo state
- ✅ Discard keeps current schedule
- ✅ Discard hides Proposed tab
- ✅ Discard stores proposal for undo

**Rollback:** Remove callbacks, remove undo properties, remove stub.

---

### Sub-Phase 3.4: Add Re-run Options Stub

#### Tasks

**3.4.1 Add onProposedRerun() callback stub**

**File:** `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`

**Location:** After showUndoToast() method

**Code to add:**
```matlab
function onProposedRerun(app)
    % Re-run optimization with adjusted scope/options
    % IMPLEMENTED: scope controls available; see onScopeIncludeChanged/RespectLocks/PreferLabs

    % For now, just re-run optimization
    app.OptimizationController.executeOptimization(app);
end
```

**Why:** Placeholder for re-run with options. Full implementation in Phase 4 (scope controls).

**Testing:**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
app = conduction.launchSchedulerGUI();
pause(2);
% Setup and trigger reopt
for i = 1:3
    app.OperatorField.Value = sprintf('Operator%d', i);
    app.ProcedureField.Value = sprintf('Procedure%d', i);
    app.ProcedureTimeField.Value = 60;
    app.AddCaseButton.ButtonPushedFcn(app.AddCaseButton, []);
end
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
labs = app.OptimizedSchedule.labAssignments();
firstCaseEnd = labs{1}(1).procEndTime;
app.setNowPosition(firstCaseEnd + 10);
app.OptimizationRunButton.ButtonPushedFcn(app.OptimizationRunButton, []);
pause(2);
% Test Re-run (should regenerate proposal)
oldProposal = app.ProposedSchedule;
app.onProposedRerun();
pause(2);
% Should regenerate proposal (may be same or different depending on solver)
assert(~isempty(app.ProposedSchedule), 'Re-run should generate new proposal');
delete(app);
disp('✅ Sub-task 3.4.1 PASSED');
"
```

**Success Criteria:**
- ✅ Re-run button triggers optimization
- ✅ New proposal generated

**Rollback:** Remove onProposedRerun() stub.

---

### Phase 3 Summary

**What Changed:**
1. ✅ Proposed tab UI created (initially hidden)
2. ✅ Re-optimization shows Proposed tab instead of applying directly
3. ✅ Accept applies proposed schedule
4. ✅ Discard keeps current schedule
5. ✅ Re-run regenerates proposal
6. ✅ Undo state stored (toast UI in Phase 5)

**Files Modified:**
- `ProspectiveSchedulerApp.m` - Added Proposed tab properties, show/hide logic, Accept/Discard/Re-run callbacks
- `buildProposedTab.m` (NEW) - Proposed tab UI builder
- `OptimizationController.m` - Routing logic (reopt → Proposed tab, full → direct apply)

**Lines Changed:** ~150 additions

**Testing:** All sub-tasks tested via CLI

**Next:** Phase 4 will add scope controls for re-optimization options.

---

## Phase 4: Progressive Disclosure

**Goal:** Show/hide features based on context. Add scope controls, helper buttons.

**Estimated Duration:** 2-3 days
**Risk Level:** LOW (mostly UI visibility logic)
**Status:** COMPLETE

### Tasks

**4.1 Add scope controls UI (collapsible section in Optimization panel)**
**4.2 Show scope controls when NOW > first case**
**4.3 Add "Advance NOW to Actual Time" button**
**4.4 Add "Reset to Planning Mode" button**
**4.5 Add feature hints and tooltips**

*(Detailed task breakdown similar to Phases 1-3)*

---

## Phase 5: Polish & Testing

**Goal:** Edge case handling, performance optimization, accessibility, user testing.

**Estimated Duration:** 3-5 days
**Risk Level:** LOW
**Status:** IN PROGRESS

### Tasks

**5.1 Implement undo toast UI** — COMPLETE (ProspectiveSchedulerApp.showUndoToast + undo actions)
**5.2 Add staleness detection for Proposed tab** — COMPLETE (ProposedStaleBanner + refreshProposedStalenessBanner)
**5.3 Add summary computation (moved/unchanged/conflicts)** — COMPLETE (updateProposedSummary)
**5.4 Comprehensive edge case testing**
**5.5 Performance optimization (large schedules, frequent NOW drags)**
**5.6 Accessibility audit (keyboard navigation, screen readers)**
**5.7 Session save/load migration**
**5.8 Documentation and help content**

*(Detailed task breakdown similar to Phases 1-3)*

---

## Testing Strategy

### Unit Testing (Per Sub-Task)
Each sub-task includes CLI test script using MATLAB batch mode:
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "test_script_here"
```

### Integration Testing (Per Phase)
After each phase, run comprehensive integration test:
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
addpath(genpath('tests'));
results = runtests('tests/integration/unified_timeline_test.m');
disp(results);
exit(~all([results.Passed]));
"
```

### Regression Testing
Run existing test suite after each phase:
```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "
cd('$(pwd)');
addpath(genpath('tests'));
results = runtests('tests/save_load');
disp(results);
exit(~all([results.Passed]));
"
```

### Manual Testing Checklist
After each phase, manually verify:
- ✅ GUI launches without errors
- ✅ NOW line visible and draggable
- ✅ Case status updates on NOW drag
- ✅ Optimization completes successfully
- ✅ Schedule renders correctly
- ✅ Session save/load works
- ✅ No console errors or warnings

---

## Rollback Procedures

### Immediate Rollback (Within Same Session)
```bash
git reset --hard HEAD~1  # Undo last commit
```

### Rollback to Specific Phase
```bash
git log --oneline  # Find commit hash before phase
git reset --hard <commit_hash>
```

### Rollback All Changes
```bash
git reset --hard origin/separate-completed-case-logic
```

### Preserve Work While Rolling Back
```bash
git branch backup-unified-timeline  # Save current work
git reset --hard <safe_commit>  # Rollback
```

---

## Progress Tracking

### Phase Completion Checklist

- [ ] **Phase 0: Analysis & Preparation** ✅ COMPLETE
- [ ] **Phase 1: Foundation - Unify Timeline**
  - [ ] Sub-Phase 1.1: Add NOW Position to App State
  - [ ] Sub-Phase 1.2: Always Show NOW Line
  - [ ] Sub-Phase 1.3: Derive Status from NOW Position
  - [ ] Sub-Phase 1.4: Unify Schedule Objects
  - [ ] Sub-Phase 1.5: Simplify Lock Management
  - [ ] Sub-Phase 1.6: Update Lock Extraction
  - [ ] Sub-Phase 1.7: Remove Time Control Toggle UI
- [ ] **Phase 2: Smart Optimize Button**
  - [ ] Sub-Phase 2.1: Add Button Label Logic
  - [ ] Sub-Phase 2.2: Add Re-optimization Mode Flag
  - [ ] Sub-Phase 2.3: Filter Cases by NOW Position
- [ ] **Phase 3: Proposed Tab Workflow**
  - [ ] Sub-Phase 3.1: Create Proposed Tab Structure
  - [ ] Sub-Phase 3.2: Show Proposed Tab on Re-optimization
  - [ ] Sub-Phase 3.3: Implement Accept/Discard Actions
  - [ ] Sub-Phase 3.4: Add Re-run Options Stub
- [ ] **Phase 4: Progressive Disclosure**
- [ ] **Phase 5: Polish & Testing**

### Metrics
- **Total Files to Modify:** ~10 core files
- **Total New Files:** ~5 utilities
- **Estimated Lines Changed:** ~500 additions, ~200 deletions
- **Test Coverage:** 100% of sub-tasks have CLI tests

---

## Notes

### Design Decisions
- **Why per-case lock flags instead of arrays?** More modular, easier to serialize, clearer ownership.
- **Why keep IsTimeControlActive = true?** Gradual migration. Some code still checks this flag. Will remove entirely in Phase 2.
- **Why Proposed tab instead of modal?** Richer visualization, less blocking, aligns with Analyze tab pattern.
- **Why derive status instead of store?** Single source of truth (NOW position). Eliminates sync bugs.

### Performance Considerations
- **Frequent NOW drags:** annotateScheduleWithDerivedStatus() called on every drag. Optimize by caching if > 50 cases.
- **Large schedules:** Status computation is O(n). Consider indexing if > 100 cases.

### Future Enhancements
- Multi-step undo/redo
- Comparison view (original vs proposed)
- Auto-advance NOW modes
- Keyboard shortcuts for NOW line nudging

---

**End of Implementation Plan**

This plan will be updated as phases complete. Each completed sub-task will be marked with ✅ and date.
