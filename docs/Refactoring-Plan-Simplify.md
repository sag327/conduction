# Refactoring Plan: Simplification and Modularity

## Executive Summary

### Current State
- **File**: `ProspectiveSchedulerApp.m`
- **Size**: 3,091 lines of code
- **Methods**: 107 methods
- **Properties**: 199 properties
  - 132 UI Components (66%)
  - 32 State Variables (16%)
  - 26 Configuration (13%)
  - 9 Controllers (5%)

### Goals
- Reduce code duplication
- Improve maintainability
- Make code easier to understand
- **Do NOT break existing functionality**

### Expected Outcomes
- **170 fewer lines** (5.5% reduction)
- Clearer, more maintainable code
- Zero functional changes (pure refactoring)
- **~7 hours total effort**

---

## Complexity Analysis Results

### Top 5 Longest Methods
1. `setupUI` - 252 lines (naturally large, UI initialization)
2. `importAppState` - 263 lines (needs refactoring)
3. `exportAppState` - 93 lines (acceptable)
4. `delete` - 90 lines (cleanup, acceptable)
5. `clearUnlockedCasesOnly` - 65 lines (has duplication)

### Code Duplication Patterns Identified

#### 1. Batch Update Pattern (3+ occurrences)
**Locations**: `clearUnlockedCasesOnly`, `clearAllCasesIncludingLocked`, `importAppState`

**Current Code** (~40 lines per occurrence):
```matlab
if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
    app.CaseStore.beginBatchUpdate();
end
if ~isempty(app.OptimizationController)
    app.OptimizationController.beginBatchUpdate();
end
try
    % ... operations ...
catch ME
    if ~isempty(app.OptimizationController)
        app.OptimizationController.endBatchUpdate(app);
    end
    if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
        app.CaseStore.endBatchUpdate();
    end
    rethrow(ME);
end
% End batch updates
if ~isempty(app.OptimizationController)
    app.OptimizationController.endBatchUpdate(app);
end
if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
    app.CaseStore.endBatchUpdate();
end
```

#### 2. Resource Store Validation (6+ occurrences)
```matlab
store = app.CaseManager.getResourceStore();
if isempty(store) || ~isvalid(store)
    return;
end
```

#### 3. Dialog Calls (10+ occurrences)
```matlab
uialert(app.UIFigure, 'Message', 'Title', 'Icon', 'warning');
uiconfirm(app.UIFigure, 'Question', 'Title', 'Options', {'Yes', 'No'});
```

---

## Refactoring Phases

### Phase 1: Extract Batch Update Wrapper ⭐ HIGHEST PRIORITY

**Risk**: LOW
**Effort**: 2 hours
**LOC Saved**: ~120 lines
**Impact**: HIGH

#### Problem
Batch update try-catch blocks duplicated in 3+ methods, totaling ~120 lines of boilerplate code.

#### Solution
Create helper method `executeBatchUpdate(app, operationFn)`:

```matlab
function executeBatchUpdate(app, operationFn)
    %EXECUTEBATCHUPDATE Execute operation within batch update context
    %   Coordinates CaseStore and OptimizationController batch updates
    %   with proper error handling

    batchStoreActive = ~isempty(app.CaseStore) && isvalid(app.CaseStore);
    batchOptActive = ~isempty(app.OptimizationController);

    % Begin batch updates
    if batchStoreActive
        app.CaseStore.beginBatchUpdate();
    end
    if batchOptActive
        app.OptimizationController.beginBatchUpdate();
    end

    try
        operationFn();
    catch ME
        % Cleanup on error
        if batchOptActive
            app.OptimizationController.endBatchUpdate(app);
        end
        if batchStoreActive
            app.CaseStore.endBatchUpdate();
        end
        rethrow(ME);
    end

    % Normal completion
    if batchOptActive
        app.OptimizationController.endBatchUpdate(app);
    end
    if batchStoreActive
        app.CaseStore.endBatchUpdate();
    end
end
```

#### Usage Example
**Before**:
```matlab
function clearUnlockedCasesOnly(app)
    if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
        app.CaseStore.beginBatchUpdate();
    end
    if ~isempty(app.OptimizationController)
        app.OptimizationController.beginBatchUpdate();
    end
    try
        % ... 30 lines of clearing logic ...
    catch ME
        if ~isempty(app.OptimizationController)
            app.OptimizationController.endBatchUpdate(app);
        end
        if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
            app.CaseStore.endBatchUpdate();
        end
        rethrow(ME);
    end
    if ~isempty(app.OptimizationController)
        app.OptimizationController.endBatchUpdate(app);
    end
    if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
        app.CaseStore.endBatchUpdate();
    end
end
```

**After**:
```matlab
function clearUnlockedCasesOnly(app)
    app.executeBatchUpdate(@() performUnlockedClear(app));
end

function performUnlockedClear(app)
    % ... 30 lines of clearing logic (unchanged) ...
end
```

#### Testing (Phase 1)

**MATLAB Command-Line Tests**:
```matlab
% Test 1: Clear unlocked cases
app = conduction.gui.ProspectiveSchedulerApp();
% Add some test cases...
app.clearUnlockedCasesOnly();
assert(app.CaseManager.CaseCount == 0, 'Clear unlocked failed');
delete(app);

% Test 2: Clear all cases (including locked)
app = conduction.gui.ProspectiveSchedulerApp();
% Add and lock some test cases...
app.clearAllCasesIncludingLocked();
assert(app.CaseManager.CaseCount == 0, 'Clear all failed');
delete(app);

% Test 3: Session import with batch updates
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = load('test_session.mat');
app.importAppState(sessionData);
assert(app.CaseManager.CaseCount > 0, 'Import failed');
delete(app);
```

**Manual Verification Checklist**:
- [ ] Clear unlocked cases works (Add/Edit tab → Cases list)
- [ ] Clear all cases works (including locked)
- [ ] Load session still works (Load Session button)
- [ ] No errors in console during operations
- [ ] Batch updates still coordinate properly (no duplicate refreshes)

---

### Phase 2: Extract Resource Store Validator

**Risk**: LOW
**Effort**: 1 hour
**LOC Saved**: ~20 lines
**Impact**: MEDIUM

#### Problem
Resource store validation pattern repeated 6+ times throughout resource-related methods.

#### Solution
Create validated getter method:

```matlab
function [store, isValid] = getValidatedResourceStore(app)
    %GETVALIDATEDRESOURCESTORE Get resource store with validation
    %   Returns both store and validity flag
    %
    %   Returns:
    %       store - ResourceStore instance or []
    %       isValid - true if store exists and is valid

    store = [];
    isValid = false;

    if isempty(app.CaseManager)
        return;
    end

    store = app.CaseManager.getResourceStore();
    isValid = ~isempty(store) && isvalid(store);
end
```

#### Usage Example
**Before**:
```matlab
function refreshResourcesTable(app)
    if isempty(app.CaseManager)
        return;
    end

    store = app.CaseManager.getResourceStore();
    if isempty(store) || ~isvalid(store)
        return;
    end

    types = store.list();
    % ... rest of logic
end
```

**After**:
```matlab
function refreshResourcesTable(app)
    [store, isValid] = app.getValidatedResourceStore();
    if ~isValid
        return;
    end

    types = store.list();
    % ... rest of logic
end
```

#### Testing (Phase 2)

**MATLAB Command-Line Tests**:
```matlab
% Test 1: Resource creation
app = conduction.gui.ProspectiveSchedulerApp();
app.ResourceNameField.Value = 'Test Resource';
app.ResourceCapacitySpinner.Value = 2;
app.onSaveResourcePressed();
[store, isValid] = app.getValidatedResourceStore();
assert(isValid, 'Store should be valid');
assert(~isempty(store.getByName('Test Resource')), 'Resource not created');
delete(app);

% Test 2: Resource table refresh
app = conduction.gui.ProspectiveSchedulerApp();
app.refreshResourcesTable();
% Should not error even with empty store
delete(app);
```

**Manual Verification Checklist**:
- [ ] Resources tab loads without error
- [ ] Can create new resource
- [ ] Can edit resource
- [ ] Can delete resource
- [ ] Resource table updates properly
- [ ] Default resources panel works

---

### Phase 3: Extract Dialog Helpers

**Risk**: LOW
**Effort**: 1 hour
**LOC Saved**: ~30 lines
**Impact**: MEDIUM

#### Problem
Dialog calls (`uialert`, `uiconfirm`) scattered with repetitive `app.UIFigure` references.

#### Solution
Create wrapper methods for common dialog patterns:

```matlab
function showAlert(app, message, title, icon)
    %SHOWALERT Display alert dialog
    %   Simplified wrapper for uialert

    arguments
        app
        message
        title = 'Alert'
        icon = 'info'
    end

    uialert(app.UIFigure, message, title, 'Icon', icon);
end

function answer = showConfirm(app, message, title, options, defaultIdx)
    %SHOWCONFIRM Display confirmation dialog
    %   Simplified wrapper for uiconfirm

    arguments
        app
        message
        title = 'Confirm'
        options = {'OK', 'Cancel'}
        defaultIdx = 2
    end

    answer = uiconfirm(app.UIFigure, message, title, ...
        'Options', options, ...
        'DefaultOption', defaultIdx, ...
        'CancelOption', defaultIdx);
end

function answer = showQuestion(app, message, title)
    %SHOWQUESTION Display yes/no question dialog
    %   Convenience wrapper for common yes/no questions

    arguments
        app
        message
        title = 'Question'
    end

    answer = uiconfirm(app.UIFigure, message, title, ...
        'Options', {'Yes', 'No'}, ...
        'DefaultOption', 'No', ...
        'CancelOption', 'No');
end
```

#### Usage Example
**Before**:
```matlab
if isempty(name)
    uialert(app.UIFigure, 'Resource name cannot be empty.', 'Validation Error', 'Icon', 'warning');
    return;
end

answer = uiconfirm(app.UIFigure, ...
    'Are you sure you want to delete all cases?', ...
    'Confirm Clear', ...
    'Options', {'Clear All', 'Cancel'}, ...
    'DefaultOption', 'Cancel', ...
    'CancelOption', 'Cancel', ...
    'Icon', 'warning');
if strcmp(answer, 'Cancel')
    return;
end
```

**After**:
```matlab
if isempty(name)
    app.showAlert('Resource name cannot be empty.', 'Validation Error', 'warning');
    return;
end

answer = app.showConfirm(...
    'Are you sure you want to delete all cases?', ...
    'Confirm Clear', ...
    {'Clear All', 'Cancel'}, ...
    2);
if strcmp(answer, 'Cancel')
    return;
end
```

#### Testing (Phase 3)

**MATLAB Command-Line Tests**:
```matlab
% Test 1: Alert dialog
app = conduction.gui.ProspectiveSchedulerApp();
app.showAlert('Test message', 'Test Title', 'info');
% Manually close dialog
delete(app);

% Test 2: Validation alerts still appear
app = conduction.gui.ProspectiveSchedulerApp();
app.ResourceNameField.Value = '';  % Invalid
app.onSaveResourcePressed();
% Should show alert about empty name
delete(app);
```

**Manual Verification Checklist**:
- [ ] Error dialogs appear for validation failures
- [ ] Confirmation dialogs appear before destructive operations
- [ ] Info dialogs appear for help/guidance
- [ ] All dialog text is readable and correct
- [ ] Dialog buttons work as expected

---

### Phase 4: Split importAppState (OPTIONAL)

**Risk**: LOW
**Effort**: 3 hours
**LOC Saved**: 0 (reorganization only)
**Impact**: MEDIUM

#### Problem
`importAppState` method is 263 lines, making it hard to understand flow and debug failures.

#### Solution
Break into logical sub-methods:

```matlab
function importAppState(app, sessionData)
    %IMPORTAPPSTATE Restore app state from session data
    %   Coordinates all aspects of session restoration

    app.validateSessionData(sessionData);
    app.clearStateForImport();

    app.IsRestoringSession = true;
    try
        app.importResourceDefinitions(sessionData);
        app.importTargetDate(sessionData);

        % Use batch update wrapper for case import
        app.executeBatchUpdate(@() app.importCases(sessionData));

        app.importSchedules(sessionData);
        app.importOptimizationState(sessionData);
        app.importLabConfiguration(sessionData);
        app.importLockedCases(sessionData);
        app.importUIState(sessionData);

        app.finalizeImport();
    catch ME
        app.IsRestoringSession = false;
        rethrow(ME);
    end
    app.IsRestoringSession = false;
end

% Private helper methods (each 20-40 lines)
function validateSessionData(app, sessionData)
    % Validate structure and version compatibility
end

function importResourceDefinitions(app, sessionData)
    % Restore resource types
end

function importCases(app, sessionData)
    % Restore cases (called within batch update)
end

function importSchedules(app, sessionData)
    % Restore optimized and simulated schedules
end

% ... etc for other sections
```

#### Benefits
- Each sub-method is testable in isolation
- Easier to understand import flow
- Better error messages (know which section failed)
- Simpler to add new session data in future

#### Testing (Phase 4)

**MATLAB Command-Line Tests**:
```matlab
% Test 1: Full session load
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = load('full_session.mat');
app.importAppState(sessionData);
assert(app.CaseManager.CaseCount > 0, 'Cases not loaded');
assert(~isempty(app.OptimizedSchedule), 'Schedule not loaded');
delete(app);

% Test 2: Session with resources
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = load('session_with_resources.mat');
app.importAppState(sessionData);
[store, isValid] = app.getValidatedResourceStore();
assert(isValid && ~isempty(store.list()), 'Resources not loaded');
delete(app);

% Test 3: Session with locked cases
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = load('session_with_locks.mat');
app.importAppState(sessionData);
assert(~isempty(app.LockedCaseIds), 'Locks not loaded');
delete(app);

% Test 4: Backward compatibility (old session format)
app = conduction.gui.ProspectiveSchedulerApp();
sessionData = load('old_format_session.mat');
app.importAppState(sessionData);
% Should load without errors
delete(app);
```

**Manual Verification Checklist**:
- [ ] Load Session button works
- [ ] All cases restored correctly
- [ ] Resource types restored
- [ ] Locked cases remain locked
- [ ] Schedules displayed correctly
- [ ] Optimization settings preserved
- [ ] Lab configuration restored
- [ ] Target date correct

---

## Complete Testing Protocol

### Regression Test Suite (Run After ALL Phases)

Create a comprehensive test script: `test_refactoring.m`

```matlab
function test_refactoring()
    %TEST_REFACTORING Comprehensive test suite for refactoring validation

    fprintf('Running refactoring regression tests...\n\n');

    % Test 1: Basic app creation/deletion
    fprintf('Test 1: App creation...\n');
    app = conduction.gui.ProspectiveSchedulerApp();
    assert(~isempty(app.UIFigure), 'App creation failed');
    delete(app);
    fprintf('✓ PASS\n\n');

    % Test 2: Case operations
    fprintf('Test 2: Case operations...\n');
    app = conduction.gui.ProspectiveSchedulerApp();
    initialCount = app.CaseManager.CaseCount;
    % Add case via UI
    app.OperatorDropDown.Value = 'Dr. Smith';
    app.ProcedureDropDown.Value = 'Procedure A';
    app.handleAddCase();
    assert(app.CaseManager.CaseCount == initialCount + 1, 'Add case failed');
    delete(app);
    fprintf('✓ PASS\n\n');

    % Test 3: Resource operations
    fprintf('Test 3: Resource operations...\n');
    app = conduction.gui.ProspectiveSchedulerApp();
    app.ResourceNameField.Value = 'TestResource';
    app.ResourceCapacitySpinner.Value = 3;
    app.onSaveResourcePressed();
    [store, isValid] = app.getValidatedResourceStore();
    assert(isValid, 'Resource store invalid');
    testRes = store.getByName('TestResource');
    assert(~isempty(testRes), 'Resource creation failed');
    assert(testRes.Capacity == 3, 'Resource capacity incorrect');
    delete(app);
    fprintf('✓ PASS\n\n');

    % Test 4: Clear operations
    fprintf('Test 4: Clear operations...\n');
    app = conduction.gui.ProspectiveSchedulerApp();
    % Add test cases
    for i = 1:3
        app.handleAddCase();
    end
    app.clearUnlockedCasesOnly();
    assert(app.CaseManager.CaseCount == 0, 'Clear unlocked failed');
    delete(app);
    fprintf('✓ PASS\n\n');

    % Test 5: Session save/load
    fprintf('Test 5: Session save/load...\n');
    app1 = conduction.gui.ProspectiveSchedulerApp();
    app1.ResourceNameField.Value = 'SessionTestResource';
    app1.ResourceCapacitySpinner.Value = 2;
    app1.onSaveResourcePressed();
    sessionData = app1.exportAppState();
    delete(app1);

    app2 = conduction.gui.ProspectiveSchedulerApp();
    app2.importAppState(sessionData);
    [store, isValid] = app2.getValidatedResourceStore();
    assert(isValid, 'Session load: store invalid');
    assert(~isempty(store.getByName('SessionTestResource')), 'Session load: resource missing');
    delete(app2);
    fprintf('✓ PASS\n\n');

    fprintf('All tests passed! ✓\n');
end
```

**Run tests**:
```matlab
cd /Users/sgaeta/Documents/codeProjects/conduction
addpath(genpath('scripts'))
test_refactoring()
```

---

## Risk Mitigation Strategies

### Before Starting
1. **Create branch**: `git checkout -b refactor-simplify`
2. **Full backup**: Save working copy outside git
3. **Document baseline**: Run app, verify all features work

### During Each Phase
1. **Test immediately** after code changes
2. **Keep old code commented** for 1 commit (easy rollback)
3. **Commit after each phase** with descriptive message
4. **Stop if issues arise** - don't continue to next phase

### If Problems Occur
1. **Rollback**: `git checkout HEAD~1`
2. **Investigate**: Identify what broke
3. **Fix or skip**: Either fix the issue or skip that refactoring
4. **Document**: Note why a refactoring was skipped

### Rollback Commands
```bash
# Undo last commit, keep changes
git reset --soft HEAD~1

# Undo last commit, discard changes
git reset --hard HEAD~1

# Restore specific file from previous commit
git checkout HEAD~1 -- scripts/+conduction/+gui/ProspectiveSchedulerApp.m
```

---

## What We're NOT Doing (Too Risky)

### ❌ Not Extracting ResourceFormController
- Would require rewiring 22 methods
- High coupling with main app UI components
- Risk of breaking resource tab functionality
- Not worth the effort given complexity

### ❌ Not Changing Data Structures
- ResourceType, Case, Schedule structures stay as-is
- No changes to how data is stored or accessed

### ❌ Not Modifying Algorithms
- Scheduling algorithms untouched
- Optimization logic unchanged
- Rendering/layout logic preserved

### ❌ Not Restructuring UI Hierarchy
- 132 UI components stay in main app
- MATLAB App Designer architecture preserved
- Tab/panel structure unchanged

---

## Implementation Guidelines

### Order of Operations
1. **Phase 1 first** (highest impact, lowest risk)
2. **Test thoroughly** before proceeding
3. **Phase 2 and 3** can be done in any order
4. **Phase 4 is optional** (do only if time permits)

### Commit Messages
Use descriptive commit messages for each phase:

```bash
git commit -m "Refactor: Extract batch update wrapper (Phase 1)

- Add executeBatchUpdate() helper method
- Simplify clearUnlockedCasesOnly() using wrapper
- Simplify clearAllCasesIncludingLocked() using wrapper
- Simplify importAppState() batch coordination
- Reduces code duplication by ~120 lines
- All tests passing"
```

### Code Review Checklist
After each phase, verify:
- [ ] Code compiles without errors
- [ ] All affected features tested manually
- [ ] Automated tests passing
- [ ] No new warnings in console
- [ ] Performance unchanged (no slowdowns)
- [ ] Code is more readable than before

---

## Success Metrics

### Quantitative
- **LOC Reduction**: Target 170 lines (~5.5%)
- **Method Count**: May increase slightly (split methods)
- **Duplication**: Eliminate 3+ instances of batch update pattern
- **Test Pass Rate**: 100% (all tests must pass)

### Qualitative
- Code is easier to read and understand
- Future changes are easier to make
- Debugging is simpler (clearer stack traces)
- New developers can onboard faster

---

## Timeline

| Phase | Effort | Cumulative |
|-------|--------|------------|
| Setup & Testing Script | 1h | 1h |
| Phase 1: Batch Update Wrapper | 2h | 3h |
| Phase 2: Resource Store Validator | 1h | 4h |
| Phase 3: Dialog Helpers | 1h | 5h |
| Phase 4: Split importAppState (optional) | 3h | 8h |
| **Total** | **7-8 hours** | |

---

## Conclusion

This refactoring plan focuses on **safe, incremental improvements** that reduce duplication and improve code clarity without risking functionality. Each phase can be completed independently, tested thoroughly, and committed separately.

**Key Principles**:
- ✅ Low risk, high value changes only
- ✅ Test after every change
- ✅ One phase at a time
- ✅ Easy rollback if needed
- ✅ No functional changes

**Expected Result**: A cleaner, more maintainable codebase with identical functionality to the current implementation.
