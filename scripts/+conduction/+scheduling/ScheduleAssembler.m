classdef ScheduleAssembler
    %SCHEDULEASSEMBLER Convert solver output into schedule structures.

    methods (Static)
        function [dailySchedule, outcome] = assemble(prepared, model, solution, solverInfo, options)
            arguments
                prepared struct
                model struct
                solution double
                solverInfo struct
                options (1,1) conduction.scheduling.SchedulingOptions
            end

            numCases = model.numCases;
            numLabs = model.numLabs;
            numTimeSlots = model.numTimeSlots;
            timeSlots = model.timeSlots;
            getVarIndex = model.getVarIndex;

            turnoverTime = model.turnoverTime;
            labStartMinutes = model.labStartMinutes;
            uniqueOperators = model.uniqueOperators;

            if isfield(prepared, 'resourceIds')
                resourceIds = prepared.resourceIds;
            else
                resourceIds = string.empty(0, 1);
            end

            if isfield(prepared, 'resourceCapacities')
                resourceCapacities = prepared.resourceCapacities;
            else
                resourceCapacities = double.empty(0, 1);
            end

            if isfield(prepared, 'resourceTypes')
                resourceTypes = prepared.resourceTypes;
            else
                resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            end

            if isfield(prepared, 'caseResourceIds')
                caseResourceIds = prepared.caseResourceIds;
            else
                caseResourceIds = repmat({string.empty(0, 1)}, numCases, 1);
            end

            if numel(prepared.cases) ~= numCases
                error('ScheduleAssembler:SizeMismatch', ...
                    'prepared.cases size (%d) does not match model.numCases (%d)', ...
                    numel(prepared.cases), numCases);
            end

            scheduleStruct = struct();
            scheduleStruct.labs = cell(numLabs, 1);
            scheduleStruct.operators = containers.Map();

            allStartTimes = [];
            allEndTimes = [];
            scheduledResourceIntervals = struct('CaseId', {}, 'Resources', {}, 'ProcStart', {}, 'ProcEnd', {});

            for caseIdx = 1:numCases
                assigned = false;
                assignedInfo = struct();
                for labIdx = 1:numLabs
                    validSlots = model.validTimeSlots{labIdx};
                    for t = validSlots(:)'
                        varIdx = getVarIndex(caseIdx, labIdx, t);
                        if solution(varIdx) > 0.5
                            startTime = timeSlots(t);
                            setupTime = model.caseSetupTimes(caseIdx);
                            procTime = model.caseProcTimes(caseIdx);
                            postTime = model.casePostTimes(caseIdx);

                            caseInfo = conduction.scheduling.ScheduleAssembler.buildCaseInfo(prepared.cases(caseIdx), ...
                                labIdx, startTime, setupTime, procTime, postTime, turnoverTime);

                            if isempty(scheduleStruct.labs{labIdx})
                                scheduleStruct.labs{labIdx} = caseInfo;
                            else
                                scheduleStruct.labs{labIdx}(end+1) = caseInfo;
                            end

                            opName = caseInfo.operator;
                            operatorEntry = struct('lab', labIdx, 'caseInfo', caseInfo);
                            if isKey(scheduleStruct.operators, opName)
                                entries = scheduleStruct.operators(opName);
                                entries(end+1) = operatorEntry;
                                scheduleStruct.operators(opName) = entries;
                            else
                                scheduleStruct.operators(opName) = operatorEntry;
                            end

                            allStartTimes(end+1) = caseInfo.startTime; %#ok<AGROW>
                            allEndTimes(end+1) = caseInfo.endTime; %#ok<AGROW>

                            if caseIdx <= numel(caseResourceIds)
                                resourcesForCase = string(caseResourceIds{caseIdx});
                                resourcesForCase = resourcesForCase(strlength(resourcesForCase) > 0);
                            else
                                resourcesForCase = string.empty(0, 1);
                            end
                            scheduledResourceIntervals(end+1) = struct( ...
                                'CaseId', string(caseInfo.caseID), ...
                                'Resources', resourcesForCase(:), ...
                                'ProcStart', caseInfo.procStartTime, ...
                                'ProcEnd', caseInfo.procEndTime); %#ok<AGROW>

                            assigned = true;
                            assignedInfo = caseInfo;
                            break;
                        end
                    end
                    if assigned, break; end
                end

                if ~assigned
                    error('ScheduleAssembler:UnassignedCase', ...
                        'Case %s could not be mapped from solver output.', prepared.cases(caseIdx).caseID);
                end
            end

            % Sort lab schedules by start time
            for labIdx = 1:numLabs
                if isempty(scheduleStruct.labs{labIdx})
                    scheduleStruct.labs{labIdx} = struct([]);
                    continue;
                end
                labCases = scheduleStruct.labs{labIdx};
                [~, sortIdx] = sort([labCases.startTime]);
                scheduleStruct.labs{labIdx} = labCases(sortIdx);
            end

            % Sort operator schedules by procedure start time
            if ~isempty(scheduleStruct.operators)
                opKeys = keys(scheduleStruct.operators);
                for i = 1:numel(opKeys)
                    key = opKeys{i};
                    entries = scheduleStruct.operators(key);
                    procStarts = arrayfun(@(entry) entry.caseInfo.procStartTime, entries);
                    [~, sortIdx] = sort(procStarts);
                    scheduleStruct.operators(key) = entries(sortIdx);
                end
            end

            % Minimal results metadata (no analytics yet)
            resultsStruct = struct();
            resultsStruct.objectiveValue = solverInfo.objectiveValue;
            resultsStruct.exitflag = solverInfo.exitflag;
            resultsStruct.solverOutput = solverInfo.output;
            resultsStruct.optimizationMetric = model.optimizationMetric;

            if ~isempty(allStartTimes)
                resultsStruct.timeRangeMinutes = [min(allStartTimes), max(allEndTimes)];
            else
                resultsStruct.timeRangeMinutes = [min(labStartMinutes), min(labStartMinutes)];
            end

            resultsStruct.scheduleStart = min(labStartMinutes);
            resultsStruct.scheduleEnd = max([labStartMinutes(:); allEndTimes(:)]);
            resultsStruct.makespan = resultsStruct.scheduleEnd - resultsStruct.scheduleStart;
            resultsStruct.labStartMinutes = labStartMinutes;

            labEndMinutes = labStartMinutes;
            for labIdx = 1:numLabs
                labCases = scheduleStruct.labs{labIdx};
                if isempty(labCases)
                    labEndMinutes(labIdx) = labStartMinutes(labIdx);
                else
                    labEndMinutes(labIdx) = max([labCases.endTime]);
                end
            end
            resultsStruct.labEndMinutes = labEndMinutes;

            % Convert to DailySchedule for downstream usage
            dailySchedule = conduction.DailySchedule.fromLegacyStruct(scheduleStruct, resultsStruct);

            outcome = struct();
            outcome.objectiveValue = solverInfo.objectiveValue;
            outcome.exitflag = solverInfo.exitflag;
            outcome.output = solverInfo.output;
            outcome.optimizationMetric = model.optimizationMetric;
            outcome.decisionVariables = solution;
            outcome.timeSlots = timeSlots;
            outcome.numTimeSlots = numTimeSlots;
            outcome.numLabs = numLabs;
            outcome.numCases = numCases;
            outcome.uniqueOperators = uniqueOperators;
            outcome.scheduleStruct = scheduleStruct;
            outcome.resultsMetadata = resultsStruct;
            outcome.options = options.toStruct();

            [resourceAssignments, resourceViolations] = conduction.scheduling.ScheduleAssembler.computeResourceDiagnostics( ...
                scheduledResourceIntervals, resourceIds, resourceTypes, resourceCapacities);
            outcome.ResourceAssignments = resourceAssignments;
            outcome.ResourceViolations = resourceViolations;
            outcome.ResourceTypes = resourceTypes;
        end
    end

    methods (Static, Access = private)
        function caseInfo = buildCaseInfo(rawCase, labIdx, startTime, setupTime, procTime, postTime, turnoverTime)
            caseInfo = struct();
            caseInfo.caseID = rawCase.caseID;
            caseInfo.operator = rawCase.operator;
            if isfield(rawCase, 'procedure')
                caseInfo.procedure = rawCase.procedure;
            end
            caseInfo.startTime = startTime;
            caseInfo.setupTime = setupTime;
            caseInfo.procTime = procTime;
            caseInfo.postTime = postTime;
            caseInfo.turnoverTime = turnoverTime;
            caseInfo.procStartTime = startTime + setupTime;
            caseInfo.procEndTime = caseInfo.procStartTime + procTime;
            caseInfo.endTime = caseInfo.procEndTime + postTime + turnoverTime;
            caseInfo.lab = labIdx;

            if isfield(rawCase, 'admissionStatus')
                caseInfo.admissionStatus = rawCase.admissionStatus;
            end
            if isfield(rawCase, 'date')
                caseInfo.date = rawCase.date;
            end
            % DUAL-ID: Preserve case number for display
            if isfield(rawCase, 'caseNumber')
                caseInfo.caseNumber = rawCase.caseNumber;
            end
            if isfield(rawCase, 'requiredResourceIds') && ~isempty(rawCase.requiredResourceIds)
                resources = string(rawCase.requiredResourceIds);
                resources = resources(strlength(resources) > 0);
                if ~isempty(resources)
                    caseInfo.requiredResources = resources(:);
                end
            end
        end

        function [assignments, violations] = computeResourceDiagnostics(intervals, resourceIds, resourceTypes, resourceCapacities)
            if nargin < 2 || isempty(resourceIds)
                assignments = struct('ResourceId', {}, 'ResourceName', {}, 'Capacity', {}, 'CaseIds', {});
                violations = struct('ResourceId', {}, 'ResourceName', {}, 'Capacity', {}, 'StartTime', {}, 'EndTime', {}, 'CaseIds', {});
                return;
            end

            numResources = numel(resourceIds);
            assignments = repmat(struct('ResourceId', "", 'ResourceName', "", 'Capacity', 0, 'CaseIds', string.empty(0, 1)), 1, numResources);
            violations = struct('ResourceId', {}, 'ResourceName', {}, 'Capacity', {}, 'StartTime', {}, 'EndTime', {}, 'CaseIds', {});

            resourceNames = strings(numResources, 1);
            if nargin >= 3 && ~isempty(resourceTypes)
                for idx = 1:numResources
                    matchIdx = find(arrayfun(@(t) t.Id == resourceIds(idx), resourceTypes), 1, 'first');
                    if ~isempty(matchIdx)
                        resourceNames(idx) = string(resourceTypes(matchIdx).Name);
                    else
                        resourceNames(idx) = resourceIds(idx);
                    end
                end
            else
                resourceNames = resourceIds;
            end

            if nargin < 4 || isempty(resourceCapacities)
                resourceCapacities = zeros(1, numResources);
            elseif numel(resourceCapacities) < numResources
                padded = zeros(1, numResources);
                padded(1:numel(resourceCapacities)) = resourceCapacities;
                resourceCapacities = padded;
            end

            for resIdx = 1:numResources
                resId = resourceIds(resIdx);
                resName = resourceNames(resIdx);
                capacity = resourceCapacities(resIdx);

                mask = arrayfun(@(interval) any(interval.Resources == resId), intervals);
                if any(mask)
                    caseIds = string({intervals(mask).CaseId});
                    assignments(resIdx).CaseIds = unique(caseIds(:), 'stable');
                else
                    assignments(resIdx).CaseIds = string.empty(0, 1);
                end
                assignments(resIdx).ResourceId = resId;
                assignments(resIdx).ResourceName = resName;
                assignments(resIdx).Capacity = capacity;

                if isinf(capacity) || isempty(assignments(resIdx).CaseIds)
                    continue;
                end

                resourceIntervals = intervals(mask);
                if isempty(resourceIntervals)
                    continue;
                end

                events = struct('Time', {}, 'Delta', {}, 'CaseId', {});
                for intervalIdx = 1:numel(resourceIntervals)
                    interval = resourceIntervals(intervalIdx);
                    events(end+1) = struct('Time', interval.ProcStart, 'Delta', 1, 'CaseId', interval.CaseId); %#ok<AGROW>
                    events(end+1) = struct('Time', interval.ProcEnd, 'Delta', -1, 'CaseId', interval.CaseId); %#ok<AGROW>
                end

                if isempty(events)
                    continue;
                end

                % Sort events by time, with start events processed before end events at the same timestamp
                eventTimes = [events.Time];
                deltas = [events.Delta];
                [~, sortIdx] = sortrows([eventTimes(:), deltas(:)]); %#ok<UDIM>
                events = events(sortIdx);

                activeCases = string.empty(0, 1);
                violationActive = false;
                violationStart = NaN;
                violationCases = string.empty(0, 1);

                for eventIdx = 1:numel(events)
                    event = events(eventIdx);
                    if event.Delta > 0
                        activeCases(end+1, 1) = string(event.CaseId); %#ok<AGROW>
                    else
                        removeId = string(event.CaseId);
                        if ~isempty(activeCases)
                            activeCases(activeCases == removeId) = [];
                        end
                        activeCases = reshape(activeCases, [], 1);
                    end

                    if numel(activeCases) > capacity && ~violationActive
                        violationActive = true;
                        violationStart = event.Time;
                        violationCases = activeCases;
                    elseif violationActive && numel(activeCases) <= capacity
                        violationActive = false;
                        violationEnd = event.Time;
                        violations(end+1) = struct( ...
                            'ResourceId', resId, ...
                            'ResourceName', resName, ...
                            'Capacity', capacity, ...
                            'StartTime', violationStart, ...
                            'EndTime', violationEnd, ...
                            'CaseIds', violationCases); %#ok<AGROW>
                        violationCases = string.empty(0, 1);
                        violationStart = NaN;
                    elseif violationActive
                        violationCases = unique([violationCases; activeCases], 'stable'); %#ok<AGROW>
                    end
                end

                if violationActive
                    violationEnd = events(end).Time;
                    violations(end+1) = struct( ...
                        'ResourceId', resId, ...
                        'ResourceName', resName, ...
                        'Capacity', capacity, ...
                        'StartTime', violationStart, ...
                        'EndTime', violationEnd, ...
                        'CaseIds', violationCases); %#ok<AGROW>
                end
            end
        end
    end
end
