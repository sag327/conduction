# Save/Load Session Implementation Plan

## Overview

This document outlines the implementation plan for adding save/load session functionality to the Conduction prospective scheduler GUI. The feature will allow users to:

- Save complete application state to `.mat` files
- Load previously saved sessions
- Auto-save sessions periodically
- Track unsaved changes (dirty flag)
- Preserve all case data, optimization results, and UI state

**Key Design Decisions:**
- Use struct-based serialization for reliability and version compatibility
- Store sessions in `.mat` files for MATLAB compatibility
- Support auto-save with configurable intervals
- Include version metadata for future migration
- Handle missing historical data gracefully

## Architecture

### Data Flow

```
App State → exportAppState() → SessionData struct → saveSessionToFile() → .mat file
                                                    ↓
.mat file → loadSessionFromFile() → SessionData struct → importAppState() → App State
```

### Core Components

1. **Serialization Layer** (`+conduction/+session/`)
   - Convert objects to/from structs
   - Handle complex types (Map, handle classes)
   - Validate data integrity

2. **State Management**
   - `exportAppState()` - extract all saveable data
   - `importAppState()` - restore app from data
   - Dirty flag tracking

3. **File I/O**
   - Save/load with version validation
   - Default sessions directory
   - Auto-save with rotation

4. **UI Integration**
   - Save/Load buttons
   - Auto-save checkbox
   - User feedback (dialogs, messages)

## Session Data Structure

### SessionData Struct Schema

```matlab
SessionData = struct(...
    'version', string,              % Format version (e.g., '1.0.0')
    'appVersion', string,           % App version when saved
    'savedDate', datetime,          % When session was saved
    'targetDate', datetime,         % Target date for scheduling
    'userNotes', string,            % Optional user notes

    % Case data
    'cases', struct array,          % Serialized ProspectiveCase objects
    'completedCases', struct array, % Completed cases archive

    % Schedule data
    'optimizedSchedule', struct,    % Serialized DailySchedule
    'simulatedSchedule', struct,    % Simulated schedule (time control)
    'optimizationOutcome', struct,  % Optimization metadata

    % Configuration
    'opts', struct,                 % Optimization options
    'labIds', double array,         % Lab IDs (e.g., [1,2,3,4,5,6])
    'availableLabIds', double array,% Labs open for reassignment

    % UI State
    'lockedCaseIds', string array,  % Locked case IDs
    'timeControlState', struct,     % Time control mode state
    'operatorColors', struct,       % Operator color mapping
    'isOptimizationDirty', logical, % Schedule needs re-optimization

    % Historical data reference
    'historicalDataPath', string    % Path to historical collection
);
```

### Serialized Case Struct

```matlab
CaseStruct = struct(...
    'operatorName', string,
    'procedureName', string,
    'estimatedDurationMinutes', double,
    'admissionStatus', string,
    'specificLab', string,
    'isFirstCaseOfDay', logical,
    'caseStatus', string,
    'isLocked', logical
);
```

### Serialized DailySchedule Struct

```matlab
ScheduleStruct = struct(...
    'date', datetime,
    'labs', struct array,           % Serialized Lab objects
    'labAssignments', cell array,   % Per-lab case assignments
    'metrics', struct               % Schedule metrics
);
```

### Time Control State Struct

```matlab
TimeControlState = struct(...
    'isActive', logical,
    'currentTimeMinutes', double,
    'baselineLockedIds', string array,
    'lockedCaseIds', string array
);
```

## Implementation Progress

### Stages Checklist

- [x] **Stage 0:** Documentation & Test Infrastructure ✅ (Completed 2025-10-08)
- [x] **Stage 1:** Serialization Layer ✅ (Completed 2025-10-08)
- [x] **Stage 2:** State Extraction ✅ (Completed 2025-10-08)
- [x] **Stage 3:** State Restoration ✅ (Completed 2025-10-08)
- [ ] **Stage 4:** File I/O
- [ ] **Stage 5:** UI Integration - Save
- [ ] **Stage 6:** UI Integration - Load
- [ ] **Stage 7:** Dirty Flag Tracking
- [ ] **Stage 8:** Auto-save
- [ ] **Stage 9:** Error Handling & Edge Cases
- [ ] **Stage 10:** Documentation & Polish

---

## Stage 0: Documentation & Test Infrastructure

**Goal:** Set up documentation and testing framework before coding

### Tasks
- [x] Create this implementation guide
- [x] Create test directory structure: `tests/save_load/`
- [x] Create test helper functions
- [x] Document example session data structures
- [x] Create verification tests for all helper functions
- [x] Fix issues discovered during testing

### Testing
- [x] Verify documentation is clear and complete
- [x] Create example SessionData struct for reference
- [x] Created `test_stage0_helpers.m` with 10 verification tests
- [x] All tests passing ✅

### Deliverables
- ✅ Implementation guide (this file)
- ✅ Test infrastructure ready (`tests/save_load/helpers/`)
- ✅ Example data structures documented (`example_session_data.md`)
- ✅ 6 helper functions created and tested
- ✅ Verification test suite passing

### Issues Found & Fixed
- `ProspectiveCase` constructor doesn't accept duration parameter - use `updateDuration()` method
- `Lab` constructor requires `room` and `location` parameters
- `CaseManager.Cases` is private - use public `getCase()` method

**Actual Time:** ~60 minutes

**Status:** ✅ COMPLETE (2025-10-08)

---

## Stage 1: Serialization Layer

**Goal:** Create utilities to convert app state to/from saveable structs

### Tasks

#### Create Package Structure
```matlab
+conduction/
  +session/
    SessionData.m              % Struct validation
    serializeProspectiveCase.m
    deserializeProspectiveCase.m
    serializeDailySchedule.m
    deserializeDailySchedule.m
    serializeLab.m
    deserializeLab.m
    serializeOperatorColors.m
    deserializeOperatorColors.m
```

#### Implementation Details

1. **`serializeProspectiveCase(case)`**
   - Input: ProspectiveCase object
   - Output: Struct with all case properties
   - Handle empty/missing fields

2. **`deserializeProspectiveCase(struct)`**
   - Input: Case struct
   - Output: ProspectiveCase object
   - Validate required fields
   - Use defaults for missing optional fields

3. **`serializeDailySchedule(schedule)`**
   - Input: DailySchedule object
   - Output: Struct with date, labs, assignments, metrics
   - Recursively serialize Lab objects
   - Handle empty schedule

4. **`deserializeDailySchedule(struct)`**
   - Input: Schedule struct
   - Output: DailySchedule object
   - Reconstruct Lab objects
   - Validate data integrity

5. **`serializeOperatorColors(map)`**
   - Input: containers.Map
   - Output: Struct with keys and values arrays
   - Handle empty map

6. **`deserializeOperatorColors(struct)`**
   - Input: Struct with keys/values
   - Output: containers.Map
   - Reconstruct color mapping

### Testing Strategy

```matlab
% Test: Case serialization roundtrip
testCase = conduction.gui.models.ProspectiveCase(...
    'Dr. Smith', 'Procedure A', 60);
testCase.IsLocked = true;
testCase.CaseStatus = "in_progress";

caseStruct = conduction.session.serializeProspectiveCase(testCase);
reconstructed = conduction.session.deserializeProspectiveCase(caseStruct);

assert(strcmp(reconstructed.OperatorName, testCase.OperatorName));
assert(reconstructed.EstimatedDurationMinutes == testCase.EstimatedDurationMinutes);
assert(reconstructed.IsLocked == testCase.IsLocked);
assert(reconstructed.CaseStatus == testCase.CaseStatus);

% Test: Schedule serialization roundtrip
% (Similar pattern for all serializers)

% Test: Edge cases
- Empty case arrays
- NaT dates
- Missing optional fields
- Invalid data types
```

### Deliverables
- ✅ Serialization utilities package complete (`+conduction/+session/`)
- ✅ 8 serialization functions implemented
- ✅ 10 unit tests passing (all roundtrip tests passing)

### What Was Built
- `serializeProspectiveCase / deserializeProspectiveCase` - Case object serialization with all properties
- `serializeLab / deserializeLab` - Lab object serialization
- `serializeDailySchedule / deserializeDailySchedule` - Complete schedule serialization
- `serializeOperatorColors / deserializeOperatorColors` - Map to struct conversion

### Test Results
✅ All 10 tests passing:
1. ProspectiveCase roundtrip
2. Array of ProspectiveCases
3. Empty ProspectiveCase array
4. Lab roundtrip
5. Array of Labs
6. OperatorColors Map roundtrip
7. Empty OperatorColors Map
8. DailySchedule roundtrip
9. Empty DailySchedule
10. Missing optional fields handling

**Time Estimate:** 2-3 hours
**Actual Time:** ~2 hours
**Status:** ✅ COMPLETE (2025-10-08)

---

## Stage 2: State Extraction

**Goal:** Extract all saveable state from app into SessionData struct

### Tasks

1. **Add method to ProspectiveSchedulerApp.m**
   ```matlab
   function sessionData = exportAppState(app)
   ```

2. **Extract each data category:**
   - Version and metadata
   - Case list from CaseManager
   - Optimization state (schedule, outcome, settings)
   - UI state (dates, flags, IDs)
   - Time control state
   - Operator colors

3. **Create SessionData struct**
   - Populate all fields
   - Use serialization functions from Stage 1
   - Include validation

### Implementation Outline

```matlab
function sessionData = exportAppState(app)
    % Version info
    versionInfo = conduction.version();

    % Initialize struct
    sessionData = struct();
    sessionData.version = '1.0.0';  % Session format version
    sessionData.appVersion = versionInfo.Version;
    sessionData.savedDate = datetime('now');
    sessionData.targetDate = app.TargetDate;
    sessionData.userNotes = '';

    % Serialize cases
    sessionData.cases = conduction.session.serializeProspectiveCase(...
        app.CaseManager.Cases);
    sessionData.completedCases = conduction.session.serializeProspectiveCase(...
        app.CaseManager.CompletedCases);

    % Serialize schedules
    if ~isempty(app.OptimizedSchedule)
        sessionData.optimizedSchedule = ...
            conduction.session.serializeDailySchedule(app.OptimizedSchedule);
    else
        sessionData.optimizedSchedule = struct();
    end

    if ~isempty(app.SimulatedSchedule)
        sessionData.simulatedSchedule = ...
            conduction.session.serializeDailySchedule(app.SimulatedSchedule);
    else
        sessionData.simulatedSchedule = struct();
    end

    % Optimization state
    sessionData.optimizationOutcome = app.OptimizationOutcome;
    sessionData.opts = app.Opts;

    % Lab configuration
    sessionData.labIds = app.LabIds;
    sessionData.availableLabIds = app.AvailableLabIds;

    % UI state
    sessionData.lockedCaseIds = app.LockedCaseIds;
    sessionData.isOptimizationDirty = app.IsOptimizationDirty;

    % Time control state
    sessionData.timeControlState = struct(...
        'isActive', app.IsTimeControlActive, ...
        'currentTimeMinutes', app.CaseManager.getCurrentTime(), ...
        'baselineLockedIds', app.TimeControlBaselineLockedIds, ...
        'lockedCaseIds', app.TimeControlLockedCaseIds);

    % Operator colors
    sessionData.operatorColors = ...
        conduction.session.serializeOperatorColors(app.OperatorColors);

    % Historical data reference
    if ~isempty(app.CaseManager.HistoricalCollection)
        % Try to extract path if available
        sessionData.historicalDataPath = "";
    else
        sessionData.historicalDataPath = "";
    end
end
```

### Testing Strategy

```matlab
% Test 1: Extract state from empty app
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = app.exportAppState();
assert(isfield(sessionData, 'version'));
assert(isfield(sessionData, 'targetDate'));
assert(isempty(sessionData.cases));

% Test 2: Extract state with cases
app = conduction.gui.ProspectiveSchedulerApp();
app.CaseManager.addCase('Dr. A', 'Proc B', 60);
app.CaseManager.addCase('Dr. C', 'Proc D', 45);
sessionData = app.exportAppState();
assert(length(sessionData.cases) == 2);

% Test 3: Extract state with optimized schedule
% (Add cases, run optimization, then export)

% Test 4: Extract locked case state
% (Lock cases, then export)

% Test 5: Time control state
% (Enable time control, then export)
```

### Deliverables
- ✅ `exportAppState()` method working
- ✅ 10 integration tests passing (all tests passing)
- ✅ Complete SessionData struct populated

### What Was Built
- `exportAppState()` method in ProspectiveSchedulerApp.m - extracts all app state into SessionData struct
- Uses serialization functions from Stage 1 for cases, schedules, and operator colors
- Handles empty states gracefully
- Extracts all required fields: version info, cases, schedules, optimization state, UI state, time control state, operator colors

### Test Results
✅ All 10 tests passing:
1. Extract state from empty app
2. Extract state with cases
3. Extract state with various case properties
4. Extract optimization state
5. Extract UI state
6. Extract time control state
7. Extract operator colors
8. Extract metadata fields
9. Extract target date
10. Verify all required fields present

### Issues Found & Fixed
- `CaseManager.CompletedCases` is private - use `getCompletedCases()` method
- `CaseManager.HistoricalCollection` is private - use `getHistoricalCollection()` method

**Time Estimate:** 1-2 hours
**Actual Time:** ~1 hour
**Status:** ✅ COMPLETE (2025-10-08)

---

## Stage 3: State Restoration

**Goal:** Restore app state from SessionData struct

### Tasks

1. **Add method to ProspectiveSchedulerApp.m**
   ```matlab
   function importAppState(app, sessionData)
   ```

2. **Clear existing state safely**
   - Clear cases
   - Clear schedules
   - Reset UI state

3. **Restore each data category:**
   - Validate version compatibility
   - Restore target date
   - Restore cases to CaseManager
   - Restore schedules
   - Restore optimization state
   - Restore UI state
   - Restore time control state
   - Restore operator colors

4. **Trigger UI updates**
   - Update date picker
   - Update cases table
   - Re-render schedule
   - Update KPIs

### Implementation Outline

```matlab
function importAppState(app, sessionData)
    % Validate session data
    if ~isfield(sessionData, 'version')
        error('Invalid session data: missing version field');
    end

    % Version compatibility check
    if sessionData.version ~= '1.0.0'
        warning('Session version %s may be incompatible with current version', ...
            sessionData.version);
    end

    % Clear current state
    app.CaseManager.clearAllCases();
    app.OptimizedSchedule = conduction.DailySchedule.empty;
    app.SimulatedSchedule = conduction.DailySchedule.empty;
    app.LockedCaseIds = string.empty;

    % Restore target date
    app.TargetDate = sessionData.targetDate;
    app.DatePicker.Value = sessionData.targetDate;

    % Restore cases
    if isfield(sessionData, 'cases') && ~isempty(sessionData.cases)
        for i = 1:length(sessionData.cases)
            caseObj = conduction.session.deserializeProspectiveCase(...
                sessionData.cases(i));
            % Add to CaseManager (may need special method to preserve state)
            app.CaseManager.Cases(end+1) = caseObj;
        end
    end

    % Restore completed cases
    if isfield(sessionData, 'completedCases') && ~isempty(sessionData.completedCases)
        for i = 1:length(sessionData.completedCases)
            caseObj = conduction.session.deserializeProspectiveCase(...
                sessionData.completedCases(i));
            app.CaseManager.CompletedCases(end+1) = caseObj;
        end
    end

    % Restore schedules
    if isfield(sessionData, 'optimizedSchedule') && ...
            ~isempty(fieldnames(sessionData.optimizedSchedule))
        app.OptimizedSchedule = conduction.session.deserializeDailySchedule(...
            sessionData.optimizedSchedule);
    end

    if isfield(sessionData, 'simulatedSchedule') && ...
            ~isempty(fieldnames(sessionData.simulatedSchedule))
        app.SimulatedSchedule = conduction.session.deserializeDailySchedule(...
            sessionData.simulatedSchedule);
    end

    % Restore optimization state
    if isfield(sessionData, 'optimizationOutcome')
        app.OptimizationOutcome = sessionData.optimizationOutcome;
    end

    if isfield(sessionData, 'opts')
        app.Opts = sessionData.opts;
        % Update UI controls with loaded options
        app.OptimizationController.syncOptsToUI(app);
    end

    % Restore lab configuration
    if isfield(sessionData, 'labIds')
        app.LabIds = sessionData.labIds;
    end

    if isfield(sessionData, 'availableLabIds')
        app.AvailableLabIds = sessionData.availableLabIds;
        % Update available labs checkboxes
        app.buildAvailableLabCheckboxes();
    end

    % Restore UI state
    if isfield(sessionData, 'lockedCaseIds')
        app.LockedCaseIds = sessionData.lockedCaseIds;
    end

    if isfield(sessionData, 'isOptimizationDirty')
        app.IsOptimizationDirty = sessionData.isOptimizationDirty;
    end

    % Restore time control state
    if isfield(sessionData, 'timeControlState')
        tcs = sessionData.timeControlState;
        if isfield(tcs, 'isActive') && tcs.isActive
            % May need to restore time control state
            app.TimeControlBaselineLockedIds = tcs.baselineLockedIds;
            app.TimeControlLockedCaseIds = tcs.lockedCaseIds;
            if isfield(tcs, 'currentTimeMinutes') && ~isnan(tcs.currentTimeMinutes)
                app.CaseManager.setCurrentTime(tcs.currentTimeMinutes);
            end
        end
    end

    % Restore operator colors
    if isfield(sessionData, 'operatorColors')
        app.OperatorColors = conduction.session.deserializeOperatorColors(...
            sessionData.operatorColors);
    end

    % Trigger UI updates
    app.updateCasesTable();
    app.OptimizationController.updateOptimizationOptionsSummary(app);

    % Re-render schedule
    if ~isempty(app.OptimizedSchedule)
        conduction.gui.app.redrawSchedule(app, app.OptimizedSchedule, ...
            app.OptimizationOutcome);
    else
        app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
    end

    % Notify user
    fprintf('Session loaded successfully from %s\n', ...
        datestr(sessionData.savedDate, 'yyyy-mm-dd HH:MM:SS'));
end
```

### Testing Strategy

```matlab
% Test 1: Full roundtrip - empty app
app1 = conduction.gui.ProspectiveSchedulerApp();
sessionData = app1.exportAppState();
app2 = conduction.gui.ProspectiveSchedulerApp();
app2.importAppState(sessionData);
assert(app1.TargetDate == app2.TargetDate);

% Test 2: Full roundtrip - app with cases
app1 = conduction.gui.ProspectiveSchedulerApp();
app1.CaseManager.addCase('Dr. A', 'Proc B', 60);
app1.CaseManager.addCase('Dr. C', 'Proc D', 45);
sessionData = app1.exportAppState();
app2 = conduction.gui.ProspectiveSchedulerApp();
app2.importAppState(sessionData);
assert(app2.CaseManager.CaseCount == 2);

% Test 3: Full roundtrip - optimized schedule
% (Complete workflow test)

% Test 4: Partial data (missing optional fields)
sessionData = struct();
sessionData.version = '1.0.0';
sessionData.targetDate = datetime('2025-01-15');
sessionData.cases = [];
app = conduction.gui.ProspectiveSchedulerApp();
app.importAppState(sessionData); % Should not error
```

### Deliverables
- ✅ `importAppState()` method working
- ✅ Full roundtrip tests passing (all 10 tests passing)
- ✅ Handles missing/optional fields gracefully

### What Was Built
- `importAppState()` method in ProspectiveSchedulerApp.m - restores all app state from SessionData struct
- Version validation and compatibility checking
- Safe state clearing before restoration
- Proper handling of all data categories: cases, schedules, optimization state, UI state, time control state, operator colors
- Triggers UI updates after restoration
- Gracefully handles missing optional fields (like savedDate)

### Test Results
✅ All 10 tests passing:
1. Full roundtrip - empty app
2. Full roundtrip - app with cases
3. Restore case properties (admission status, first case flag, specific lab, locked flag)
4. Restore target date
5. Restore optimization state
6. Restore lab configuration
7. Restore UI state
8. Restore time control state
9. Restore operator colors
10. Handle partial/missing data gracefully

### Issues Found & Fixed
- Need to handle missing `savedDate` field in partial session data
- Note: Completed cases restoration not fully implemented (requires additional CaseManager method)

**Time Estimate:** 2-3 hours
**Actual Time:** ~1.5 hours
**Status:** ✅ COMPLETE (2025-10-08)

---

## Stage 4: File I/O

**Goal:** Save/load SessionData to/from .mat files

### Tasks

1. **Create file I/O functions in `+conduction/+session/`**
   ```matlab
   saveSessionToFile(sessionData, filepath)
   loadSessionFromFile(filepath)
   ```

2. **Implement save with safety features:**
   - Backup existing file before overwrite
   - Validate filepath
   - Handle write errors

3. **Implement load with validation:**
   - Check file exists
   - Validate .mat format
   - Version checking
   - Handle corrupt files

4. **Create default sessions directory**
   - `./sessions/` folder
   - Auto-create if missing

5. **Filename generation utility**
   - Format: `session_YYYY-MM-DD_HHmmss.mat`
   - Based on target date

### Implementation

```matlab
function saveSessionToFile(sessionData, filepath)
    % Validate inputs
    if ~isstruct(sessionData)
        error('sessionData must be a struct');
    end

    if ~ischar(filepath) && ~isstring(filepath)
        error('filepath must be a string or char array');
    end

    % Ensure .mat extension
    [pathstr, name, ext] = fileparts(filepath);
    if isempty(ext)
        filepath = fullfile(pathstr, [name '.mat']);
    end

    % Backup existing file
    if isfile(filepath)
        backupPath = [filepath '.backup'];
        copyfile(filepath, backupPath);
    end

    % Save to file
    try
        save(filepath, 'sessionData', '-v7.3');
    catch ME
        error('Failed to save session: %s', ME.message);
    end
end

function sessionData = loadSessionFromFile(filepath)
    % Check file exists
    if ~isfile(filepath)
        error('Session file not found: %s', filepath);
    end

    % Load file
    try
        loaded = load(filepath, 'sessionData');
    catch ME
        error('Failed to load session file: %s', ME.message);
    end

    % Validate structure
    if ~isfield(loaded, 'sessionData')
        error('Invalid session file: missing sessionData variable');
    end

    sessionData = loaded.sessionData;

    % Version validation
    if ~isfield(sessionData, 'version')
        warning('Session file missing version field - may be incompatible');
    elseif sessionData.version ~= '1.0.0'
        warning('Session version %s may be incompatible', sessionData.version);
    end
end

function filepath = generateSessionFilename(targetDate, basePath)
    % Generate filename from target date
    if nargin < 2
        basePath = './sessions';
    end

    % Create directory if needed
    if ~isfolder(basePath)
        mkdir(basePath);
    end

    % Format filename
    dateStr = datestr(targetDate, 'yyyy-mm-dd');
    timeStr = datestr(datetime('now'), 'HHMMss');
    filename = sprintf('session_%s_%s.mat', dateStr, timeStr);
    filepath = fullfile(basePath, filename);
end
```

### Testing Strategy

```matlab
% Test 1: Save and load file
sessionData = struct('version', '1.0.0', 'targetDate', datetime('2025-01-15'));
filepath = tempname();
conduction.session.saveSessionToFile(sessionData, filepath);
assert(isfile([filepath '.mat']));
loaded = conduction.session.loadSessionFromFile([filepath '.mat']);
assert(isequal(loaded.version, sessionData.version));
delete([filepath '.mat']);

% Test 2: Invalid file
try
    loaded = conduction.session.loadSessionFromFile('nonexistent.mat');
    assert(false, 'Should have thrown error');
catch ME
    assert(contains(ME.message, 'not found'));
end

% Test 3: Backup on overwrite
sessionData1 = struct('version', '1.0.0', 'data', 1);
filepath = tempname();
conduction.session.saveSessionToFile(sessionData1, filepath);
sessionData2 = struct('version', '1.0.0', 'data', 2);
conduction.session.saveSessionToFile(sessionData2, filepath);
assert(isfile([filepath '.mat.backup']));
delete([filepath '.mat']);
delete([filepath '.mat.backup']);

% Test 4: Filename generation
filepath = conduction.session.generateSessionFilename(datetime('2025-01-15'));
assert(contains(filepath, 'session_2025-01-15'));
assert(contains(filepath, '.mat'));
```

### Deliverables
- File save/load functions working
- Version validation implemented
- Backup mechanism working
- Error handling for file I/O

**Time Estimate:** 1-2 hours

---

## Stage 5: UI Integration - Save

**Goal:** Add Save button and functionality to GUI

### Tasks

1. **Add Save Session button to top bar**
   - Position next to "Load Baseline Data"
   - Icon/text: "Save Session"
   - Tooltip: "Save current session to file"

2. **Implement `saveSession()` callback**
   - Show `uiputfile` dialog
   - Default filename from date
   - Call `exportAppState()` and `saveSessionToFile()`
   - Show success/error message

3. **Add keyboard shortcut**
   - Ctrl+S (or Cmd+S on Mac)

### Implementation

```matlab
% In ProspectiveSchedulerApp.m setupUI():

% Add Save Session button
app.SaveSessionButton = uibutton(app.TopBarLayout, 'push');
app.SaveSessionButton.Text = 'Save Session';
app.SaveSessionButton.Layout.Column = 3;  % Adjust as needed
app.SaveSessionButton.ButtonPushedFcn = createCallbackFcn(app, @SaveSessionButtonPushed, true);
app.SaveSessionButton.Tooltip = 'Save current session to file (Ctrl+S)';

% Callback method:
function SaveSessionButtonPushed(app, event)
    % Generate default filename
    defaultName = conduction.session.generateSessionFilename(app.TargetDate);
    [~, defaultFile, ~] = fileparts(defaultName);

    % Show file dialog
    [filename, pathname] = uiputfile('*.mat', 'Save Session', defaultFile);

    if isequal(filename, 0)
        % User cancelled
        return;
    end

    filepath = fullfile(pathname, filename);

    try
        % Export app state
        sessionData = app.exportAppState();

        % Save to file
        conduction.session.saveSessionToFile(sessionData, filepath);

        % Mark as clean
        app.IsDirty = false;

        % Success message
        uialert(app.UIFigure, sprintf('Session saved to:\n%s', filepath), ...
            'Session Saved', 'Icon', 'success');

    catch ME
        % Error dialog
        uialert(app.UIFigure, sprintf('Failed to save session:\n%s', ME.message), ...
            'Save Error', 'Icon', 'error');
    end
end
```

### Testing Strategy

```matlab
% Manual Test 1: Click Save button
% - Add some cases
% - Click "Save Session"
% - Dialog appears with default filename
% - Save file
% - Success message shows
% - File created correctly

% Manual Test 2: Cancel save
% - Click "Save Session"
% - Cancel in dialog
% - No file created, no error

% Manual Test 3: Keyboard shortcut
% - Press Ctrl+S (Cmd+S)
% - Save dialog appears

% Automated Test: Programmatic save
app = conduction.gui.ProspectiveSchedulerApp();
app.CaseManager.addCase('Dr. A', 'Proc B', 60);
testFile = tempname();
% Simulate save (without dialog)
sessionData = app.exportAppState();
conduction.session.saveSessionToFile(sessionData, testFile);
assert(isfile([testFile '.mat']));
```

### Deliverables
- Save button in UI
- Save dialog working
- Success/error messages
- Keyboard shortcut functional

**Time Estimate:** 1 hour

---

## Stage 6: UI Integration - Load

**Goal:** Add Load button and functionality to GUI

### Tasks

1. **Add Load Session button to top bar**
   - Position next to "Save Session"
   - Icon/text: "Load Session"
   - Tooltip: "Load a saved session"

2. **Implement `loadSession()` callback**
   - Check for unsaved changes (dirty flag)
   - Show warning if dirty
   - Show `uigetfile` dialog
   - Call `loadSessionFromFile()` and `importAppState()`
   - Show success/error message

3. **Add keyboard shortcut**
   - Ctrl+O (or Cmd+O on Mac)

### Implementation

```matlab
% In ProspectiveSchedulerApp.m setupUI():

% Add Load Session button
app.LoadSessionButton = uibutton(app.TopBarLayout, 'push');
app.LoadSessionButton.Text = 'Load Session';
app.LoadSessionButton.Layout.Column = 4;  % Adjust as needed
app.LoadSessionButton.ButtonPushedFcn = createCallbackFcn(app, @LoadSessionButtonPushed, true);
app.LoadSessionButton.Tooltip = 'Load a saved session (Ctrl+O)';

% Callback method:
function LoadSessionButtonPushed(app, event)
    % Check for unsaved changes
    if app.IsDirty
        answer = uiconfirm(app.UIFigure, ...
            'You have unsaved changes. Continue loading?', ...
            'Unsaved Changes', ...
            'Options', {'Load Anyway', 'Cancel'}, ...
            'DefaultOption', 'Cancel', ...
            'Icon', 'warning');

        if strcmp(answer, 'Cancel')
            return;
        end
    end

    % Show file dialog
    [filename, pathname] = uigetfile('*.mat', 'Load Session', './sessions/');

    if isequal(filename, 0)
        % User cancelled
        return;
    end

    filepath = fullfile(pathname, filename);

    try
        % Load from file
        sessionData = conduction.session.loadSessionFromFile(filepath);

        % Import app state
        app.importAppState(sessionData);

        % Mark as clean
        app.IsDirty = false;

        % Success message
        uialert(app.UIFigure, sprintf('Session loaded from:\n%s', filepath), ...
            'Session Loaded', 'Icon', 'success');

    catch ME
        % Error dialog
        uialert(app.UIFigure, sprintf('Failed to load session:\n%s', ME.message), ...
            'Load Error', 'Icon', 'error');
    end
end
```

### Testing Strategy

```matlab
% Manual Test 1: Load saved session
% - Save a session
% - Clear app (or restart)
% - Click "Load Session"
% - Select saved file
% - Verify all data restored
% - Schedule re-rendered

% Manual Test 2: Load with unsaved changes
% - Make changes
% - Click "Load Session"
% - Warning dialog appears
% - Can cancel or proceed

% Manual Test 3: Cancel load
% - Click "Load Session"
% - Cancel in file dialog
% - App state unchanged

% Automated Test: Full save/load workflow
app1 = conduction.gui.ProspectiveSchedulerApp();
app1.CaseManager.addCase('Dr. A', 'Proc B', 60);
app1.TargetDate = datetime('2025-02-20');
testFile = tempname();
sessionData = app1.exportAppState();
conduction.session.saveSessionToFile(sessionData, testFile);

app2 = conduction.gui.ProspectiveSchedulerApp();
sessionData = conduction.session.loadSessionFromFile([testFile '.mat']);
app2.importAppState(sessionData);
assert(app2.CaseManager.CaseCount == 1);
assert(app2.TargetDate == datetime('2025-02-20'));
```

### Deliverables
- Load button in UI
- Load dialog working
- Unsaved changes warning
- Full save/load roundtrip functional

**Time Estimate:** 1-2 hours

---

## Stage 7: Dirty Flag Tracking

**Goal:** Track when app has unsaved changes

### Tasks

1. **Add `IsDirty` property to app**
   ```matlab
   properties (Access = public)
       IsDirty logical = false
   end
   ```

2. **Mark dirty on changes:**
   - Case added/removed
   - Optimization run
   - Settings changed
   - Case locked/unlocked
   - Date changed

3. **Clear dirty on:**
   - Successful save
   - Session loaded

4. **Visual indicator:**
   - Window title: "Conduction v1.0.0 *" (asterisk when dirty)
   - Or status label in UI

### Implementation

```matlab
% Add property to ProspectiveSchedulerApp.m:
properties (Access = public)
    IsDirty logical = false
end

% Add method to mark dirty:
function markDirty(app)
    app.IsDirty = true;
    app.updateWindowTitle();
end

% Update window title:
function updateWindowTitle(app)
    versionInfo = conduction.version();
    baseTitle = sprintf('Conduction v%s', versionInfo.Version);

    if app.IsDirty
        app.UIFigure.Name = [baseTitle ' *'];
    else
        app.UIFigure.Name = baseTitle;
    end
end

% Add to various callbacks:
function AddCaseButtonPushed(app, event)
    % ... existing code ...
    app.markDirty();
end

function OptimizationRunButtonPushed(app, event)
    % ... existing code ...
    app.markDirty();
end

% etc.
```

### Testing Strategy

```matlab
% Test 1: Initially not dirty
app = conduction.gui.ProspectiveSchedulerApp();
assert(~app.IsDirty);

% Test 2: Dirty after adding case
app = conduction.gui.ProspectiveSchedulerApp();
app.CaseManager.addCase('Dr. A', 'Proc B', 60);
app.markDirty();
assert(app.IsDirty);

% Test 3: Clean after save
app = conduction.gui.ProspectiveSchedulerApp();
app.CaseManager.addCase('Dr. A', 'Proc B', 60);
app.markDirty();
assert(app.IsDirty);
testFile = tempname();
sessionData = app.exportAppState();
conduction.session.saveSessionToFile(sessionData, testFile);
app.IsDirty = false;
assert(~app.IsDirty);

% Test 4: Clean after load, dirty after change
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = conduction.session.loadSessionFromFile('test.mat');
app.importAppState(sessionData);
assert(~app.IsDirty);
app.CaseManager.addCase('Dr. C', 'Proc D', 45);
app.markDirty();
assert(app.IsDirty);
```

### Deliverables
- Dirty flag tracking working
- Visual indicator in window title
- All change operations mark dirty
- Save/load clears dirty flag

**Time Estimate:** 1 hour

---

## Stage 8: Auto-save

**Goal:** Automatic periodic saving

### Tasks

1. **Add auto-save UI controls**
   - Checkbox: "Auto-save"
   - Settings for interval (default 5 min)

2. **Create auto-save timer**
   - Fires at configured interval
   - Only saves if dirty
   - Uses default location

3. **Implement file rotation**
   - Keep last N auto-saves (default 5)
   - Delete older auto-saves

4. **Add recovery option**
   - List recent auto-saves
   - Quick load most recent

### Implementation

```matlab
% Add properties:
properties (Access = public)
    AutoSaveEnabled logical = false
    AutoSaveInterval double = 5  % minutes
    AutoSaveTimer timer = timer.empty
    AutoSaveMaxFiles double = 5
end

% Auto-save methods:
function enableAutoSave(app, enabled, interval)
    if nargin < 3
        interval = 5;  % default 5 minutes
    end

    app.AutoSaveEnabled = enabled;
    app.AutoSaveInterval = interval;

    if enabled
        app.startAutoSaveTimer();
    else
        app.stopAutoSaveTimer();
    end
end

function startAutoSaveTimer(app)
    % Stop existing timer
    app.stopAutoSaveTimer();

    % Create new timer
    app.AutoSaveTimer = timer(...
        'ExecutionMode', 'fixedSpacing', ...
        'Period', app.AutoSaveInterval * 60, ...  % Convert to seconds
        'StartDelay', app.AutoSaveInterval * 60, ...
        'TimerFcn', @(~,~) app.autoSaveCallback(), ...
        'Name', 'ConductionAutoSaveTimer');

    start(app.AutoSaveTimer);
end

function stopAutoSaveTimer(app)
    if ~isempty(app.AutoSaveTimer) && isvalid(app.AutoSaveTimer)
        stop(app.AutoSaveTimer);
        delete(app.AutoSaveTimer);
        app.AutoSaveTimer = timer.empty;
    end
end

function autoSaveCallback(app)
    % Only save if dirty
    if ~app.IsDirty
        return;
    end

    try
        % Generate auto-save filename
        autoSaveDir = './sessions/autosave';
        if ~isfolder(autoSaveDir)
            mkdir(autoSaveDir);
        end

        timestamp = datestr(datetime('now'), 'yyyy-mm-dd_HHMMSS');
        filename = sprintf('autosave_%s.mat', timestamp);
        filepath = fullfile(autoSaveDir, filename);

        % Save session
        sessionData = app.exportAppState();
        conduction.session.saveSessionToFile(sessionData, filepath);

        % Rotate old auto-saves
        app.rotateAutoSaves(autoSaveDir);

        fprintf('Auto-saved to: %s\n', filepath);

    catch ME
        warning('Auto-save failed: %s', ME.message);
    end
end

function rotateAutoSaves(app, autoSaveDir)
    % Get all auto-save files
    files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));

    % Sort by date (oldest first)
    [~, idx] = sort([files.datenum]);
    files = files(idx);

    % Delete oldest if too many
    numToDelete = length(files) - app.AutoSaveMaxFiles;
    if numToDelete > 0
        for i = 1:numToDelete
            delete(fullfile(autoSaveDir, files(i).name));
        end
    end
end
```

### Testing Strategy

```matlab
% Test 1: Auto-save when dirty
app = conduction.gui.ProspectiveSchedulerApp();
app.enableAutoSave(true, 0.1);  % 0.1 min = 6 sec for testing
app.CaseManager.addCase('Dr. A', 'Proc B', 60);
app.markDirty();
pause(7);
autoSaveFiles = dir('./sessions/autosave/autosave_*.mat');
assert(~isempty(autoSaveFiles));

% Test 2: No auto-save when clean
app = conduction.gui.ProspectiveSchedulerApp();
app.enableAutoSave(true, 0.1);
pause(7);
% Should not create auto-save file

% Test 3: Auto-save disabled
app = conduction.gui.ProspectiveSchedulerApp();
app.CaseManager.addCase('Dr. A', 'Proc B', 60);
app.markDirty();
app.enableAutoSave(false, 0.1);
pause(7);
% Should not create auto-save file

% Test 4: File rotation
app = conduction.gui.ProspectiveSchedulerApp();
app.AutoSaveMaxFiles = 3;
% Create 5 auto-save files
% Verify only 3 most recent kept
```

### Deliverables
- Auto-save checkbox in UI
- Auto-save timer functional
- File rotation working
- Recovery from auto-save possible

**Time Estimate:** 2 hours

---

## Stage 9: Error Handling & Edge Cases

**Goal:** Robust error handling and edge cases

### Tasks

1. **Handle missing historical data**
   - Warn user
   - Allow session load without historical data
   - Option to reload historical data

2. **Handle corrupt/invalid files**
   - Validate file structure
   - Graceful error messages
   - Don't crash app

3. **Handle version incompatibility**
   - Detect old versions
   - Warn or migrate data
   - Document version changes

4. **Handle I/O errors**
   - Disk full
   - Permission denied
   - Network drive issues

5. **Handle edge cases**
   - Empty app state
   - Partial session data
   - Missing optional fields

### Implementation

```matlab
% Enhanced validation in loadSessionFromFile:
function sessionData = loadSessionFromFile(filepath)
    % ... existing code ...

    % Comprehensive validation
    required = {'version', 'targetDate'};
    for i = 1:length(required)
        if ~isfield(sessionData, required{i})
            error('Invalid session: missing required field "%s"', required{i});
        end
    end

    % Version-specific migrations
    if sessionData.version == '0.9.0'
        sessionData = migrateFrom_0_9_0(sessionData);
    end

    % Validate dates
    if isnat(sessionData.targetDate)
        warning('Target date is NaT, using today');
        sessionData.targetDate = datetime('today');
    end
end

% Enhanced error handling in importAppState:
function importAppState(app, sessionData)
    try
        % ... existing code ...

    catch ME
        % Log error
        warning('Failed to import session: %s', ME.message);

        % Attempt partial recovery
        if isfield(sessionData, 'cases')
            try
                % At least restore cases
                % ... partial import ...
            catch
                % Even partial import failed
            end
        end

        % Re-throw with better message
        error('Session import failed: %s', ME.message);
    end
end
```

### Testing Strategy

```matlab
% Test 1: Missing historical data
sessionData = createTestSessionData();
sessionData.historicalDataPath = '/nonexistent/path.mat';
app = conduction.gui.ProspectiveSchedulerApp();
% Should load but warn

% Test 2: Corrupt file
fid = fopen('corrupt.mat', 'w');
fwrite(fid, 'not a mat file');
fclose(fid);
try
    sessionData = conduction.session.loadSessionFromFile('corrupt.mat');
    assert(false);
catch ME
    assert(contains(ME.message, 'invalid') || contains(ME.message, 'corrupt'));
end

% Test 3: Missing required field
sessionData = struct('version', '1.0.0');  % Missing targetDate
try
    app = conduction.gui.ProspectiveSchedulerApp();
    app.importAppState(sessionData);
    assert(false);
catch ME
    assert(contains(ME.message, 'required'));
end

% Test 4: Invalid date
sessionData = createTestSessionData();
sessionData.targetDate = NaT;
app = conduction.gui.ProspectiveSchedulerApp();
app.importAppState(sessionData);
% Should use default date
```

### Deliverables
- All error cases handled
- User-friendly error messages
- No crashes on invalid input
- Graceful degradation

**Time Estimate:** 2-3 hours

---

## Stage 10: Documentation & Polish

**Goal:** Finalize documentation and user experience

### Tasks

1. **Update user documentation**
   - How to save/load sessions
   - Auto-save feature
   - Keyboard shortcuts
   - Troubleshooting

2. **Add tooltips**
   - All save/load buttons
   - Auto-save controls

3. **Add to help menu**
   - Session management section

4. **Performance testing**
   - Large sessions (100+ cases)
   - File size optimization

5. **Final integration testing**
   - Complete workflow tests
   - All stages working together

6. **Update changelog**
   - Document new features

### Testing Strategy

```matlab
% Performance Test: Large session
app = conduction.gui.ProspectiveSchedulerApp();
for i = 1:100
    app.CaseManager.addCase(sprintf('Dr. %d', i), 'Procedure', 60);
end

tic;
sessionData = app.exportAppState();
conduction.session.saveSessionToFile(sessionData, 'large_test.mat');
saveTime = toc;
assert(saveTime < 5, 'Save should complete in under 5 seconds');

tic;
sessionData = conduction.session.loadSessionFromFile('large_test.mat');
app2 = conduction.gui.ProspectiveSchedulerApp();
app2.importAppState(sessionData);
loadTime = toc;
assert(loadTime < 5, 'Load should complete in under 5 seconds');

% File size test
fileInfo = dir('large_test.mat');
fileSizeMB = fileInfo.bytes / 1e6;
fprintf('100-case session file size: %.2f MB\n', fileSizeMB);

% Manual tests
% - Keyboard shortcuts work
% - Tooltips are helpful
% - Error messages are clear
% - Complete workflow is smooth
```

### Deliverables
- Complete user documentation
- All tooltips in place
- Keyboard shortcuts functional
- Performance validated
- Ready for production use

**Time Estimate:** 1-2 hours

---

## Testing Infrastructure

### Test File Organization

```
tests/
  save_load/
    test_serialization.m
    test_state_extraction.m
    test_state_restoration.m
    test_file_io.m
    test_ui_integration.m
    test_dirty_tracking.m
    test_autosave.m
    test_error_handling.m
    test_performance.m
    helpers/
      createTestApp.m
      createTestCase.m
      createTestSchedule.m
      createTestSessionData.m
```

### Test Helper Functions

```matlab
% createTestApp.m
function app = createTestApp()
    app = conduction.gui.ProspectiveSchedulerApp();
end

% createTestAppWithCases.m
function app = createTestAppWithCases(numCases)
    if nargin < 1
        numCases = 3;
    end
    app = conduction.gui.ProspectiveSchedulerApp();
    for i = 1:numCases
        app.CaseManager.addCase(...
            sprintf('Dr. %d', i), ...
            sprintf('Procedure %d', i), ...
            60 + 10*i);
    end
end

% createTestSessionData.m
function sessionData = createTestSessionData()
    sessionData = struct(...
        'version', '1.0.0', ...
        'appVersion', '1.0.0', ...
        'savedDate', datetime('now'), ...
        'targetDate', datetime('2025-01-15'), ...
        'userNotes', 'Test session', ...
        'cases', [], ...
        'completedCases', [], ...
        'optimizedSchedule', struct(), ...
        'simulatedSchedule', struct(), ...
        'optimizationOutcome', struct(), ...
        'opts', struct(), ...
        'labIds', 1:6, ...
        'availableLabIds', 1:6, ...
        'lockedCaseIds', string.empty, ...
        'timeControlState', struct('isActive', false), ...
        'operatorColors', struct('keys', {{}}, 'values', {{}}), ...
        'historicalDataPath', '');
end
```

---

## Known Issues

*Document issues as they are discovered during implementation*

---

## Future Enhancements

Potential features for future versions:

1. **Export Formats**
   - Export case list to CSV/Excel
   - Export schedule as PDF
   - Export metrics to JSON

2. **Session Templates**
   - Save optimization settings as templates
   - Quick load common configurations

3. **Session Management UI**
   - List recent sessions
   - Session preview/metadata
   - Quick load from list

4. **Collaborative Features**
   - Share sessions between users
   - Session merge/compare
   - Version control integration

5. **Cloud Storage**
   - Save to cloud storage
   - Sync across devices
   - Backup to cloud

6. **Advanced Auto-save**
   - Crash recovery
   - Undo/redo system
   - Session history

---

## Version History

### 1.0.0 (Planned)
- Initial implementation
- Basic save/load functionality
- Auto-save feature
- Dirty flag tracking

---

*Last updated: 2025-10-07*
