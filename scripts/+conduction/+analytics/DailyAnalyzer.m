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

            metadata = dailySchedule.metrics();

            numLabs = numel(labAssignments);
            labStartTimes = NaN(numLabs, 1);
            if isstruct(metadata) && isfield(metadata, 'labStartMinutes')
                rawStarts = metadata.labStartMinutes;
                labStartTimes = double(rawStarts(:));
                if numel(labStartTimes) ~= numLabs
                    labStartTimes = repmat(labStartTimes(1), numLabs, 1);
                end
            end

            if isempty(caseStructs)
                metrics.caseCount = 0;
                metrics.labUtilization = zeros(numLabs,1);
                metrics.averageLabOccupancyRatio = 0;
                metrics.labIdleMinutes = 0;
                metrics.makespanMinutes = 0;
                metrics.firstCaseStart = NaN;
                metrics.lastCaseEnd = NaN;
                return;
            end

            metrics.caseCount = numel(caseStructs);

            % Lab utilization
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
                caseStarts = arrayfun(@conduction.analytics.DailyAnalyzer.caseStartForLab, cases);
                labStart(labIdx) = min(caseStarts);
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
                if isempty(labCases)
                    continue;
                end

                % Order cases chronologically
                caseStarts = arrayfun(@conduction.analytics.DailyAnalyzer.caseStartForLab, labCases);
                [~, order] = sort(caseStarts);
                labCases = labCases(order);

                % Determine baseline start for this lab
                baselineStart = NaN;
                if labIdx <= numel(labStartTimes)
                    baselineStart = labStartTimes(labIdx);
                end
                if isnan(baselineStart)
                    baselineStart = caseStarts(order(1));
                end

                prevEnd = baselineStart;

                for caseIdx = 1:numel(labCases)
                    thisCase = labCases(caseIdx);
                    caseStart = conduction.analytics.DailyAnalyzer.caseStartForLab(thisCase);
                    if isnan(prevEnd)
                        prevEnd = caseStart;
                    end
                    if ~isnan(prevEnd) && ~isnan(caseStart)
                        gap = caseStart - prevEnd;
                        if gap > 0
                            labIdleTotal = labIdleTotal + gap;
                        end
                    end

                    procEnd = conduction.analytics.DailyAnalyzer.procEnd(thisCase);
                    postTime = conduction.analytics.DailyAnalyzer.fieldOr(thisCase, 'postTime', 0);
                    turnoverTime = conduction.analytics.DailyAnalyzer.fieldOr(thisCase, 'turnoverTime', 0);
                    caseFinish = procEnd + postTime;

                    if caseIdx < numel(labCases)
                        if turnoverTime > 0
                            labIdleTotal = labIdleTotal + turnoverTime;
                        end
                        prevEnd = caseFinish + turnoverTime;
                    else
                        prevEnd = caseFinish;
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
