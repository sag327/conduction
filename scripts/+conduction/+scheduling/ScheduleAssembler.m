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

            % DEBUG: Check array sizes
            fprintf('[DEBUG ScheduleAssembler] model.numCases=%d\n', numCases);
            fprintf('[DEBUG ScheduleAssembler] prepared.cases array size=%d\n', numel(prepared.cases));
            fprintf('[DEBUG ScheduleAssembler] solution vector size=%d\n', numel(solution));
            fprintf('[DEBUG ScheduleAssembler] model.numVars=%d\n', model.numVars);

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
        end
    end
end
