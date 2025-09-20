classdef DailyAnalyzer
    %DAILYANALYZER Compute metrics for a single DailySchedule.

    methods (Static)
        function metrics = analyze(dailySchedule)
            arguments
                dailySchedule conduction.DailySchedule
            end

            labAssignments = dailySchedule.labAssignments();
            caseStructs = dailySchedule.cases();

            metrics = struct();
            metrics.date = dailySchedule.Date;

            if isempty(caseStructs)
                metrics.caseCount = 0;
                metrics.labUtilization = zeros(numel(labAssignments),1);
                metrics.meanLabUtilization = 0;
                metrics.operatorIdleTime = struct();
                metrics.operatorOvertime = struct();
                metrics.makespanMinutes = 0;
                metrics.firstCaseStart = NaN;
                metrics.lastCaseEnd = NaN;
                return;
            end

            metrics.caseCount = numel(caseStructs);

            % Lab utilization
            numLabs = numel(labAssignments);
            labUtil = zeros(numLabs,1);
            labStart = zeros(numLabs,1);
            labEnd = zeros(numLabs,1);
            for labIdx = 1:numLabs
                cases = labAssignments{labIdx};
                if isempty(cases)
                    labStart(labIdx) = NaN;
                    labEnd(labIdx) = NaN;
                    continue;
                end
                procTimes = [cases.procTime];
                labUtil(labIdx) = sum(procTimes);
                labStart(labIdx) = min([cases.startTime]);
                labEndTimes = arrayfun(@conduction.analytics.DailyAnalyzer.caseEnd, cases);
                labEnd(labIdx) = max(labEndTimes);
            end
            labDurations = labEnd - labStart;
            metrics.labUtilization = zeros(numLabs,1);
            for labIdx = 1:numLabs
                if labDurations(labIdx) <= 0
                    metrics.labUtilization(labIdx) = 0;
                else
                    metrics.labUtilization(labIdx) = labUtil(labIdx) / labDurations(labIdx);
                end
            end
            validUtil = metrics.labUtilization(~isnan(metrics.labUtilization));
            if isempty(validUtil)
                metrics.meanLabUtilization = 0;
            else
                metrics.meanLabUtilization = mean(validUtil);
            end

            % Time range
            allStarts = [caseStructs.startTime];
            allEnds = arrayfun(@conduction.analytics.DailyAnalyzer.caseEnd, caseStructs);
            metrics.firstCaseStart = min(allStarts);
            metrics.lastCaseEnd = max(allEnds);
            metrics.makespanMinutes = metrics.lastCaseEnd - metrics.firstCaseStart;

            % Operator idle/overtime
            operatorNames = {caseStructs.operator};
            uniqueOps = unique(operatorNames);
            idleMap = containers.Map('KeyType','char','ValueType','double');
            overtimeMap = containers.Map('KeyType','char','ValueType','double');

            for idx = 1:numel(uniqueOps)
                opName = uniqueOps{idx};
                opCases = caseStructs(strcmp(operatorNames, opName));
                [sortedStart, order] = sort([opCases.procStartTime]);
                opCases = opCases(order);
                procEndTimes = arrayfun(@conduction.analytics.DailyAnalyzer.procEnd, opCases);

                % Idle time between procedures (> 0 minutes)
                idle = sum(max(0, sortedStart(2:end) - procEndTimes(1:end-1)));
                idleMap(opName) = idle;

                % Overtime beyond eight hours (480 minutes)
                totalProc = sum([opCases.procTime]);
                overtime = max(0, totalProc - 480);
                overtimeMap(opName) = overtime;
            end

            metrics.operatorIdleTime = idleMap;
            metrics.operatorOvertime = overtimeMap;
        end
    end

    methods (Static, Access = private)
        function t = caseEnd(caseStruct)
            if isfield(caseStruct, 'endTime') && ~isempty(caseStruct.endTime)
                t = caseStruct.endTime;
            else
                t = conduction.analytics.DailyAnalyzer.procEnd(caseStruct) + ...
                    conduction.analytics.DailyAnalyzer.fieldOr(caseStruct, 'postTime', 0) + ...
                    conduction.analytics.DailyAnalyzer.fieldOr(caseStruct, 'turnoverTime', 0);
            end
        end

        function t = procEnd(caseStruct)
            if isfield(caseStruct, 'procEndTime') && ~isempty(caseStruct.procEndTime)
                t = caseStruct.procEndTime;
            else
                start = conduction.analytics.DailyAnalyzer.fieldOr(caseStruct, 'procStartTime', NaN);
                duration = conduction.analytics.DailyAnalyzer.fieldOr(caseStruct, 'procTime', NaN);
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
