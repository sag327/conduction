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
                metrics.averageLabOccupancyRatio = 0;
                metrics.labIdleMinutes = 0;
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
            % Average occupancy across labs (procedure minutes ÷ active window)
            validUtil = metrics.labUtilization(~isnan(metrics.labUtilization));
            if isempty(validUtil)
                metrics.averageLabOccupancyRatio = 0;
            else
                metrics.averageLabOccupancyRatio = mean(validUtil);
            end

            % Time range
            allStarts = [caseStructs.startTime];
            allEnds = arrayfun(@conduction.analytics.DailyAnalyzer.caseEnd, caseStructs);
            metrics.firstCaseStart = min(allStarts);
            metrics.lastCaseEnd = max(allEnds);
            metrics.makespanMinutes = metrics.lastCaseEnd - metrics.firstCaseStart;

            % Lab idle time across the department
            labIdleTotal = 0;
            for labIdx = 1:numel(labAssignments)
                labCases = labAssignments{labIdx};
                if numel(labCases) <= 1
                    continue;
                end

                [~, labOrder] = sort([labCases.procStartTime]);
                labCases = labCases(labOrder);

                for caseIdx = 2:numel(labCases)
                    prevEnd = conduction.analytics.DailyAnalyzer.caseEnd(labCases(caseIdx - 1));
                    nextStart = conduction.analytics.DailyAnalyzer.caseStartForLab(labCases(caseIdx));
                    if isnan(prevEnd) || isnan(nextStart)
                        continue;
                    end

                    gap = nextStart - prevEnd;
                    if gap > 0
                        labIdleTotal = labIdleTotal + gap;
                    end
                end
            end
            metrics.labIdleMinutes = labIdleTotal;
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

        function startTime = caseStartForLab(caseStruct)
            startTime = conduction.analytics.DailyAnalyzer.fieldOr(caseStruct, 'startTime', NaN);
            if isnan(startTime)
                startTime = conduction.analytics.DailyAnalyzer.fieldOr(caseStruct, 'procStartTime', NaN);
            end
        end
    end
end
