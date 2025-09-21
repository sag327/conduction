classdef OperatorAnalyzer
    %OPERATORANALYZER Compute per-operator metrics for a DailySchedule.

    methods (Static)
        function metrics = analyze(dailySchedule)
            arguments
                dailySchedule conduction.DailySchedule
            end

            metrics = struct();
            metrics.date = dailySchedule.Date;

            caseStructs = dailySchedule.cases();
            if isempty(caseStructs)
                metrics.operatorMetrics = conduction.analytics.OperatorAnalyzer.emptyOperatorStruct();
                metrics.departmentMetrics = conduction.analytics.OperatorAnalyzer.emptySummary();
                return;
            end

            operatorNames = {caseStructs.operator};
            uniqueOps = unique(operatorNames);

            operatorData = struct();
            operatorData.totalIdleTime = containers.Map('KeyType','char','ValueType','double');
            operatorData.overtime = containers.Map('KeyType','char','ValueType','double');
            operatorData.flipPerTurnoverRatio = containers.Map('KeyType','char','ValueType','double');
            operatorData.idlePerTurnoverRatio = containers.Map('KeyType','char','ValueType','double');
            operatorData.turnoverCount = containers.Map('KeyType','char','ValueType','double');
            operatorData.flipCount = containers.Map('KeyType','char','ValueType','double');
            operatorData.turnoverIdleMinutes = containers.Map('KeyType','char','ValueType','double');
            operatorData.operatorNames = containers.Map('KeyType','char','ValueType','char');

            totalOperatorIdleMinutes = 0;
            turnoverIdleDurations = double.empty(0, 1);
            turnoverFlipFlags = false(0, 1);

            for idx = 1:numel(uniqueOps)
                opName = uniqueOps{idx};
                opCases = caseStructs(strcmp(operatorNames, opName));
                [sortedStart, order] = sort([opCases.procStartTime]);
                opCases = opCases(order);
                procEndTimes = arrayfun(@conduction.analytics.OperatorAnalyzer.procEnd, opCases);

                if numel(opCases) > 1
                    idleGaps = max(0, sortedStart(2:end) - procEndTimes(1:end-1));
                else
                    idleGaps = zeros(0,1);
                end
                idleMinutes = sum(idleGaps);
                operatorData.totalIdleTime(opName) = idleMinutes;
                if ~isKey(operatorData.operatorNames, opName)
                    operatorData.operatorNames(opName) = char(opName);
                end
                totalOperatorIdleMinutes = totalOperatorIdleMinutes + idleMinutes;

                totalProcMinutes = sum([opCases.procTime]);
                overtimeMinutes = max(0, totalProcMinutes - 480);
                operatorData.overtime(opName) = overtimeMinutes;

                if numel(opCases) <= 1
                    continue;
                end

                labSequence = strings(1, numel(opCases));
                for caseIdx = 1:numel(opCases)
                    labSequence(caseIdx) = conduction.analytics.OperatorAnalyzer.caseLab(opCases(caseIdx));
                end

                startIdx = numel(turnoverIdleDurations);
                appended = 0;
                for gapIdx = 1:numel(idleGaps)
                    prevLab = labSequence(gapIdx);
                    currLab = labSequence(gapIdx + 1);
                    if strlength(prevLab) == 0 || strlength(currLab) == 0
                        continue;
                    end

                    turnoverIdleDurations(end+1,1) = idleGaps(gapIdx); %#ok<AGROW>
                    turnoverFlipFlags(end+1,1) = (prevLab ~= currLab); %#ok<AGROW>
                    appended = appended + 1;
                end

                if appended > 0
                    flipsForOperator = turnoverFlipFlags(startIdx+1:end);
                    idleForOperator = turnoverIdleDurations(startIdx+1:end);
                    eligibleTurnovers = appended;
                else
                    flipsForOperator = false(0,1);
                    idleForOperator = double.empty(0,1);
                    eligibleTurnovers = 0;
                end

                flipCount = sum(flipsForOperator);
                idleForTurnover = sum(idleForOperator);

                if eligibleTurnovers > 0
                    operatorData.flipPerTurnoverRatio(opName) = flipCount / eligibleTurnovers;
                    operatorData.idlePerTurnoverRatio(opName) = idleForTurnover / eligibleTurnovers;
                end

                existingTurns = 0;
                if operatorData.turnoverCount.isKey(opName)
                    existingTurns = operatorData.turnoverCount(opName);
                end
                operatorData.turnoverCount(opName) = existingTurns + eligibleTurnovers;

                existingFlips = 0;
                if operatorData.flipCount.isKey(opName)
                    existingFlips = operatorData.flipCount(opName);
                end
                operatorData.flipCount(opName) = existingFlips + flipCount;

                existingIdle = 0;
                if operatorData.turnoverIdleMinutes.isKey(opName)
                    existingIdle = operatorData.turnoverIdleMinutes(opName);
                end
                operatorData.turnoverIdleMinutes(opName) = existingIdle + idleForTurnover;
            end

            summary = struct();
            summary.totalOperatorIdleMinutes = totalOperatorIdleMinutes;
            summary.turnoverIdleDurations = turnoverIdleDurations;
            summary.turnoverFlipFlags = turnoverFlipFlags;
            summary.totalTurnovers = numel(turnoverIdleDurations);
            summary.totalFlipCount = sum(turnoverFlipFlags);
            summary.totalIdleForTurnover = sum(turnoverIdleDurations);
            if ~isempty(turnoverIdleDurations)
                summary.flipPerTurnoverRatio = mean(turnoverFlipFlags);
                summary.idlePerTurnoverRatio = mean(turnoverIdleDurations);
            else
                summary.flipPerTurnoverRatio = 0;
                summary.idlePerTurnoverRatio = 0;
            end

            metrics.operatorMetrics = operatorData;
            metrics.departmentMetrics = summary;
        end
    end

    methods (Static, Access = private)
        function ops = emptyOperatorStruct()
            ops = struct( ...
                'totalIdleTime', containers.Map('KeyType','char','ValueType','double'), ...
                'overtime', containers.Map('KeyType','char','ValueType','double'), ...
                'flipPerTurnoverRatio', containers.Map('KeyType','char','ValueType','double'), ...
                'idlePerTurnoverRatio', containers.Map('KeyType','char','ValueType','double'), ...
                'turnoverCount', containers.Map('KeyType','char','ValueType','double'), ...
                'flipCount', containers.Map('KeyType','char','ValueType','double'), ...
                'turnoverIdleMinutes', containers.Map('KeyType','char','ValueType','double'), ...
                'operatorNames', containers.Map('KeyType','char','ValueType','char') ...
            );
        end

        function summary = emptySummary()
            summary = struct( ...
                'totalOperatorIdleMinutes', 0, ...
                'turnoverIdleDurations', double.empty(0,1), ...
                'turnoverFlipFlags', false(0,1), ...
                'totalTurnovers', 0, ...
                'totalFlipCount', 0, ...
                'totalIdleForTurnover', 0, ...
                'flipPerTurnoverRatio', 0, ...
                'idlePerTurnoverRatio', 0 ...
            );
        end

        function labId = caseLab(caseStruct)
            candidates = { ...
                'room', ...
                'lab', ...
                'labName', ...
                'labId', ...
                'assignedLab' ...
            };

            labId = "";
            for idx = 1:numel(candidates)
                name = candidates{idx};
                if ~isfield(caseStruct, name) || isempty(caseStruct.(name))
                    continue;
                end

                value = caseStruct.(name);
                if isa(value, 'conduction.Lab')
                    labId = string(value.Id);
                elseif isstruct(value) && isfield(value, 'Id')
                    labId = string(value.Id);
                elseif isstring(value) || ischar(value)
                    labId = string(value);
                elseif isnumeric(value)
                    labId = string(value);
                else
                    labId = string(value);
                end

                labId = strtrim(labId);
                if strlength(labId) == 0 || labId == "<missing>"
                    labId = "";
                    continue;
                end

                labId = conduction.Lab.canonicalId(labId);
                if labId ~= "lab_unknown"
                    return;
                else
                    labId = "";
                end
            end
        end
    end

    methods (Static, Access = private)
        function t = procEnd(caseStruct)
            if isfield(caseStruct, 'procEndTime') && ~isempty(caseStruct.procEndTime)
                t = caseStruct.procEndTime;
            else
                start = conduction.analytics.OperatorAnalyzer.fieldOr(caseStruct, 'procStartTime', NaN);
                duration = conduction.analytics.OperatorAnalyzer.fieldOr(caseStruct, 'procTime', NaN);
                t = start + duration;
            end
        end

        function value = fieldOr(caseStruct, fieldName, defaultValue)
            if isfield(caseStruct, fieldName) && ~isempty(caseStruct.(fieldName))
                value = caseStruct.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
