classdef SchedulingPreprocessor
    %SCHEDULINGPREPROCESSOR Prepare historical cases for optimization.
    %   Handles filtering, time conversions, and matrix-friendly structures.

    methods (Static)
        function prepared = prepareDataset(cases, options)
            arguments
                cases
                options (1,1) conduction.scheduling.SchedulingOptions
            end

            if isempty(cases)
                error('SchedulingPreprocessor:NoCases', ...
                    'At least one case is required to build an optimization model.');
            end

            cases = conduction.scheduling.SchedulingPreprocessor.normaliseCaseStruct(cases);

            numLabs = options.NumLabs;
            labStartMinutes = conduction.scheduling.SchedulingPreprocessor.parseLabStarts(options.LabStartTimes);

            operatorNames = {cases.operator};
            uniqueOperators = unique(operatorNames);
            operatorMap = containers.Map(uniqueOperators, num2cell(1:numel(uniqueOperators)));
            operatorIdx = cellfun(@(name) operatorMap(name), operatorNames);

            [setupTimes, procTimes, postTimes] = conduction.scheduling.SchedulingPreprocessor.extractDurations(cases);
            priorities = conduction.scheduling.SchedulingPreprocessor.extractPriorities(cases);
            labPreferences = conduction.scheduling.SchedulingPreprocessor.buildLabPreferences(cases, numLabs);

            operatorAvailability = options.OperatorAvailability;
            if isempty(operatorAvailability)
                operatorAvailability = containers.Map('KeyType','char','ValueType','double');
            end
            operatorAvailability = conduction.scheduling.SchedulingPreprocessor.normalizeAvailability(operatorAvailability);

            % Process locked case constraints
            lockedConstraints = options.LockedCaseConstraints;
            fprintf('[DEBUG PREPROCESSOR] Processing locked constraints...\n');
            fprintf('[DEBUG PREPROCESSOR] Number of cases: %d\n', numel(cases));
            fprintf('[DEBUG PREPROCESSOR] Number of locked constraints: %d\n', numel(lockedConstraints));

            [lockedCaseMap, lockedStartTimes] = conduction.scheduling.SchedulingPreprocessor.processLockedConstraints(lockedConstraints, cases);

            fprintf('[DEBUG PREPROCESSOR] lockedStartTimes array size: %d\n', numel(lockedStartTimes));
            fprintf('[DEBUG PREPROCESSOR] Number of non-NaN locked times: %d\n', sum(~isnan(lockedStartTimes)));

            % Enhance operator availability with locked case busy windows
            operatorAvailability = conduction.scheduling.SchedulingPreprocessor.addLockedCasesToAvailability(...
                operatorAvailability, lockedConstraints);

            prepared = struct();
            prepared.cases = cases;
            prepared.numCases = numel(cases);
            prepared.numLabs = numLabs;
            prepared.labStartMinutes = labStartMinutes;
            prepared.labStartTimes = options.LabStartTimes;
            prepared.turnoverTime = options.TurnoverTime;
            prepared.maxOperatorTime = options.MaxOperatorTime;
            prepared.timeStep = options.TimeStep;
            prepared.enforceMidnight = options.EnforceMidnight;

            prepared.operatorNames = operatorNames;
            prepared.uniqueOperators = uniqueOperators;
            prepared.operatorMap = operatorMap;
            prepared.operatorIndex = operatorIdx;

            prepared.caseSetupTimes = setupTimes;
            prepared.caseProcTimes = procTimes;
            prepared.casePostTimes = postTimes;
            prepared.casePriorities = priorities;
            prepared.labPreferences = labPreferences;
            prepared.operatorAvailability = operatorAvailability;

            % Add locked case information
            prepared.lockedCaseMap = lockedCaseMap;
            prepared.lockedStartTimes = lockedStartTimes;
        end
    end

    methods (Static, Access = private)
        function cases = normaliseCaseStruct(cases)
            if isa(cases, 'conduction.DailySchedule')
                cases = cases.toOptimizationCases();
            elseif isa(cases, 'conduction.CaseRequest')
                error('SchedulingPreprocessor:UnsupportedType', ...
                    ['CaseRequest to optimization bridge not implemented yet. ', ...
                     'Convert CaseRequest objects to optimization structs before scheduling.']);
            end

            if ~isstruct(cases)
                error('SchedulingPreprocessor:InvalidCases', ...
                    'Expected cases as struct array compatible with legacy optimization.');
            end
        end

        function minutes = parseLabStarts(startTimes)
            minutes = zeros(1, numel(startTimes));
            for idx = 1:numel(startTimes)
                timeStr = startTimes{idx};
                if isstring(timeStr); timeStr = char(timeStr); end
                parts = strsplit(timeStr, ':');
                if numel(parts) ~= 2
                    error('SchedulingPreprocessor:InvalidTime', ...
                        'Lab start time must be HH:MM format. Got: %s', timeStr);
                end
                minutes(idx) = str2double(parts{1}) * 60 + str2double(parts{2});
            end
        end

        function [setupTimes, procTimes, postTimes] = extractDurations(cases)
            setupTimes = [cases.setupTime];
            procTimes = [cases.procTime];
            postTimes = [cases.postTime];

            if any(isnan(procTimes))
                error('SchedulingPreprocessor:MissingProcedureMinutes', ...
                    'Procedure duration is required for all cases.');
            end

            setupTimes(isnan(setupTimes)) = 0;
            postTimes(isnan(postTimes)) = 0;
        end

        function priorities = extractPriorities(cases)
            priorities = zeros(numel(cases), 1);
            for idx = 1:numel(cases)
                value = cases(idx).priority;
                if isempty(value) || isnan(value)
                    continue;
                end
                priorities(idx) = value;
            end
        end

        function prefs = buildLabPreferences(cases, numLabs)
            prefs = zeros(numel(cases), numLabs);
            for idx = 1:numel(cases)
                preferred = cases(idx).preferredLab;
                if isempty(preferred) || isnan(preferred)
                    prefs(idx, :) = 1;
                else
                    prefLab = preferred;
                    if prefLab < 1 || prefLab > numLabs
                        prefs(idx, :) = 1;
                    else
                        prefs(idx, prefLab) = 1;
                    end
                end
            end
        end

        function availability = normalizeAvailability(availability)
            keys = availability.keys;
            for idx = 1:numel(keys)
                key = keys{idx};
                value = availability(key);
                if ~isnumeric(value)
                    error('SchedulingPreprocessor:InvalidAvailability', ...
                        'Operator availability must be numeric minutes from midnight.');
                end
                availability(key) = double(value);
            end
        end

        function [lockedCaseMap, lockedStartTimes] = processLockedConstraints(constraints, cases)
            % Process locked case constraints into case-indexed structures
            %   lockedCaseMap: containers.Map from caseID to constraint struct
            %   lockedStartTimes: array parallel to cases with locked start times (NaN if not locked)

            lockedCaseMap = containers.Map('KeyType','char','ValueType','any');
            lockedStartTimes = nan(numel(cases), 1);

            if isempty(constraints)
                return;
            end

            % Build map from constraints
            fprintf('[DEBUG processLockedConstraints] Building constraint map...\n');
            for i = 1:numel(constraints)
                constraint = constraints(i);
                caseId = char(string(constraint.caseID));
                lockedCaseMap(caseId) = constraint;
                fprintf('[DEBUG processLockedConstraints] Added constraint for case: %s\n', caseId);
            end

            % Build parallel array of start times for each case
            fprintf('[DEBUG processLockedConstraints] Matching constraints to cases...\n');
            fprintf('[DEBUG processLockedConstraints] Cases array size: %d\n', numel(cases));
            for cIdx = 1:numel(cases)
                caseId = char(string(cases(cIdx).caseID));
                fprintf('[DEBUG processLockedConstraints] Checking case %d: %s\n', cIdx, caseId);
                if isKey(lockedCaseMap, caseId)
                    constraint = lockedCaseMap(caseId);
                    % Use startTime (includes setup) for the optimizer constraint
                    lockedStartTimes(cIdx) = constraint.startTime;
                    fprintf('[DEBUG processLockedConstraints] MATCHED! Set locked time: %.1f\n', constraint.startTime);
                end
            end
        end

        function availability = addLockedCasesToAvailability(availability, constraints)
            % Add locked case busy windows to operator availability
            %   Operators become unavailable during their locked case procedure times

            if isempty(constraints)
                return;
            end

            % For each locked case, block the operator during procedure time
            for i = 1:numel(constraints)
                constraint = constraints(i);
                operatorName = char(string(constraint.operator));

                % Use procedure end time as operator availability
                % The operator can't start another case until after the procedure ends
                procEndTime = constraint.procEndTime;

                % Update operator availability (use max if operator has multiple locked cases)
                if isKey(availability, operatorName)
                    currentAvail = availability(operatorName);
                    availability(operatorName) = max(currentAvail, procEndTime);
                else
                    availability(operatorName) = procEndTime;
                end
            end
        end
    end
end
