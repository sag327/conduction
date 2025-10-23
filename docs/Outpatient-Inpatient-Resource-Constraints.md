# Outpatient/Inpatient Resource Constraint Implementation Plan

## Problem Statement

The current two-phase optimization approach (outpatients first, then inpatients) treats each phase independently when enforcing resource capacity constraints. This creates a critical issue:

**Current Behavior:**
- Phase 1 optimizes outpatient cases, respecting resource capacity limits *within outpatients*
- Phase 2 optimizes inpatient cases, respecting resource capacity limits *within inpatients*
- **Problem:** Both phases assume full access to resources, leading to violations when schedules are merged

**Example Violation:**
- Resource "Affera" has capacity = 1
- Phase 1 schedules outpatient at 9:00-10:00 using Affera
- Phase 2 schedules inpatient at 9:30-10:30 using Affera (doesn't know outpatient is using it)
- **Result:** Both cases overlap, violating capacity=1 constraint

## Design Principles

### Hard vs Soft Constraints

**Hard Constraints (Cannot be violated):**
- Resource capacity limits (physical limitation)
- Lab availability (OR can only handle one case at a time)
- Operator availability (surgeon can only operate on one patient at a time)

**Soft Constraints (Preferences, can be relaxed if necessary):**
- Outpatient prioritization (scheduling preference, not physical law)
- Makespan minimization
- Idle time minimization

### User Requirements

1. **Performance:** Should not be significantly slower than current implementation
2. **Conflict Resolution:** When outpatient-first + resource-limits = impossible, allow some inpatients before outpatients but warn the user
3. **Resource Bottlenecks:** Resources are not often a bottleneck (rare case)
4. **User Control:** Provide three modes with clear tradeoffs

## Solution Architecture

### Overview: Two-Phase with Locked Cases + Auto-Fallback

The solution maintains the fast two-phase approach for normal cases while gracefully handling resource conflicts through automatic fallback to single-phase optimization.

### Three Optimization Modes

#### 1. Two-Phase (Strict)
**Behavior:**
- Outpatients always scheduled first, no exceptions
- Phase 1: Optimize outpatients
- Phase 2: Optimize inpatients with phase 1 cases locked (consuming resources)
- If resource conflicts make phase 2 infeasible → **error, no schedule produced**

**When to Use:**
- Outpatient priority is absolute (regulatory/policy requirement)
- Willing to fail rather than compromise priority

**Error Message:**
```
Cannot schedule all inpatients due to resource constraints.
Please adjust resource capacity, reduce case load, or change
outpatient/inpatient optimization handling option.
```

#### 2. Two-Phase (Auto-Fallback) [DEFAULT]
**Behavior:**
- Tries outpatients-first approach (fast path)
- Phase 1: Optimize outpatients
- Phase 2: Optimize inpatients with phase 1 cases locked
- If phase 2 fails or has violations → **automatically retry with single-phase**
- Single-phase allows some inpatients before outpatients to satisfy resource constraints
- Shows warning about which cases were affected

**When to Use:**
- Most scenarios - prefer outpatients first, but pragmatic about fitting all cases
- Want best effort while respecting hard constraints
- Performance matters (fast when resources aren't bottleneck)

**Warning Message:**
```
⚠ Resource Constraints Override

Resource capacity limits required 2 inpatient cases to be
scheduled before some outpatients.

Affected cases:
  • IP-1234
  • IP-5678
```

#### 3. Single-Phase (Flexible)
**Behavior:**
- Optimizes all cases together from the start
- Outpatient priority is a preference (weighted objective) not a rule
- May schedule inpatients before outpatients even when not strictly necessary for resources

**When to Use:**
- Makespan/efficiency is more important than outpatient ordering
- Resource constraints are frequently tight
- Want globally optimal solution regardless of outpatient/inpatient mix

### How It Works

#### Normal Case (Resources Not Bottleneck - ~95% of time)

**Two-Phase (Auto-Fallback) mode:**

```
Step 1: Phase 1 - Optimize Outpatients
  ├─ Input: Outpatient cases only
  ├─ Constraints: Resources, labs, operators
  └─ Output: Outpatient schedule

Step 2: Convert Phase 1 to Locked Constraints
  ├─ Extract: caseID, startTime, assignedLab for each outpatient
  └─ Include resource assignments from phase 1

Step 3: Phase 2 - Optimize Inpatients
  ├─ Input: Inpatient cases + locked outpatient constraints
  ├─ Constraints:
  │   ├─ Resources (locked cases consume resources during their windows)
  │   ├─ Labs (updated start times after outpatients)
  │   └─ Operators (availability after outpatient completion)
  └─ Output: Inpatient schedule

Step 4: Check Success
  ├─ Phase 2 exitflag >= 1 (feasible solution found)
  └─ No resource violations detected
  └─ ✓ SUCCESS → Merge and return

Runtime: Same as current two-phase (fast)
```

#### Resource-Constrained Case (Rare - ~5% of time)

**Two-Phase (Auto-Fallback) mode:**

```
Step 1-3: [Same as above]

Step 4: Check Success
  ├─ Phase 2 exitflag < 1 (infeasible)
  └─ OR resource violations detected
  └─ ✗ FAILURE → Trigger fallback

Step 5: Fallback to Single-Phase
  ├─ Input: ALL cases (outpatients + inpatients)
  ├─ Constraints: Resources, labs, operators (hard)
  ├─ Objective: Minimize makespan + penalty for inpatients before outpatients
  └─ Output: Combined schedule with some inpatients possibly before outpatients

Step 6: Generate Warning
  ├─ Identify which inpatients were scheduled before outpatients
  ├─ Build user-friendly explanation
  └─ Display warning dialog

Runtime: Two-phase attempt + single-phase retry (~1.5-2x slower)
Overall Impact: ~2-5% average slowdown (negligible)
```

## Implementation Details

### Code Changes Required

#### 1. SchedulingOptions.m - Add New Property

```matlab
properties
    % ... existing properties ...

    % Outpatient/Inpatient optimization strategy
    OutpatientInpatientMode string {mustBeMember(OutpatientInpatientMode, ...
        ["TwoPhaseStrict", "TwoPhaseAutoFallback", "SinglePhaseFlexible"])} = "TwoPhaseAutoFallback"
end
```

Update `fromArgs()` to accept and validate this parameter.

#### 2. HistoricalScheduler.m - Core Logic Changes

**Modify `scheduleTwoPhase()` method:**

```matlab
function [dailySchedule, outcome] = scheduleTwoPhase(obj, cases)
    [outpatientCases, inpatientCases] = obj.partitionCases(cases);

    if isempty(outpatientCases)
        [dailySchedule, outcome] = runPhase(cases, obj.Options);
        return;
    end

    % Phase 1 - Optimize outpatients only
    phase1Options = obj.buildPhase1Options();
    [phase1Daily, phase1Outcome] = runPhase(outpatientCases, phase1Options);

    if isempty(inpatientCases)
        % No inpatients to schedule
        dailySchedule = phase1Daily;
        outcome = obj.buildPhase1OnlyOutcome(phase1Outcome);
        return;
    end

    % Convert phase 1 results to locked constraints for phase 2
    lockedConstraints = obj.convertScheduleToLockedConstraints(...
        phase1Outcome.scheduleStruct, outpatientCases, obj.Options.LockedCaseConstraints);

    % Phase 2 - Optimize inpatients with locked outpatients
    phase2Options = obj.buildPhase2Options(lockedConstraints);
    [phase2Daily, phase2Outcome] = runPhase(inpatientCases, phase2Options);

    % Merge schedules
    combinedSchedule = obj.mergeSchedules(phase1Outcome.scheduleStruct, ...
        phase2Outcome.scheduleStruct);

    % Check if fallback is needed
    needsFallback = obj.shouldFallback(phase2Outcome, combinedSchedule);

    if needsFallback
        if obj.Options.OutpatientInpatientMode == "TwoPhaseAutoFallback"
            % Retry with single-phase optimization
            [dailySchedule, outcome] = obj.fallbackToSinglePhase(cases, ...
                phase1Outcome, phase2Outcome);
            outcome.usedFallback = true;
            outcome.fallbackReason = 'Resource capacity constraints prevented two-phase solution';
        elseif obj.Options.OutpatientInpatientMode == "TwoPhaseStrict"
            % Mark as infeasible, return diagnostic info
            mergedResults = obj.mergeResultsMetadata(combinedSchedule, ...
                phase1Outcome, phase2Outcome);
            dailySchedule = conduction.DailySchedule.fromLegacyStruct(...
                combinedSchedule, mergedResults);

            outcome = obj.buildFailedOutcome(phase1Outcome, phase2Outcome, ...
                combinedSchedule);
            outcome.infeasible = true;
            outcome.infeasibilityReason = 'Resource capacity constraints';
            outcome.ResourceViolations = obj.detectResourceViolations(...
                combinedSchedule, obj.Options.ResourceTypes);
        end
    else
        % Success - return merged schedule
        mergedResults = obj.mergeResultsMetadata(combinedSchedule, ...
            phase1Outcome, phase2Outcome);
        dailySchedule = conduction.DailySchedule.fromLegacyStruct(...
            combinedSchedule, mergedResults);

        outcome = struct();
        outcome.phase1 = phase1Outcome;
        outcome.phase2 = phase2Outcome;
        outcome.objectiveValue = phase1Outcome.objectiveValue + phase2Outcome.objectiveValue;
        outcome.exitflag = [phase1Outcome.exitflag, phase2Outcome.exitflag];
        outcome.scheduleStruct = combinedSchedule;
        outcome.resultsMetadata = mergedResults;
        outcome.usedFallback = false;
    end
end
```

**Add new helper methods:**

```matlab
function locked = convertScheduleToLockedConstraints(obj, scheduleStruct, cases, existingLocked)
    % CONVERTSCHEDULETOLOCKEDCONSTRAINTS Build locked case constraints from phase 1 schedule
    %
    % Inputs:
    %   scheduleStruct - Schedule output from phase 1
    %   cases - Original case structs with resource assignments
    %   existingLocked - Any pre-existing locked constraints to preserve
    %
    % Output:
    %   locked - Array of locked constraint structs with fields:
    %            caseID, startTime, assignedLab

    locked = existingLocked;  % Start with existing locks

    % Build map from caseID to case struct (to get resource info)
    caseMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for idx = 1:numel(cases)
        caseMap(char(cases(idx).caseID)) = cases(idx);
    end

    % Extract locked constraints from schedule
    for labIdx = 1:numel(scheduleStruct.labs)
        labCases = scheduleStruct.labs{labIdx};
        for caseIdx = 1:numel(labCases)
            scheduledCase = labCases(caseIdx);

            constraint = struct();
            constraint.caseID = scheduledCase.caseID;
            constraint.startTime = scheduledCase.startTime;
            constraint.assignedLab = labIdx;

            % Preserve resource assignments from original case
            if isKey(caseMap, char(scheduledCase.caseID))
                originalCase = caseMap(char(scheduledCase.caseID));
                if isfield(originalCase, 'requiredResourceIds')
                    constraint.requiredResourceIds = originalCase.requiredResourceIds;
                end
            end

            locked(end+1) = constraint; %#ok<AGROW>
        end
    end
end

function shouldFallback = shouldFallback(obj, phase2Outcome, combinedSchedule)
    % SHOULDFALLBACK Determine if single-phase fallback is needed
    %
    % Returns true if:
    %   - Phase 2 solver failed to find feasible solution (exitflag < 1)
    %   - Resource violations detected in combined schedule

    shouldFallback = false;

    % Check solver status
    if phase2Outcome.exitflag < 1
        shouldFallback = true;
        return;
    end

    % Check for resource violations
    violations = obj.detectResourceViolations(combinedSchedule, obj.Options.ResourceTypes);
    if ~isempty(violations)
        shouldFallback = true;
    end
end

function violations = detectResourceViolations(obj, scheduleStruct, resourceTypes)
    % DETECTRESOURCEVIOLATIONS Check if resource capacity limits are exceeded
    %
    % Returns array of violation structs with fields:
    %   ResourceId, ResourceName, StartTime, EndTime, Capacity, ActualUsage, CaseIds

    violations = struct([]);

    if isempty(resourceTypes)
        return;
    end

    % Build resource usage timeline
    resourceIds = string({resourceTypes.Id});
    resourceCapacities = arrayfun(@(r) r.Capacity, resourceTypes);

    % Collect all scheduled cases with their resource requirements
    allCases = [];
    for labIdx = 1:numel(scheduleStruct.labs)
        allCases = [allCases, scheduleStruct.labs{labIdx}]; %#ok<AGROW>
    end

    if isempty(allCases)
        return;
    end

    % For each resource, check usage at each time point
    for resIdx = 1:numel(resourceIds)
        resId = resourceIds(resIdx);
        capacity = resourceCapacities(resIdx);

        % Find cases using this resource
        casesUsingResource = [];
        for caseIdx = 1:numel(allCases)
            if isfield(allCases(caseIdx), 'requiredResourceIds')
                if any(string(allCases(caseIdx).requiredResourceIds) == resId)
                    casesUsingResource(end+1) = caseIdx; %#ok<AGROW>
                end
            end
        end

        if isempty(casesUsingResource)
            continue;
        end

        % Check for overlaps
        for i = 1:numel(casesUsingResource)
            case_i = allCases(casesUsingResource(i));
            overlapCount = 1;  % Count self
            overlapCaseIds = {case_i.caseID};

            for j = i+1:numel(casesUsingResource)
                case_j = allCases(casesUsingResource(j));

                % Check if procedure times overlap
                i_procStart = case_i.procStartTime;
                i_procEnd = case_i.procEndTime;
                j_procStart = case_j.procStartTime;
                j_procEnd = case_j.procEndTime;

                overlaps = (i_procStart < j_procEnd) && (j_procStart < i_procEnd);

                if overlaps
                    overlapCount = overlapCount + 1;
                    overlapCaseIds{end+1} = case_j.caseID; %#ok<AGROW>
                end
            end

            % Record violation if capacity exceeded
            if overlapCount > capacity
                violation = struct();
                violation.ResourceId = resId;
                violation.ResourceName = resourceTypes(resIdx).Name;
                violation.StartTime = case_i.procStartTime;
                violation.EndTime = case_i.procEndTime;
                violation.Capacity = capacity;
                violation.ActualUsage = overlapCount;
                violation.CaseIds = overlapCaseIds;
                violations(end+1) = violation; %#ok<AGROW>
            end
        end
    end
end

function [dailySchedule, outcome] = fallbackToSinglePhase(obj, allCases, phase1Outcome, phase2Outcome)
    % FALLBACKTOSINGLEPHASE Retry optimization with all cases together
    %
    % Uses single-phase optimization with priority weighting for outpatients

    singlePhaseOptions = obj.buildSinglePhaseOptions();
    [dailySchedule, outcome] = runPhase(allCases, singlePhaseOptions);

    % Add diagnostic info about fallback
    outcome.originalPhase1 = phase1Outcome;
    outcome.originalPhase2 = phase2Outcome;
    outcome.conflictStats = obj.analyzeOutpatientInpatientMix(dailySchedule);
end

function stats = analyzeOutpatientInpatientMix(obj, schedule)
    % ANALYZEOUTPATIENTINPATIENTMIX Identify inpatients scheduled before outpatients
    %
    % Returns struct with:
    %   inpatientsMovedEarly: count of inpatients before any outpatient
    %   affectedCases: list of caseIDs

    stats = struct();
    stats.inpatientsMovedEarly = 0;
    stats.affectedCases = {};

    % Implementation: compare case start times and admission status
    % Flag inpatients that start before the first outpatient
end

function options = buildSinglePhaseOptions(obj)
    % BUILDSINGLEPHASEOPTIO Configure options for single-phase fallback
    %
    % Modifies objective function to include priority weighting

    baseStruct = obj.Options.toStruct();
    baseStruct.PrioritizeOutpatient = false;  % Using custom weighting instead
    baseStruct.CaseFilter = 'all';
    baseStruct.OutpatientInpatientMode = 'SinglePhaseFlexible';

    options = conduction.scheduling.SchedulingOptions.fromArgs(baseStruct);
end
```

#### 3. OptimizationModelBuilder.m - Locked Case Resource Awareness

**Verify locked cases participate in resource constraints:**

The existing `buildResourceCapacityConstraints()` method should already handle locked cases correctly since it processes all cases in the `caseResourceMatrix`. However, we need to ensure that:

1. Locked cases are included in the preprocessed dataset
2. Their resource assignments are preserved
3. The constraint builder sees them during phase 2

**Check in SchedulingPreprocessor.prepareDataset():**

Locked cases must be included in the case list for phase 2 so they consume resources:

```matlab
% In prepareDataset - ensure locked cases from phase 1 are in the case list
% They should be marked somehow to indicate they're locked
% Their resource assignments must be in caseResourceMatrix
```

**Potential modification needed:**
If locked cases are NOT currently included in the optimization (only as constraints), we need to add them back to the case list with their assignments fixed but still consuming resources.

#### 4. GUI Changes - Optimization Tab

**Add new section in buildOptimizationTab.m:**

```matlab
% Outpatient/Inpatient Handling Section
outpatientInpatientPanel = uipanel(parent, ...
    'Title', 'Outpatient/Inpatient Handling', ...
    'Position', [x, y, width, height]);

% Mode dropdown
modeLabel = uilabel(outpatientInpatientPanel, ...
    'Text', 'Optimization Mode:', ...
    'Position', [10, 60, 120, 22]);

modeDropdown = uidropdown(outpatientInpatientPanel, ...
    'Items', {'Two-Phase (Strict)', 'Two-Phase (Auto-Fallback)', 'Single-Phase (Flexible)'}, ...
    'ItemsData', {'TwoPhaseStrict', 'TwoPhaseAutoFallback', 'SinglePhaseFlexible'}, ...
    'Value', 'TwoPhaseAutoFallback', ...
    'Position', [140, 60, 200, 22], ...
    'ValueChangedFcn', @(src, event) onModeChanged(app, src.Value));

% Help button
helpButton = uibutton(outpatientInpatientPanel, ...
    'Text', '?', ...
    'Position', [345, 60, 25, 22], ...
    'Tooltip', 'Learn about optimization modes', ...
    'ButtonPushedFcn', @(~,~) showOptimizationModeHelp(app));

% Store in app
app.OutpatientInpatientModeDropdown = modeDropdown;
```

**Add help dialog method:**

```matlab
function showOptimizationModeHelp(app)
    % SHOWOPTIMIZATIONMODEHELP Display explanation of optimization modes

    helpText = sprintf([ ...
        '<html><body style="width:400px">' ...
        '<h2>Outpatient/Inpatient Optimization Modes</h2>' ...
        '<p>Controls how the scheduler handles outpatient prioritization vs. resource constraints.</p>' ...
        '' ...
        '<h3>Two-Phase (Strict)</h3>' ...
        '<p><b>Behavior:</b> Outpatients are always scheduled first, no exceptions.</p>' ...
        '<p><b>Use when:</b> Outpatient priority is absolute (policy/regulatory requirement).</p>' ...
        '<p><b>Note:</b> Will fail if resources cannot accommodate inpatients after outpatients.</p>' ...
        '' ...
        '<h3>Two-Phase (Auto-Fallback) [Recommended]</h3>' ...
        '<p><b>Behavior:</b> Tries to schedule outpatients first. If resource constraints ' ...
        'prevent fitting all inpatients, automatically switches to flexible mode and warns you.</p>' ...
        '<p><b>Use when:</b> You prefer outpatients first but want all cases scheduled.</p>' ...
        '<p><b>Performance:</b> Fast when resources aren''t constrained (most cases).</p>' ...
        '' ...
        '<h3>Single-Phase (Flexible)</h3>' ...
        '<p><b>Behavior:</b> Optimizes all cases together. Outpatient priority is a preference, ' ...
        'not a requirement. May schedule some inpatients before outpatients.</p>' ...
        '<p><b>Use when:</b> Makespan/efficiency is more important than strict outpatient ordering.</p>' ...
        '' ...
        '<h3>Resource Constraints</h3>' ...
        '<p>All modes enforce resource capacity limits as hard constraints. ' ...
        'The difference is how they handle conflicts between outpatient priority and resource availability.</p>' ...
        '</body></html>' ...
    ]);

    uialert(app.UIFigure, helpText, 'Optimization Mode Help', ...
        'Icon', 'info', 'Interpreter', 'html');
end
```

**Update OptimizationController.buildScheduleOptions():**

```matlab
function scheduleOptions = buildScheduleOptions(obj, app, casesStruct, lockedConstraints)
    % ... existing code ...

    scheduleOptions = conduction.scheduling.SchedulingOptions.fromArgs( ...
        'NumLabs', numLabs, ...
        'LabStartTimes', startTimes, ...
        'OptimizationMetric', string(app.Opts.metric), ...
        'CaseFilter', string(app.Opts.caseFilter), ...
        'MaxOperatorTime', app.Opts.maxOpMin, ...
        'TurnoverTime', app.Opts.turnover, ...
        'EnforceMidnight', logical(app.Opts.enforceMidnight), ...
        'PrioritizeOutpatient', logical(app.Opts.prioritizeOutpt), ...
        'AvailableLabs', app.AvailableLabIds, ...
        'LockedCaseConstraints', lockedConstraints, ...
        'ResourceTypes', resourceTypes, ...
        'Verbose', true, ...
        'OutpatientInpatientMode', app.OutpatientInpatientModeDropdown.Value);  % NEW
end
```

**Add outcome handling for warnings/errors:**

```matlab
% In OptimizationController.runOptimization() after optimization completes

if isfield(outcome, 'infeasible') && outcome.infeasible
    % Two-Phase Strict mode failed
    msg = sprintf(['Cannot schedule all inpatients due to resource constraints.\n\n' ...
        'Please adjust resource capacity, reduce case load, or change\n' ...
        'outpatient/inpatient optimization handling option.']);

    if isfield(outcome, 'ResourceViolations') && ~isempty(outcome.ResourceViolations)
        msg = [msg sprintf('\n\nResource violations detected:\n')];
        for v = outcome.ResourceViolations
            msg = [msg sprintf('  • %s (capacity=%d, usage=%d) at time %d-%d\n', ...
                v.ResourceName, v.Capacity, v.ActualUsage, v.StartTime, v.EndTime)];
        end
    end

    uialert(app.UIFigure, msg, 'Optimization Failed', 'Icon', 'error');
    return;
end

if isfield(outcome, 'usedFallback') && outcome.usedFallback
    % Two-Phase Auto-Fallback triggered
    msg = sprintf('⚠ Resource Constraints Override\n\n');

    if isfield(outcome, 'conflictStats')
        stats = outcome.conflictStats;
        msg = [msg sprintf(['Resource capacity limits required %d inpatient case(s) ' ...
            'to be scheduled before some outpatients.\n\n'], stats.inpatientsMovedEarly)];

        if ~isempty(stats.affectedCases)
            msg = [msg 'Affected cases:\n'];
            for caseId = stats.affectedCases
                msg = [msg sprintf('  • %s\n', caseId{1})];
            end
        end
    else
        msg = [msg 'Some inpatients were scheduled before outpatients to satisfy resource constraints.'];
    end

    uialert(app.UIFigure, msg, 'Optimization Notice', 'Icon', 'warning');
end
```

### Testing Strategy

#### Unit Tests

1. **Test locked case resource consumption:**
   - Create phase 1 schedule with resource usage
   - Convert to locked constraints
   - Verify phase 2 sees resources as consumed

2. **Test resource violation detection:**
   - Create schedule with overlapping resource usage
   - Verify violations are detected correctly
   - Test edge cases (exact capacity, just over capacity)

3. **Test fallback trigger conditions:**
   - Infeasible phase 2
   - Phase 2 with resource violations
   - Successful phase 2 (no fallback)

#### Integration Tests

1. **Two-Phase Strict mode:**
   - Normal case (resources sufficient) → success
   - Resource conflict case → error with appropriate message

2. **Two-Phase Auto-Fallback mode:**
   - Normal case (resources sufficient) → two-phase success, no warning
   - Resource conflict case → fallback to single-phase, warning displayed

3. **Single-Phase Flexible mode:**
   - All cases optimized together
   - Some inpatients may be before outpatients

#### Manual Testing Scenarios

1. **Create resource bottleneck:**
   - 1 resource with capacity=1
   - 2 outpatients requiring it (60 min each)
   - 2 inpatients requiring it (60 min each)
   - Test all three modes

2. **Mixed resources:**
   - Resource A (capacity=1, used by 1 outpatient + 2 inpatients)
   - Resource B (capacity=2, used by 2 outpatients + 1 inpatient)
   - Verify correct handling

3. **Edge cases:**
   - No resources defined
   - Unlimited capacity resources (should not trigger fallback)
   - All outpatients or all inpatients (single phase should be used)

## Performance Considerations

### Expected Performance Impact

**Two-Phase (Auto-Fallback) - Default Mode:**

| Scenario | Frequency | Runtime Impact |
|----------|-----------|----------------|
| Normal case (no resource conflicts) | ~95% | Same as current (fast) |
| Resource conflict (fallback triggered) | ~5% | 1.5-2x slower |
| **Overall average** | 100% | **~2-5% slower** |

### Optimization Opportunities

If performance becomes an issue:

1. **Early violation detection:** Check resource feasibility before full phase 2 solve
2. **Cached single-phase:** Reuse phase 1 solution as starting point for single-phase
3. **Adaptive mode selection:** Auto-detect likely conflicts and skip two-phase attempt

## Migration and Backwards Compatibility

### Default Behavior

**Current behavior:** Two-phase without resource awareness across phases
**New default:** Two-Phase (Auto-Fallback) with resource awareness

### Breaking Changes

None - new default mode maintains outpatient-first preference while fixing resource violations.

### Migration Path

Users can explicitly set mode if they want different behavior:
- Strict enforcement → `OutpatientInpatientMode = "TwoPhaseStrict"`
- More flexibility → `OutpatientInpatientMode = "SinglePhaseFlexible"`

## Future Enhancements

### Potential Improvements

1. **Resource availability display:**
   - Show resource utilization timeline in GUI
   - Highlight bottleneck resources

2. **Smart fallback:**
   - Partial fallback (keep most outpatients first, move only necessary inpatients)
   - Minimal perturbation approach

3. **What-if analysis:**
   - "What if I add one more unit of resource X?"
   - "What if I delay these 2 outpatients?"

4. **Optimization hints:**
   - Suggest resource capacity increases
   - Identify cases that could be rescheduled to improve fit

## Appendix: Algorithm Pseudocode

### Two-Phase with Auto-Fallback

```
function scheduleTwoPhase(outpatients, inpatients, options):
    // Phase 1: Optimize outpatients
    phase1_schedule = optimizeILP(outpatients, options)

    // Convert to locked constraints
    locked_constraints = []
    for case in phase1_schedule:
        locked_constraints.add({
            caseID: case.id,
            startTime: case.startTime,
            assignedLab: case.lab,
            resourceIds: case.requiredResources
        })

    // Phase 2: Optimize inpatients with locked outpatients
    phase2_options = options.copy()
    phase2_options.lockedCases = locked_constraints
    phase2_options.labStartTimes = computeUpdatedLabStarts(phase1_schedule)
    phase2_options.operatorAvailability = computeOperatorAvailability(phase1_schedule)

    phase2_schedule = optimizeILP(inpatients, phase2_options)

    // Check for resource violations
    combined = merge(phase1_schedule, phase2_schedule)
    violations = detectResourceViolations(combined, options.resources)

    if phase2_schedule.infeasible OR violations.notEmpty():
        if options.mode == "TwoPhaseAutoFallback":
            // Retry with single-phase
            all_cases = outpatients + inpatients
            single_phase_schedule = optimizeILP(all_cases, options)

            // Analyze and warn about inpatient/outpatient mix
            conflicts = analyzeConflicts(single_phase_schedule)
            displayWarning(conflicts)

            return single_phase_schedule
        else:  // TwoPhaseStrict
            displayError("Resource capacity insufficient. Please adjust resources or change mode.")
            return FAILED

    return combined
```

### Resource Violation Detection

```
function detectResourceViolations(schedule, resources):
    violations = []

    for resource in resources:
        if resource.capacity == UNLIMITED:
            continue

        // Find all cases using this resource
        cases_using_resource = []
        for case in schedule.allCases():
            if resource.id in case.requiredResources:
                cases_using_resource.add(case)

        // Check for overlaps
        for i in 0..cases_using_resource.length():
            for j in i+1..cases_using_resource.length():
                case_i = cases_using_resource[i]
                case_j = cases_using_resource[j]

                // Check if procedure times overlap
                if overlap(case_i.procTime, case_j.procTime):
                    // Count total simultaneous usage
                    usage = countSimultaneous(cases_using_resource, case_i.procStartTime)

                    if usage > resource.capacity:
                        violations.add({
                            resource: resource,
                            time: [case_i.procStartTime, case_i.procEndTime],
                            capacity: resource.capacity,
                            actualUsage: usage,
                            cases: getOverlappingCases(cases_using_resource, case_i.procTime)
                        })

    return violations
```

## References

- `HistoricalScheduler.m` - Current two-phase implementation
- `SchedulingOptions.m` - Configuration options
- `OptimizationModelBuilder.m` - ILP constraint generation
- `SchedulingPreprocessor.m` - Data preparation and locked case handling
