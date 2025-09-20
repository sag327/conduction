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

            baseStruct = obj.Options.toStruct();
            baseStruct.PrioritizeOutpatient = false;
            baseStruct.CaseFilter = 'all';
            baseStruct.OperatorAvailability = containers.Map('KeyType','char','ValueType','double');

            phase1Options = conduction.scheduling.SchedulingOptions.fromArgs(baseStruct);
            [phase1Daily, phase1Outcome] = conduction.scheduling.HistoricalScheduler.runPhase(outpatientCases, phase1Options);

            if isempty(inpatientCases)
                dailySchedule = phase1Daily;
                outcome = struct('phase1', phase1Outcome, ...
                    'objectiveValue', phase1Outcome.objectiveValue, ...
                    'exitflag', phase1Outcome.exitflag, ...
                    'scheduleStruct', phase1Outcome.scheduleStruct, ...
                    'resultsMetadata', phase1Outcome.resultsMetadata);
                return;
            end

            [updatedStarts, operatorAvailability] = obj.calculateUpdatedLabAvailability( ...
                phase1Outcome.scheduleStruct, obj.Options.LabStartTimes);

            phase2Struct = obj.Options.toStruct();
            phase2Struct.PrioritizeOutpatient = false;
            phase2Struct.CaseFilter = 'all';
            phase2Struct.LabStartTimes = updatedStarts;
            phase2Struct.OperatorAvailability = operatorAvailability;

            phase2Options = conduction.scheduling.SchedulingOptions.fromArgs(phase2Struct);
            [phase2Daily, phase2Outcome] = conduction.scheduling.HistoricalScheduler.runPhase(inpatientCases, phase2Options);

            combinedSchedule = obj.mergeSchedules(phase1Outcome.scheduleStruct, phase2Outcome.scheduleStruct);
            mergedResults = obj.mergeResultsMetadata(combinedSchedule, phase1Outcome, phase2Outcome);
            dailySchedule = conduction.DailySchedule.fromLegacyStruct(combinedSchedule, mergedResults);

            outcome = struct();
            outcome.phase1 = phase1Outcome;
            outcome.phase2 = phase2Outcome;
            outcome.objectiveValue = phase1Outcome.objectiveValue + phase2Outcome.objectiveValue;
            outcome.exitflag = [phase1Outcome.exitflag, phase2Outcome.exitflag];
            outcome.scheduleStruct = combinedSchedule;
            outcome.resultsMetadata = mergedResults;
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
            [dailySchedule, outcome] = conduction.scheduling.ScheduleAssembler.assemble(prepared, model, solution, solverInfo);
        end

        function tf = isOutpatient(caseStruct)
            if ~isfield(caseStruct, 'admissionStatus') || isempty(caseStruct.admissionStatus)
                tf = true;
                return;
            end
            tf = strcmp(caseStruct.admissionStatus, 'Hospital Outpatient Surgery (Amb Proc)');
        end

        function tf = isInpatient(caseStruct)
            tf = isfield(caseStruct, 'admissionStatus') && strcmp(caseStruct.admissionStatus, 'Inpatient');
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
end
