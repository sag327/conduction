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
  - **Note:** Locked outpatient resource consumption is NOT enforced during phase 2 optimization
  - Resource violations are detected AFTER merging schedules
- If phase 2 fails or has violations → **automatically retry with single-phase**
- Single-phase allows some inpatients before outpatients to satisfy resource constraints
- Shows warning about which cases were affected

**Resource Blocking Behavior (Current Implementation):**
- Phase 2 optimizer does not see reduced resource capacity from locked outpatients
- Resource violations detected post-merge trigger automatic fallback to single-phase
- This "detect-and-fallback" approach works correctly but may trigger more fallbacks than necessary
- Future enhancement: Pre-block resources in phase 2 to avoid unnecessary fallbacks

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

## Comprehensive Automated Testing Strategy

### Test Infrastructure

The existing MATLAB unit testing framework (`matlab.unittest.TestCase`) provides a solid foundation. Key existing components:
- **Helper functions**: `createTestCase()` for programmatic case creation
- **Resource test baseline**: `TestResourceConstraints.m`
- **CaseManager API**: Allows resource assignment and optimization case building

### Test Suite Overview

**Total**: 48 automated tests across 6 layers
**Execution Time**: ~5-10 minutes for full suite
**Coverage Goal**: >95% of new code

---

### Layer 1: Unit Tests - Core Components (10 tests)

**File**: `tests/matlab/TestOutpatientInpatientResourceConstraints.m`

#### Test Group A: Locked Case Conversion (3 tests)

**Test 1: testConvertScheduleToLockedConstraints_BasicConversion**
```matlab
% Purpose: Verify phase 1 schedule converts to locked constraints correctly
% Setup: Phase 1 schedule with 3 outpatients
% Verify:
%   - Locked constraints contain caseID, startTime, assignedLab
%   - Resource assignments preserved in locked constraints
%   - Count matches schedule
```

**Test 2: testConvertScheduleToLockedConstraints_PreservesExistingLocks**
```matlab
% Purpose: Ensure existing locked cases aren't lost
% Setup: Phase 1 schedule + 2 pre-existing locked constraints
% Verify:
%   - Both old and new locked constraints present
%   - No duplicates
%   - Total count = existing + new
```

**Test 3: testConvertScheduleToLockedConstraints_EmptySchedule**
```matlab
% Purpose: Handle edge case gracefully
% Setup: Empty schedule
% Verify: Returns empty array (no crash)
```

#### Test Group B: Resource Violation Detection (4 tests)

**Test 4: testDetectResourceViolations_NoViolation**
```matlab
% Purpose: Verify clean schedules pass
% Setup: 2 cases sequential (9:00-10:00, 10:00-11:00), capacity=1
% Verify: violations array is empty
```

**Test 5: testDetectResourceViolations_SimpleOverlap**
```matlab
% Purpose: Detect basic overlap
% Setup: Case1 9:00-10:00, Case2 9:30-10:30, capacity=1
% Verify:
%   - 1 violation detected
%   - ResourceId correct
%   - Time window [9:30, 10:00]
%   - ActualUsage = 2, Capacity = 1
%   - Both caseIDs in CaseIds array
```

**Test 6: testDetectResourceViolations_MultipleResources**
```matlab
% Purpose: Independent resource tracking
% Setup:
%   - Resource A: capacity=1, cases overlap
%   - Resource B: capacity=2, 2 cases overlap (within capacity)
% Verify:
%   - Violation only for Resource A
%   - Resource B has no violation
```

**Test 7: testDetectResourceViolations_ExactCapacityNoViolation**
```matlab
% Purpose: Boundary condition
% Setup: 2 cases overlapping, capacity=2
% Verify: No violation (at limit but not over)
```

#### Test Group C: Fallback Decision Logic (3 tests)

**Test 8: testShouldFallback_InfeasiblePhase2**
```matlab
% Purpose: Trigger fallback on solver failure
% Setup: Mock phase2Outcome with exitflag = -1
% Verify: shouldFallback() returns true
```

**Test 9: testShouldFallback_ResourceViolations**
```matlab
% Purpose: Trigger fallback on violations
% Setup: Mock phase2Outcome exitflag=1, but violations detected
% Verify: shouldFallback() returns true
```

**Test 10: testShouldFallback_Success**
```matlab
% Purpose: No fallback when successful
% Setup: exitflag=1, no violations
% Verify: shouldFallback() returns false
```

---

### Layer 2: Integration Tests - Optimization Modes (15 tests)

**File**: `tests/matlab/TestOptimizationModes.m`

#### Test Group D: Two-Phase Strict Mode (5 tests)

**Test 11: testTwoPhaseStrict_NormalCase_NoResourceConflict**
```matlab
% Purpose: Verify strict mode works when resources sufficient
% Setup: 2 outpatients + 2 inpatients, resource capacity=2
% Mode: TwoPhaseStrict
% Verify:
%   - exitflag >= 1 (success)
%   - outcome.usedFallback == false
%   - All outpatients start before all inpatients
%   - 4 cases total in schedule
```

**Test 12: testTwoPhaseStrict_ResourceConflict_Fails**
```matlab
% Purpose: Verify strict mode fails appropriately
% Setup: 2 outpatients + 2 inpatients (all 60min), capacity=1
% Mode: TwoPhaseStrict
% Verify:
%   - outcome.infeasible == true
%   - outcome.ResourceViolations not empty
%   - infeasibilityReason contains "Resource capacity"
```

**Test 13: testTwoPhaseStrict_NoInpatients**
```matlab
% Purpose: Handle single-sided scenario
% Setup: 3 outpatients only, capacity=1
% Mode: TwoPhaseStrict
% Verify:
%   - Success
%   - Only phase 1 executed
%   - 3 cases in schedule
```

**Test 14: testTwoPhaseStrict_NoOutpatients**
```matlab
% Purpose: Handle inpatient-only scenario
% Setup: 3 inpatients only, capacity=1
% Mode: TwoPhaseStrict
% Verify:
%   - Success
%   - Single-phase behavior
%   - 3 cases scheduled
```

**Test 15: testTwoPhaseStrict_LockedCasesConsumeResources**
```matlab
% Purpose: Verify locked cases block resources in phase 2
% Setup:
%   - Outpatient: 9:00-10:00, using Resource A
%   - Inpatient: 9:30-10:30, using Resource A
%   - Resource A capacity = 1
% Mode: TwoPhaseStrict
% Verify:
%   - Phase 2 infeasible or inpatient scheduled after 10:00
%   - No overlap with outpatient
```

#### Test Group E: Two-Phase Auto-Fallback Mode (5 tests)

**Test 16: testAutoFallback_NormalCase_NoFallback**
```matlab
% Purpose: Fast path when resources sufficient
% Setup: 2 outpatients + 2 inpatients, capacity=2
% Mode: TwoPhaseAutoFallback
% Verify:
%   - outcome.usedFallback == false
%   - Two-phase success
%   - All outpatients before inpatients
```

**Test 17: testAutoFallback_ResourceConflict_FallbackTriggered**
```matlab
% Purpose: Verify fallback mechanism
% Setup: 2 outpatients + 2 inpatients, capacity=1
% Mode: TwoPhaseAutoFallback
% Verify:
%   - outcome.usedFallback == true
%   - outcome.fallbackReason contains "Resource"
%   - All 4 cases scheduled
%   - No resource violations in final schedule
```

**Test 18: testAutoFallback_InpatientsBeforeOutpatients_AfterFallback**
```matlab
% Purpose: Verify conflict detection and reporting
% Setup: Same as Test 17
% Mode: TwoPhaseAutoFallback
% Verify:
%   - outcome.conflictStats.inpatientsMovedEarly > 0
%   - outcome.conflictStats.affectedCases contains inpatient caseIDs
%   - Some inpatients have startTime < some outpatients
```

**Test 19: testAutoFallback_MultipleResources_PartialConflict**
```matlab
% Purpose: Mixed resource scenario
% Setup:
%   - Resource A (capacity=1): 1 outpatient + 1 inpatient
%   - Resource B (capacity=2): 2 outpatients + 1 inpatient
% Mode: TwoPhaseAutoFallback
% Verify:
%   - Fallback triggered (Resource A causes conflict)
%   - All cases fit in final schedule
%   - Both resource constraints respected
```

**Test 20: testAutoFallback_FallbackPreservesResourceConstraints**
```matlab
% Purpose: Verify single-phase respects resources
% Setup: 3 cases all using same resource, capacity=1
% Mode: TwoPhaseAutoFallback
% Verify:
%   - No overlapping resource usage in final schedule
%   - All 3 cases scheduled sequentially
```

#### Test Group F: Single-Phase Flexible Mode (5 tests)

**Test 21: testSinglePhaseFlexible_MixedScheduling**
```matlab
% Purpose: Verify flexible mode allows mixing
% Setup: 2 outpatients + 2 inpatients, capacity=2
% Mode: SinglePhaseFlexible
% Verify:
%   - All 4 cases scheduled
%   - Resource constraints respected
%   - May have mixed order (not required to be sequential)
```

**Test 22: testSinglePhaseFlexible_ResourceConstraintsEnforced**
```matlab
% Purpose: Hard constraints still enforced
% Setup: 3 cases using same resource, capacity=1
% Mode: SinglePhaseFlexible
% Verify:
%   - Cases scheduled sequentially
%   - No resource overlaps
```

**Test 23: testSinglePhaseFlexible_NoOutpatients**
```matlab
% Purpose: Edge case handling
% Setup: 3 inpatients only
% Mode: SinglePhaseFlexible
% Verify: All scheduled successfully
```

**Test 24: testSinglePhaseFlexible_NoInpatients**
```matlab
% Purpose: Edge case handling
% Setup: 3 outpatients only
% Mode: SinglePhaseFlexible
% Verify: All scheduled successfully
```

**Test 25: testSinglePhaseFlexible_AllCasesMixed**
```matlab
% Purpose: Stress test with complexity
% Setup: 5 outpatients + 5 inpatients, varied resource usage
% Mode: SinglePhaseFlexible
% Verify:
%   - All 10 cases scheduled
%   - All resource constraints respected
```

---

### Layer 3: Edge Cases and Boundary Conditions (10 tests)

**File**: `tests/matlab/TestOutpatientInpatientEdgeCases.m`

#### Test Group G: Resource Edge Cases (4 tests)

**Test 26: testEdgeCase_UnlimitedCapacityResource**
```matlab
% Purpose: Verify infinite capacity handling
% Setup: Resource capacity = Inf, multiple overlapping cases
% All modes: Should never trigger fallback
% Verify: All cases can overlap freely
```

**Test 27: testEdgeCase_ZeroCapacityResource**
```matlab
% Purpose: Handle impossible resource
% Setup: Resource capacity = 0
% Verify:
%   - Cases using this resource cannot be scheduled
%   - Appropriate error or infeasibility
```

**Test 28: testEdgeCase_NoResourcesDefined**
```matlab
% Purpose: Backwards compatibility
% Setup: Cases without resource assignments
% All modes: Should work as before
% Verify: Optimization completes, mode handling still applies
```

**Test 29: testEdgeCase_SomeResourcesUnlimited**
```matlab
% Purpose: Mixed capacity handling
% Setup: Resource A (capacity=1), Resource B (capacity=Inf)
% Verify: Constraints only enforced for Resource A
```

#### Test Group H: Timing Edge Cases (3 tests)

**Test 30: testEdgeCase_ExactlySimultaneous**
```matlab
% Purpose: Same start/end times
% Setup: 2 cases identical times, same resource
% Verify: Resource violation detected
```

**Test 31: testEdgeCase_BackToBackNonOverlapping**
```matlab
% Purpose: Boundary condition
% Setup: Case1 9:00-10:00, Case2 10:00-11:00, capacity=1
% Verify:
%   - No violation (end == start is OK)
%   - Both scheduled successfully
```

**Test 32: testEdgeCase_OneMinuteOverlap**
```matlab
% Purpose: Minimal overlap detection
% Setup: Case1 9:00-10:00, Case2 9:59-10:59, capacity=1
% Verify:
%   - Violation detected
%   - Fallback triggered in auto mode
```

#### Test Group I: Data Edge Cases (3 tests)

**Test 33: testEdgeCase_EmptyCaseList**
```matlab
% Purpose: Graceful handling
% Setup: No cases
% Verify: Empty schedule returned, no errors
```

**Test 34: testEdgeCase_SingleCase**
```matlab
% Purpose: Minimal scenario
% Setup: 1 outpatient
% Verify: Scheduled successfully in all modes
```

**Test 35: testEdgeCase_OnlyLockedCases**
```matlab
% Purpose: Pre-locked scenario
% Setup: All cases pre-locked (manual locks)
% Verify: Returns locked schedule, no optimization needed
```

---

### Layer 4: Regression Tests (5 tests)

**File**: `tests/matlab/TestOutpatientInpatientRegression.m`

**Test 36: testRegression_BackwardsCompatibility_NoResourcesSpecified**
```matlab
% Purpose: Legacy compatibility
% Setup: Optimization without ResourceTypes in options
% Verify:
%   - No crash
%   - Defaults to TwoPhaseAutoFallback behavior
%   - Works as before (ignores resource logic)
```

**Test 37: testRegression_ExistingLockedCasesPreserved**
```matlab
% Purpose: User locks respected
% Setup: User manually locked 2 cases, phase 1 adds 3 more
% Verify:
%   - All 5 locks present in phase 2
%   - Manual locks + phase 1 locks combined
%   - No duplicates
```

**Test 38: testRegression_OperatorAvailabilityStillWorks**
```matlab
% Purpose: Existing feature preservation
% Setup: Phase 1 completes, operator availability passed to phase 2
% Verify:
%   - Phase 2 respects operator availability
%   - Inpatients don't start before operator free
```

**Test 39: testRegression_LabStartTimesStillUpdated**
```matlab
% Purpose: Lab coordination preserved
% Setup: Phase 1 ends at different times per lab
% Verify:
%   - Phase 2 lab start times updated correctly
%   - Inpatients start after outpatients per-lab
```

**Test 40: testRegression_PrioritizeOutpatientOption_StillWorks**
```matlab
% Purpose: Legacy option compatibility
% Setup: PrioritizeOutpatient = false (old single-phase trigger)
% Verify:
%   - Single-phase behavior activated
%   - Cases mixed regardless of admission status
```

---

### Layer 5: Performance and Scale Tests (3 tests)

**File**: `tests/matlab/TestOutpatientInpatientPerformance.m`

**Test 41: testPerformance_LargeCase_TwoPhaseSpeed**
```matlab
% Purpose: Verify fast path performance
% Setup: 20 outpatients + 20 inpatients, no conflicts, capacity=5
% Mode: TwoPhaseAutoFallback
% Measure: Execution time
% Verify:
%   - No fallback triggered
%   - Completes within 2x baseline (baseline = current two-phase)
```

**Test 42: testPerformance_LargeCase_FallbackCost**
```matlab
% Purpose: Measure fallback overhead
% Setup: 20 outpatients + 20 inpatients, capacity=1 (forces conflict)
% Mode: TwoPhaseAutoFallback
% Measure: Total time (two-phase attempt + single-phase retry)
% Verify:
%   - Fallback triggered
%   - Completes within 5x baseline
%   - Produces valid schedule
```

**Test 43: testPerformance_StrictMode_QuickFailure**
```matlab
% Purpose: Verify strict mode fails fast
% Setup: Resource conflict scenario
% Mode: TwoPhaseStrict
% Measure: Time to failure
% Verify:
%   - Fails quickly (< 10% of fallback retry time)
%   - Doesn't waste time on retry
```

---

### Layer 6: Diagnostic and Reporting Tests (5 tests)

**File**: `tests/matlab/TestOutpatientInpatientDiagnostics.m`

**Test 44: testDiagnostics_ViolationReportAccuracy**
```matlab
% Purpose: Verify diagnostic data quality
% Setup: Multiple overlapping cases creating violations
% Verify ResourceViolations array contains:
%   - Correct ResourceId, ResourceName
%   - Accurate StartTime, EndTime
%   - Correct Capacity vs ActualUsage
%   - Complete CaseIds list
```

**Test 45: testDiagnostics_ConflictStatsAccuracy**
```matlab
% Purpose: Verify fallback reporting
% Setup: Fallback scenario with 2 inpatients moved early
% Verify outcome.conflictStats:
%   - inpatientsMovedEarly = 2
%   - affectedCases contains exactly those 2 caseIDs
%   - Only truly early inpatients flagged
```

**Test 46: testDiagnostics_FallbackReason_Descriptive**
```matlab
% Purpose: User-friendly error messages
% Setup: Various fallback triggers
% Verify:
%   - fallbackReason is non-empty string
%   - Contains keywords: "Resource", "capacity", "constraints"
%   - Helpful to user
```

**Test 47: testDiagnostics_PhaseOutcomes_Preserved**
```matlab
% Purpose: Debug information retention
% Setup: Successful two-phase optimization
% Verify outcome structure:
%   - outcome.phase1 present with objectiveValue, exitflag
%   - outcome.phase2 present with objectiveValue, exitflag
%   - Can trace back each phase's results
```

**Test 48: testDiagnostics_InfeasibilityReason_Helpful**
```matlab
% Purpose: Actionable error messages
% Setup: TwoPhaseStrict failure
% Verify:
%   - infeasibilityReason is descriptive
%   - Suggests solutions (adjust capacity, reduce load, change mode)
```

---

## Test Execution Strategy

### Running Tests

**Quick Smoke Test** (~1 minute, 10 tests):
```matlab
% Run core unit tests only
runtests('tests/matlab/TestOutpatientInpatientResourceConstraints.m');
```

**Full Test Suite** (~5-10 minutes, 48 tests):
```matlab
% Run all tests
results = runtests('tests/matlab/TestOutpatientInpatient*.m');
disp(results);
```

**Performance Benchmarks** (separate run):
```matlab
% Performance tests can be slow, run separately
runtests('tests/matlab/TestOutpatientInpatientPerformance.m');
```

**Coverage Report**:
```matlab
import matlab.unittest.TestRunner;
import matlab.unittest.plugins.CodeCoveragePlugin;
import matlab.unittest.plugins.codecoverage.CoverageReport;

suite = testsuite('tests/matlab/TestOutpatientInpatient*.m');
runner = TestRunner.withTextOutput;

% Add coverage for new code
sourceDir = fullfile('scripts', '+conduction', '+scheduling');
plugin = CodeCoveragePlugin.forFolder(sourceDir, ...
    'Producing', CoverageReport('coverage-report'));
runner.addPlugin(plugin);

results = runner.run(suite);
```

### Continuous Integration

```matlab
% CI script: run_tests.m
function exitCode = run_tests()
    % Run all tests and generate reports
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.XMLPlugin;
    import matlab.unittest.plugins.CodeCoveragePlugin;

    suite = testsuite('tests/matlab/TestOutpatientInpatient*.m');
    runner = TestRunner.withTextOutput;

    % JUnit XML for CI systems
    runner.addPlugin(XMLPlugin.producingJUnitFormat('test-results.xml'));

    % Coverage report
    runner.addPlugin(CodeCoveragePlugin.forFolder('scripts', ...
        'Producing', CoverageReport('coverage')));

    results = runner.run(suite);

    % Exit code: 0 if all pass, 1 if any fail
    exitCode = double(~all([results.Passed]));
end
```

### Test Data Helpers

Create reusable test fixtures:

```matlab
% tests/matlab/helpers/createResourceConflictScenario.m
function [outpatients, inpatients, resources] = createResourceConflictScenario(numOut, numIn, capacity)
    % Create scenario designed to trigger resource conflicts

    store = conduction.gui.stores.ResourceStore();
    resource = store.create("TestResource", capacity);

    outpatients = [];
    for i = 1:numOut
        caseObj = createTestCase(sprintf('Dr. Out%d', i), 'Outpatient Procedure', 60, 'outpatient');
        caseObj.assignResource(resource.Id);
        outpatients(end+1) = caseObj; %#ok<AGROW>
    end

    inpatients = [];
    for i = 1:numIn
        caseObj = createTestCase(sprintf('Dr. In%d', i), 'Inpatient Procedure', 60, 'inpatient');
        caseObj.assignResource(resource.Id);
        inpatients(end+1) = caseObj; %#ok<AGROW>
    end

    resources = store.snapshot();
end
```

### Coverage Goals

- **Line Coverage**: >95% for all new methods in:
  - `HistoricalScheduler.scheduleTwoPhase()`
  - `HistoricalScheduler.convertScheduleToLockedConstraints()`
  - `HistoricalScheduler.shouldFallback()`
  - `HistoricalScheduler.detectResourceViolations()`
  - `HistoricalScheduler.fallbackToSinglePhase()`

- **Branch Coverage**: 100% for:
  - Mode selection switch statements
  - Fallback decision logic
  - Resource violation detection loops

- **Path Coverage**: All execution paths:
  - Two-phase success (no fallback)
  - Two-phase → fallback → success
  - Two-phase → failure (strict mode)
  - Single-phase direct

### Test Maintenance

**After each implementation session:**
1. Run affected test group
2. Update test if behavior intentionally changed
3. Add new test if edge case discovered
4. Verify coverage hasn't decreased

**Before merging:**
1. Run full test suite
2. All 48 tests must pass
3. Coverage >95%
4. No performance regressions

---

## References

- `HistoricalScheduler.m` - Current two-phase implementation
- `SchedulingOptions.m` - Configuration options
- `OptimizationModelBuilder.m` - ILP constraint generation
- `SchedulingPreprocessor.m` - Data preparation and locked case handling
- `TestResourceConstraints.m` - Existing resource test baseline
