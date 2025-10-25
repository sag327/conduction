# First Case Constraint Implementation Plan

## Overview
Implement proper handling of the "First Case of Day" constraint, which requires that marked cases be scheduled at the earliest available time slot in a lab with no other cases before them.

## Current Behavior (Problem)

### Issue 1: Constraint Not Enforced
- `IsFirstCaseOfDay` property exists on `ProspectiveCase` (line 27 of ProspectiveCase.m)
- Currently converted to `priority = 1` in case struct (CaseManager.m:941-944)
- Optimizer Constraint 6 (OptimizationModelBuilder.m:315-349) only ensures priority cases come BEFORE non-priority cases for the same operator
- **Does NOT ensure they are the first case in a lab**

### Issue 2: No Validation for Impossible Scenarios
- No pre-optimization check if there are more "first case" cases than available labs
- This creates impossible constraints that optimizer cannot satisfy

## Desired Behavior

### "First Case" Definition
- Schedule at the **earliest available time slot** for the assigned lab
- **No other cases** can be scheduled in that lab before it
- Can be assigned to **any lab** (unless SpecificLab constraint exists)
- Lab assignment should respect:
  - Specific lab requirements
  - Locked case constraints
  - Resource availability

### Implementation Approach
Treat "first case" constraint as a **locked constraint** at lab start time:
1. Pre-process cases before optimization
2. Identify cases with `IsFirstCaseOfDay == true`
3. Convert to locked constraints at earliest time slot
4. Validate feasibility (more first cases than labs → fallback)
5. Pass to optimizer as locked constraints

## Implementation Plan

### Phase 1: Add Validation Method

**File**: `scripts/+conduction/+scheduling/LockedCaseConflictValidator.m`

**New Method**:
```matlab
function [isImpossible, warningMsg, adjustedCases] = validateFirstCaseConstraints(cases, numLabs)
    % Count cases with IsFirstCaseOfDay or priority == 1
    % If count > numLabs, warn and demote excess cases
    % Return adjusted case list with some cases deprioritized
end
```

**Details**:
- Count how many cases have `IsFirstCaseOfDay == true` or `priority == 1`
- Compare against available labs count
- If firstCaseCount > numLabs:
  - Create warning message: "You have X cases marked as 'First Case' but only Y labs available. Some cases will be scheduled as second cases."
  - Keep first N cases (where N = numLabs) as priority
  - Set remaining cases to priority = 0
  - Return `isImpossible = true`, warning message, and adjusted case list
- Fallback strategy: deterministic (keep first N by case number or ID)

### Phase 2: Pre-process First Cases into Locked Constraints

**File**: `scripts/+conduction/+gui/+controllers/OptimizationController.m`

**New Method**:
```matlab
function lockedConstraints = convertFirstCasesToLockedConstraints(obj, cases, numLabs, labStartTimes, existingLockedConstraints)
    % For each case with priority == 1:
    %   1. Determine which lab to assign (respect SpecificLab if set)
    %   2. Check if lab already has a first case (conflict)
    %   3. Create locked constraint at lab start time
    %   4. Calculate timing: startTime, procStartTime, procEndTime
    % Merge with existing locked constraints
    % Return combined locked constraints
end
```

**Algorithm**:
1. Group cases by priority level
2. For each priority == 1 case:
   - Check if case has `SpecificLab` constraint
     - If yes: assign to that lab
     - If no: assign to first available lab (round-robin or random)
   - Check if lab already has a locked first case → conflict
   - Extract timing info:
     - `startTime` = lab start time (e.g., 480 min = 08:00)
     - `procStartTime` = startTime + setupTime
     - `procEndTime` = procStartTime + procTime
     - `endTime` = procEndTime + postTime + turnoverTime
   - Create locked constraint struct:
     ```matlab
     {
       caseID: case.CaseId
       operator: case.OperatorName
       caseNumber: case.CaseNumber
       startTime: labStartTime
       procStartTime: ...
       procEndTime: ...
       endTime: ...
       assignedLab: labIdx
     }
     ```
3. Merge with existing locked constraints
4. Return combined array

### Phase 3: Integrate into Optimization Flow

**File**: `scripts/+conduction/+gui/+controllers/OptimizationController.m`

**Location**: In `executeOptimization` method (around line 50-80)

**Modified Flow**:
```matlab
function executeOptimization(obj, app)
    % ... existing validation ...

    % Get all cases
    casesStruct = app.CaseManager.toCasesStruct(...);

    % STEP 1: Validate first case constraints
    numLabs = app.Opts.labs;
    [isImpossible, warningMsg, adjustedCases] = ...
        conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(...
            casesStruct, numLabs);

    if isImpossible
        % Show warning but continue
        uialert(app.UIFigure, warningMsg, 'First Case Constraint Warning', 'Icon', 'warning');
        casesStruct = adjustedCases;  % Use adjusted cases with some deprioritized
    end

    % STEP 2: Build locked constraints (existing)
    lockedAssignments = app.ScheduleRenderer.getLockedAssignments(...);
    lockedConstraints = obj.buildLockedCaseConstraints(lockedAssignments);

    % STEP 3: Convert first cases to locked constraints (NEW)
    labStartTimes = repmat({'08:00'}, 1, numLabs);  % From buildSchedulingOptions
    lockedConstraints = obj.convertFirstCasesToLockedConstraints(...
        casesStruct, numLabs, labStartTimes, lockedConstraints);

    % STEP 4: Validate combined locked constraints (existing)
    [hasConflicts, conflictReport] = ...
        conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);

    if hasConflicts
        uialert(app.UIFigure, conflictReport.message, 'Locked Case Conflicts');
        return;
    end

    % Continue with optimization...
end
```

### Phase 4: Update Case Struct Conversion

**File**: `scripts/+conduction/+gui/+controllers/CaseManager.m`

**Modification**: In `toCasesStruct` method (around line 941)

Currently:
```matlab
if caseObj.IsFirstCaseOfDay
    casesStruct(idx).priority = 1;
else
    casesStruct(idx).priority = 0;
end
```

**Keep this for fallback**, but add flag to distinguish "converted to locked" vs "use priority constraint":
```matlab
casesStruct(idx).isFirstCase = caseObj.IsFirstCaseOfDay;
casesStruct(idx).priority = caseObj.IsFirstCaseOfDay ? 1 : 0;
```

After conversion to locked constraints, set:
```matlab
casesStruct(idx).priority = 0;  % Don't use old priority constraint
```

### Phase 5: Remove or Modify Old Priority Constraint

**File**: `scripts/+conduction/+scheduling/OptimizationModelBuilder.m`

**Option A (Recommended)**: Keep Constraint 6 as fallback
- If a "first case" couldn't be converted to locked constraint (e.g., not enough labs)
- The priority constraint ensures it's at least before other cases from same operator

**Option B**: Remove Constraint 6 entirely
- Rely solely on locked constraints
- Simpler, but loses fallback behavior

**Recommendation**: Keep Constraint 6 as-is for now. It provides good fallback.

## Testing Strategy

### Unit Tests

**File**: `tests/scheduling/testFirstCaseConstraintValidation.m`

```matlab
classdef testFirstCaseConstraintValidation < matlab.unittest.TestCase
    methods (Test)
        function testFewFirstCases(testCase)
            % 2 first cases, 6 labs -> should pass
        end

        function testExactlyEnoughLabs(testCase)
            % 6 first cases, 6 labs -> should pass
        end

        function testTooManyFirstCases(testCase)
            % 10 first cases, 6 labs -> should warn and demote 4 cases
        end

        function testNoFirstCases(testCase)
            % 0 first cases -> should pass
        end
    end
end
```

**File**: `tests/scheduling/testFirstCaseLockedConversion.m`

```matlab
classdef testFirstCaseLockedConversion < matlab.unittest.TestCase
    methods (Test)
        function testBasicConversion(testCase)
            % Single first case -> locked at lab 1, start time 08:00
        end

        function testMultipleFirstCases(testCase)
            % 3 first cases, 6 labs -> locked at labs 1,2,3
        end

        function testSpecificLabRespected(testCase)
            % First case with SpecificLab=3 -> locked at lab 3
        end

        function testConflictWithExistingLocked(testCase)
            % First case + existing locked case at same lab start
            % Should detect conflict
        end

        function testTimingCalculation(testCase)
            % Verify procStartTime, procEndTime calculated correctly
        end
    end
end
```

### Integration Tests

**File**: `tests/integration/testFirstCaseOptimization.m`

```matlab
classdef testFirstCaseOptimization < matlab.unittest.TestCase
    methods (Test)
        function testFirstCaseScheduledFirst(testCase)
            % Create schedule with 1 first case, 2 normal cases
            % Verify first case is at earliest time in assigned lab
            % Verify no cases before it in that lab
        end

        function testMultipleFirstCasesDistributed(testCase)
            % 3 first cases, 6 labs
            % Verify all 3 are at lab start times
            % Verify different labs
        end

        function testFirstCaseWithSpecificLab(testCase)
            % First case with SpecificLab constraint
            % Verify scheduled at start of that specific lab
        end

        function testExcessFirstCasesFallback(testCase)
            % 10 first cases, 6 labs
            % Verify first 6 are locked at start times
            % Verify remaining 4 use priority constraint
        end

        function testFirstCaseWithResources(testCase)
            % First case requiring specific resources
            % Verify resources respected and still scheduled first
        end
    end
end
```

### Manual GUI Testing Checklist

1. **Basic First Case**
   - [ ] Add case with "First Case" checkbox checked
   - [ ] Run optimization
   - [ ] Verify case is scheduled at 08:00 in a lab
   - [ ] Verify no other cases before it in that lab

2. **Multiple First Cases**
   - [ ] Add 3 cases with "First Case" checked
   - [ ] Run optimization
   - [ ] Verify all 3 at 08:00 in different labs
   - [ ] Verify distributed across labs

3. **First Case with Specific Lab**
   - [ ] Add case with "First Case" + "Lab 4" specified
   - [ ] Run optimization
   - [ ] Verify scheduled at 08:00 in Lab 4
   - [ ] Add another first case without specific lab
   - [ ] Verify second first case goes to different lab

4. **Too Many First Cases**
   - [ ] Add 10 cases with "First Case" checked
   - [ ] Set available labs to 6
   - [ ] Run optimization
   - [ ] Verify warning dialog appears with clear message
   - [ ] Verify optimization still completes
   - [ ] Verify first 6 cases at lab start times
   - [ ] Verify remaining 4 scheduled later but before normal cases from same operator

5. **First Case with Locked Cases**
   - [ ] Schedule cases and lock one at 08:00
   - [ ] Add new first case
   - [ ] Run re-optimization
   - [ ] Verify first case goes to different lab (conflict avoided)

6. **First Case with Resources**
   - [ ] Add first case requiring rare resource
   - [ ] Run optimization
   - [ ] Verify scheduled at start time with resources available

## Rollout Plan

1. **Phase 1**: Implement validation method (1-2 hours)
   - Add to LockedCaseConflictValidator
   - Write unit tests
   - Verify validation logic

2. **Phase 2**: Implement conversion method (2-3 hours)
   - Add to OptimizationController
   - Handle timing calculations
   - Handle lab assignment logic
   - Write unit tests

3. **Phase 3**: Integrate into optimization flow (1 hour)
   - Modify executeOptimization method
   - Add warning dialogs
   - Handle adjusted cases

4. **Phase 4**: Integration testing (2-3 hours)
   - Write integration tests
   - Run full optimization scenarios
   - Verify edge cases

5. **Phase 5**: Manual GUI testing (1-2 hours)
   - Test all GUI scenarios
   - Verify user experience
   - Document any issues

**Total Estimated Time**: 8-12 hours

## Open Questions

1. **Lab assignment strategy for first cases without specific lab**:
   - Round-robin (deterministic)?
   - Random (non-deterministic)?
   - Least loaded lab (smart)?
   - **Recommendation**: Round-robin for deterministic behavior

2. **Should we update GUI to show first cases differently in schedule?**:
   - Add visual indicator (star icon, different color)?
   - **Recommendation**: Future enhancement, not required for initial implementation

3. **What if lab start times are different for different labs?**:
   - Currently hardcoded to '08:00' for all labs
   - If this changes in future, logic should adapt
   - **Recommendation**: Use earliest start time per lab from LabStartTimes

4. **Should first case constraint override locked case constraints?**:
   - What if user locks a case at 10:00 and adds first case to same lab?
   - **Recommendation**: Detect as conflict, show error, let user resolve

## Success Criteria

- [ ] Cases marked "First Case" are scheduled at earliest time slot
- [ ] No cases scheduled before "First Case" in same lab
- [ ] Warning shown when more first cases than labs
- [ ] Optimization completes successfully with fallback
- [ ] Specific lab constraints respected for first cases
- [ ] Conflicts with locked cases detected and prevented
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual GUI testing scenarios pass
