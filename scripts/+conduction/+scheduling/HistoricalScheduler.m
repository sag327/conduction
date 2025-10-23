classdef HistoricalScheduler
    %HISTORICALSCHEDULER Orchestrates ILP scheduling for historical cases.

    properties (SetAccess = immutable)
        Options (1,1) conduction.scheduling.SchedulingOptions
    end

    methods
        function obj = HistoricalScheduler(options)
            arguments
                options (1,1) conduction.scheduling.SchedulingOptions
            end
            obj.Options = options;
        end

        function [dailySchedule, outcome] = schedule(obj, cases)
            cases = obj.ensureStructArray(cases);
            filteredCases = obj.applyCaseFilter(cases, obj.Options.CaseFilter);

            if isempty(filteredCases)
                [dailySchedule, outcome] = obj.buildEmptyResult();
                return;
            end

            if obj.Options.isTwoPhaseEnabled()
                [dailySchedule, outcome] = obj.scheduleTwoPhase(filteredCases);
            else
                [dailySchedule, outcome] = conduction.scheduling.HistoricalScheduler.runPhase(filteredCases, obj.Options);
            end
        end
    end

    methods (Access = private)
        function [dailySchedule, outcome] = scheduleTwoPhase(obj, cases)
            [outpatientCases, inpatientCases] = obj.partitionCases(cases);

            if isempty(outpatientCases)
                [dailySchedule, outcome] = conduction.scheduling.HistoricalScheduler.runPhase(cases, obj.Options);
                return;
            end

            % Phase 1 - Optimize outpatients only
            fprintf('\n[DEBUG] ========== PHASE 1 (Outpatients) ==========\n');
            fprintf('[DEBUG] Outpatient cases: %d\n', numel(outpatientCases));
            for i = 1:numel(outpatientCases)
                if isfield(outpatientCases(i), 'requiredResourceIds')
                    fprintf('[DEBUG]   Case %s: resources = %s\n', ...
                        char(outpatientCases(i).caseID), ...
                        strjoin(string(outpatientCases(i).requiredResourceIds), ', '));
                end
            end

            phase1Options = obj.buildPhase1Options();
            [phase1Daily, phase1Outcome] = conduction.scheduling.HistoricalScheduler.runPhase(outpatientCases, phase1Options);

            if isempty(inpatientCases)
                % No inpatients to schedule
                dailySchedule = phase1Daily;
                outcome = obj.buildPhase1OnlyOutcome(phase1Outcome);
                return;
            end

            % Convert phase 1 results to locked constraints for phase 2
            lockedConstraints = obj.convertScheduleToLockedConstraints(...
                phase1Outcome.scheduleStruct, outpatientCases, obj.Options.LockedCaseConstraints);

            fprintf('\n[DEBUG] ========== LOCKED CONSTRAINTS ==========\n');
            fprintf('[DEBUG] Total locked constraints: %d\n', numel(lockedConstraints));
            for i = 1:numel(lockedConstraints)
                if isfield(lockedConstraints(i), 'requiredResourceIds')
                    fprintf('[DEBUG]   Locked case %s: lab=%d, startTime=%.1f, resources=%s\n', ...
                        char(lockedConstraints(i).caseID), ...
                        lockedConstraints(i).assignedLab, ...
                        lockedConstraints(i).startTime, ...
                        strjoin(string(lockedConstraints(i).requiredResourceIds), ', '));
                end
            end

            % Phase 2 - Optimize inpatients with locked outpatients
            fprintf('\n[DEBUG] ========== PHASE 2 (Inpatients) ==========\n');
            fprintf('[DEBUG] Inpatient cases: %d\n', numel(inpatientCases));
            for i = 1:numel(inpatientCases)
                if isfield(inpatientCases(i), 'requiredResourceIds')
                    fprintf('[DEBUG]   Case %s: resources = %s\n', ...
                        char(inpatientCases(i).caseID), ...
                        strjoin(string(inpatientCases(i).requiredResourceIds), ', '));
                end
            end

            phase2Options = obj.buildPhase2Options(phase1Outcome.scheduleStruct, lockedConstraints);
            fprintf('[DEBUG] Phase 2 options - LockedCaseConstraints count: %d\n', numel(phase2Options.LockedCaseConstraints));

            [phase2Daily, phase2Outcome] = conduction.scheduling.HistoricalScheduler.runPhase(inpatientCases, phase2Options);

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

        function cases = applyCaseFilter(~, cases, filter)
            filter = string(filter);
            if filter == "all"
                return;
            end

            switch filter
                case "outpatient"
                    selector = @(c) conduction.scheduling.HistoricalScheduler.isOutpatient(c);
                case "inpatient"
                    selector = @(c) conduction.scheduling.HistoricalScheduler.isInpatient(c);
                otherwise
                    error('HistoricalScheduler:InvalidCaseFilter', 'Unknown case filter: %s', filter);
            end

            mask = arrayfun(selector, cases);
            cases = cases(mask);
        end

        function [outpatientCases, inpatientCases] = partitionCases(~, cases)
            isOut = arrayfun(@conduction.scheduling.HistoricalScheduler.isOutpatient, cases);
            isIn = arrayfun(@conduction.scheduling.HistoricalScheduler.isInpatient, cases);
            outpatientCases = cases(isOut);
            inpatientCases = cases(isIn);
        end

        function [labStarts, operatorAvailability] = calculateUpdatedLabAvailability(~, scheduleStruct, originalStarts)
            labStarts = originalStarts;
            operatorAvailability = containers.Map('KeyType','char','ValueType','double');

            for labIdx = 1:numel(scheduleStruct.labs)
                labSchedule = scheduleStruct.labs{labIdx};
                if isempty(labSchedule)
                    continue;
                end
                latestEnd = max([labSchedule.endTime]);
                hours = floor(latestEnd / 60);
                minutes = mod(latestEnd, 60);
                if hours >= 24
                    hours = 23; minutes = 59;
                end
                labStarts{labIdx} = sprintf('%02d:%02d', hours, minutes);
            end

            if ~isempty(scheduleStruct.operators)
                operatorKeys = keys(scheduleStruct.operators);
                for idx = 1:numel(operatorKeys)
                    name = operatorKeys{idx};
                    entries = scheduleStruct.operators(name);
                    endTimes = arrayfun(@(entry) entry.caseInfo.procEndTime, entries);
                    availability = max(endTimes);
                    operatorAvailability(name) = availability;
                end
            end
        end

        function [dailySchedule, outcome] = buildEmptyResult(obj)
            numLabs = obj.Options.NumLabs;
            scheduleStruct = struct();
            scheduleStruct.labs = cell(numLabs,1);
            scheduleStruct.operators = containers.Map();

            resultsStruct = struct();
            labStartMinutes = obj.parseLabStarts(obj.Options.LabStartTimes);
            resultsStruct.timeRangeMinutes = [min(labStartMinutes), min(labStartMinutes)];
            resultsStruct.scheduleStart = min(labStartMinutes);
            resultsStruct.scheduleEnd = min(labStartMinutes);
            resultsStruct.makespan = 0;
            resultsStruct.objectiveValue = NaN;
            resultsStruct.exitflag = NaN;
            resultsStruct.optimizationMetric = obj.Options.normalizedMetric();
            resultsStruct.solverOutput = struct();

            dailySchedule = conduction.DailySchedule.fromLegacyStruct(scheduleStruct, resultsStruct);

            outcome = struct();
            outcome.objectiveValue = NaN;
            outcome.exitflag = NaN;
            outcome.scheduleStruct = scheduleStruct;
            outcome.resultsMetadata = resultsStruct;
            outcome.decisionVariables = [];
        end

        function cases = ensureStructArray(~, cases)
            if isa(cases, 'conduction.DailySchedule')
                cases = cases.toOptimizationCases();
            elseif isa(cases, 'conduction.CaseRequest')
                error('HistoricalScheduler:UnsupportedInput', ...
                    'Convert CaseRequest objects to legacy optimization struct before scheduling.');
            end
            if ~isstruct(cases)
                error('HistoricalScheduler:InvalidCases', 'Cases must be provided as struct array.');
            end
        end

        function combined = mergeSchedules(~, schedule1, schedule2)
            combined = struct();
            combined.labs = schedule1.labs;
            combined.operators = containers.Map();

            if ~isempty(schedule1.operators)
                keys1 = keys(schedule1.operators);
                for idx = 1:numel(keys1)
                    key = keys1{idx};
                    combined.operators(key) = schedule1.operators(key);
                end
            end

            numLabs = numel(schedule1.labs);
            for labIdx = 1:numLabs
                cases1 = schedule1.labs{labIdx};
                cases2 = schedule2.labs{labIdx};
                combinedCases = [cases1, cases2];
                if isempty(combinedCases)
                    combined.labs{labIdx} = struct([]);
                else
                    [~, sortIdx] = sort([combinedCases.startTime]);
                    combined.labs{labIdx} = combinedCases(sortIdx);
                end
            end

            keys2 = keys(schedule2.operators);
            for idx = 1:numel(keys2)
                name = keys2{idx};
                entries = schedule2.operators(name);
                if isKey(combined.operators, name)
                    combinedEntries = combined.operators(name);
                    combinedEntries = [combinedEntries, entries];
                    procStarts = arrayfun(@(entry) entry.caseInfo.procStartTime, combinedEntries);
                    [~, sortIdx] = sort(procStarts);
                    combined.operators(name) = combinedEntries(sortIdx);
                else
                    combined.operators(name) = entries;
                end
            end
        end

        function results = mergeResultsMetadata(obj, scheduleStruct, phase1Outcome, phase2Outcome)
            labStartMinutes = obj.parseLabStarts(obj.Options.LabStartTimes);
            startTimes = [];
            endTimes = [];
            for labIdx = 1:numel(scheduleStruct.labs)
                labCases = scheduleStruct.labs{labIdx};
                if isempty(labCases), continue; end
                startTimes = [startTimes, [labCases.startTime]]; %#ok<AGROW>
                endTimes = [endTimes, [labCases.endTime]]; %#ok<AGROW>
            end
            if isempty(startTimes)
                timeRange = [min(labStartMinutes), min(labStartMinutes)];
            else
                timeRange = [min(startTimes), max(endTimes)];
            end

            results = struct();
            results.objectiveValue = phase1Outcome.objectiveValue + phase2Outcome.objectiveValue;
            results.exitflag = [phase1Outcome.exitflag, phase2Outcome.exitflag];
            results.solverOutput = struct('phase1', phase1Outcome.output, 'phase2', phase2Outcome.output);
            results.optimizationMetric = obj.Options.normalizedMetric();
            results.timeRangeMinutes = timeRange;
            results.scheduleStart = min(labStartMinutes);
            results.scheduleEnd = max([labStartMinutes(:); timeRange(2)]);
            results.makespan = results.scheduleEnd - results.scheduleStart;
        end
    end

    methods (Static)
        function [dailySchedule, outcome] = runPhase(cases, options)
            if isempty(cases)
                scheduler = conduction.scheduling.HistoricalScheduler(options);
                [dailySchedule, outcome] = scheduler.buildEmptyResult();
                return;
            end

            prepared = conduction.scheduling.SchedulingPreprocessor.prepareDataset(cases, options);
            model = conduction.scheduling.OptimizationModelBuilder.build(prepared, options);
            [solution, solverInfo] = conduction.scheduling.OptimizationSolver.solve(model, options);
            [dailySchedule, outcome] = conduction.scheduling.ScheduleAssembler.assemble(prepared, model, solution, solverInfo, options);
        end

        function tf = isOutpatient(caseStruct)
            if ~isfield(caseStruct, 'admissionStatus') || isempty(caseStruct.admissionStatus)
                tf = true;
                return;
            end

            statusValue = lower(strtrim(string(caseStruct.admissionStatus)));
            outpatientValues = ["outpatient", "ambulatory", "hospital outpatient surgery (amb proc)"];
            tf = any(strcmp(statusValue, outpatientValues));
        end

        function tf = isInpatient(caseStruct)
            if ~isfield(caseStruct, 'admissionStatus') || isempty(caseStruct.admissionStatus)
                tf = false;
                return;
            end

            statusValue = lower(strtrim(string(caseStruct.admissionStatus)));
            inpatientValues = ["inpatient", "ip"];
            tf = any(strcmp(statusValue, inpatientValues));
        end
    end

    methods (Static, Access = private)
        function minutes = parseLabStarts(startTimes)
            minutes = zeros(1, numel(startTimes));
            for idx = 1:numel(startTimes)
                timeStr = startTimes{idx};
                if isstring(timeStr); timeStr = char(timeStr); end
                parts = strsplit(timeStr, ':');
                minutes(idx) = str2double(parts{1}) * 60 + str2double(parts{2});
            end
        end
    end

    methods (Access = {?matlab.unittest.TestCase, ?conduction.scheduling.HistoricalScheduler})
        function locked = convertScheduleToLockedConstraints(obj, scheduleStruct, cases, existingLocked)
            %CONVERTSCHEDULETOLOCKEDCONSTRAINTS Build locked case constraints from phase 1 schedule
            %
            % Inputs:
            %   scheduleStruct - Schedule output from phase 1
            %   cases - Original case structs with resource assignments
            %   existingLocked - Any pre-existing locked constraints to preserve
            %
            % Output:
            %   locked - Array of locked constraint structs with fields:
            %            caseID, startTime, assignedLab

            % Define consistent struct template with all possible fields
            constraintTemplate = struct(...
                'caseID', '', ...
                'startTime', NaN, ...
                'assignedLab', NaN, ...
                'requiredResourceIds', {{}}, ...
                'procTime', NaN, ...
                'setupTime', NaN, ...
                'procStartTime', NaN, ...
                'procEndTime', NaN);

            % Initialize with consistent struct template
            if isempty(existingLocked)
                locked = repmat(constraintTemplate, 0, 1);
            else
                locked = existingLocked;
                % Ensure existing locked constraints have all fields
                locked = obj.ensureConstraintFields(locked, constraintTemplate);
            end

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

                    % Start with template to ensure all fields exist
                    constraint = constraintTemplate;
                    constraint.caseID = scheduledCase.caseID;
                    constraint.startTime = scheduledCase.startTime;
                    constraint.assignedLab = labIdx;
                    constraint.requiredResourceIds = {};  % Default empty

                    % Preserve resource assignments and timing from original case
                    if isKey(caseMap, char(scheduledCase.caseID))
                        originalCase = caseMap(char(scheduledCase.caseID));
                        if isfield(originalCase, 'requiredResourceIds')
                            constraint.requiredResourceIds = originalCase.requiredResourceIds;
                        end
                        % Add procedure timing for resource capacity calculations
                        if isfield(originalCase, 'procTime')
                            constraint.procTime = originalCase.procTime;
                        end
                        if isfield(originalCase, 'setupTime')
                            constraint.setupTime = originalCase.setupTime;
                        end
                    end

                    % Extract timing from scheduled case
                    if isfield(scheduledCase, 'procStartTime')
                        constraint.procStartTime = scheduledCase.procStartTime;
                    end
                    if isfield(scheduledCase, 'procEndTime')
                        constraint.procEndTime = scheduledCase.procEndTime;
                    end

                    locked(end+1) = constraint; %#ok<AGROW>
                end
            end
        end

        function violations = detectResourceViolations(obj, scheduleStruct, resourceTypes)
            %DETECTRESOURCEVIOLATIONS Check if resource capacity limits are exceeded
            %
            % Returns array of violation structs with fields:
            %   ResourceId, ResourceName, StartTime, EndTime, Capacity, ActualUsage, CaseIds

            % Initialize with template to ensure consistent struct fields
            violationTemplate = struct(...
                'ResourceId', "", ...
                'ResourceName', "", ...
                'StartTime', 0, ...
                'EndTime', 0, ...
                'Capacity', 0, ...
                'ActualUsage', 0, ...
                'CaseIds', {{}});
            violations = repmat(violationTemplate, 0, 1);

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

        function shouldFallback = shouldFallback(obj, phase2Outcome, combinedSchedule)
            %SHOULDFALLBACK Determine if single-phase fallback is needed
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

        function [dailySchedule, outcome] = fallbackToSinglePhase(obj, allCases, phase1Outcome, phase2Outcome)
            %FALLBACKTOSINGLEPHASE Retry optimization with all cases together
            %
            % Uses single-phase optimization with priority weighting for outpatients

            singlePhaseOptions = obj.buildSinglePhaseOptions();
            [dailySchedule, outcome] = conduction.scheduling.HistoricalScheduler.runPhase(allCases, singlePhaseOptions);

            % Add diagnostic info about fallback
            outcome.originalPhase1 = phase1Outcome;
            outcome.originalPhase2 = phase2Outcome;
            outcome.conflictStats = obj.analyzeOutpatientInpatientMix(dailySchedule);
        end

        function stats = analyzeOutpatientInpatientMix(obj, schedule)
            %ANALYZEOUTPATIENTINPATIENTMIX Identify inpatients scheduled before outpatients
            %
            % Returns struct with:
            %   inpatientsMovedEarly: count of inpatients before any outpatient
            %   affectedCases: list of caseIDs

            stats = struct();
            stats.inpatientsMovedEarly = 0;
            stats.affectedCases = {};

            % Extract cases from schedule
            allCases = [];
            if isfield(schedule, 'Cases') && ~isempty(schedule.Cases)
                allCases = schedule.Cases;
            elseif isfield(schedule, 'labs')
                for labIdx = 1:numel(schedule.labs)
                    allCases = [allCases, schedule.labs{labIdx}]; %#ok<AGROW>
                end
            end

            if isempty(allCases)
                return;
            end

            % Find earliest outpatient start time
            earliestOutpatientTime = inf;
            for caseIdx = 1:numel(allCases)
                caseStruct = allCases(caseIdx);
                if isfield(caseStruct, 'admissionStatus')
                    if conduction.scheduling.HistoricalScheduler.isOutpatient(caseStruct)
                        if isfield(caseStruct, 'startTime')
                            earliestOutpatientTime = min(earliestOutpatientTime, caseStruct.startTime);
                        elseif isfield(caseStruct, 'procStartTime')
                            earliestOutpatientTime = min(earliestOutpatientTime, caseStruct.procStartTime);
                        end
                    end
                end
            end

            % Count inpatients that start before earliest outpatient
            if isfinite(earliestOutpatientTime)
                for caseIdx = 1:numel(allCases)
                    caseStruct = allCases(caseIdx);
                    if isfield(caseStruct, 'admissionStatus')
                        if conduction.scheduling.HistoricalScheduler.isInpatient(caseStruct)
                            caseStartTime = inf;
                            if isfield(caseStruct, 'startTime')
                                caseStartTime = caseStruct.startTime;
                            elseif isfield(caseStruct, 'procStartTime')
                                caseStartTime = caseStruct.procStartTime;
                            end

                            if caseStartTime < earliestOutpatientTime
                                stats.inpatientsMovedEarly = stats.inpatientsMovedEarly + 1;
                                stats.affectedCases{end+1} = caseStruct.caseID; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        function options = buildSinglePhaseOptions(obj)
            %BUILDSINGLEPHASEOPTIO Configure options for single-phase fallback
            %
            % Modifies objective function to include priority weighting

            baseStruct = obj.Options.toStruct();
            baseStruct.PrioritizeOutpatient = false;  % Using custom weighting instead
            baseStruct.CaseFilter = 'all';
            baseStruct.OutpatientInpatientMode = 'SinglePhaseFlexible';

            options = conduction.scheduling.SchedulingOptions.fromArgs(baseStruct);
        end

        function options = buildPhase1Options(obj)
            %BUILDPHASE1OPTIONS Configure options for phase 1 (outpatients only)

            baseStruct = obj.Options.toStruct();
            baseStruct.PrioritizeOutpatient = false;
            baseStruct.CaseFilter = 'all';
            baseStruct.OperatorAvailability = containers.Map('KeyType','char','ValueType','double');

            options = conduction.scheduling.SchedulingOptions.fromArgs(baseStruct);
        end

        function options = buildPhase2Options(obj, phase1Schedule, lockedConstraints)
            %BUILDPHASE2OPTIONS Configure options for phase 2 (inpatients with locked outpatients)

            [updatedStarts, operatorAvailability] = obj.calculateUpdatedLabAvailability(...
                phase1Schedule, obj.Options.LabStartTimes);

            phase2Struct = obj.Options.toStruct();
            phase2Struct.PrioritizeOutpatient = false;
            phase2Struct.CaseFilter = 'all';
            phase2Struct.LabStartTimes = updatedStarts;
            phase2Struct.OperatorAvailability = operatorAvailability;
            phase2Struct.LockedCaseConstraints = lockedConstraints;

            options = conduction.scheduling.SchedulingOptions.fromArgs(phase2Struct);
        end

        function outcome = buildPhase1OnlyOutcome(obj, phase1Outcome)
            %BUILDPHASE1ONLYOUTCOME Build outcome struct when only outpatients were scheduled

            outcome = struct(...
                'phase1', phase1Outcome, ...
                'objectiveValue', phase1Outcome.objectiveValue, ...
                'exitflag', phase1Outcome.exitflag, ...
                'scheduleStruct', phase1Outcome.scheduleStruct, ...
                'resultsMetadata', phase1Outcome.resultsMetadata, ...
                'usedFallback', false);
        end

        function outcome = buildFailedOutcome(obj, phase1Outcome, phase2Outcome, combinedSchedule)
            %BUILDFAILEDOUTCOME Build outcome struct for TwoPhaseStrict failure

            outcome = struct();
            outcome.phase1 = phase1Outcome;
            outcome.phase2 = phase2Outcome;
            outcome.objectiveValue = phase1Outcome.objectiveValue + phase2Outcome.objectiveValue;
            outcome.exitflag = [phase1Outcome.exitflag, phase2Outcome.exitflag];
            outcome.scheduleStruct = combinedSchedule;
            outcome.usedFallback = false;
        end

        function constraints = ensureConstraintFields(~, constraints, template)
            %ENSURECONSTRAINTFIELDS Ensure all constraints have fields from template

            if isempty(constraints)
                return;
            end

            templateFields = fieldnames(template);
            existingFields = fieldnames(constraints);
            missingFields = setdiff(templateFields, existingFields);

            % Add missing fields with default values from template
            for i = 1:numel(missingFields)
                fieldName = missingFields{i};
                defaultValue = template.(fieldName);
                for idx = 1:numel(constraints)
                    constraints(idx).(fieldName) = defaultValue;
                end
            end

            % Reorder fields to match template
            constraints = orderfields(constraints, templateFields);
        end
    end
end
