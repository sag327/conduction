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
        end
    end

    methods (Static, Access = private)
        function cases = normaliseCaseStruct(cases)
            if isa(cases, 'conduction.CaseRequest')
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
    end
end
