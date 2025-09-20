classdef DailySchedule
    %DAILYSCHEDULE Encapsulates all scheduling data for a single day.
    %   Provides a stable interface for visualization, analytics, and adapters.

    properties (SetAccess = immutable)
        Date datetime
        Labs (1,:) conduction.Lab
    end

    properties (Access = private)
        LabAssignments cell
        ScheduleMetrics struct
    end

    methods
        function obj = DailySchedule(dateValue, labs, labAssignments, metrics)
            arguments
                dateValue
                labs (1,:) conduction.Lab
                labAssignments (1,:) cell
                metrics struct = struct()
            end

            if numel(labAssignments) ~= numel(labs)
                error('DailySchedule:InvalidInput', ...
                    'Lab assignments must align with the provided labs.');
            end

            obj.Date = conduction.DailySchedule.parseDate(dateValue);
            obj.Labs = labs;
            obj.LabAssignments = labAssignments;
            obj.ScheduleMetrics = metrics;
        end

        function cases = cases(obj)
            %CASES Flattened list of all case requests across labs.
            nonEmpty = obj.LabAssignments(~cellfun(@isempty, obj.LabAssignments));
            if isempty(nonEmpty)
                cases = [];
                return;
            end
            cases = [nonEmpty{:}];
        end

        function metrics = metrics(obj)
            %METRICS Returns summary metrics (makespan, utilization, etc.).
            metrics = obj.ScheduleMetrics;
        end

        function assignments = labAssignments(obj)
            %LABASSIGNMENTS Accessor for per-lab case groupings.
            assignments = obj.LabAssignments;
        end

        function rangeMinutes = timeRangeMinutes(obj)
            %TIMERANGEMINUTES Overall start/end window as [start, end] in minutes.
            metrics = obj.ScheduleMetrics;
            if isfield(metrics, 'timeRangeMinutes')
                rangeMinutes = metrics.timeRangeMinutes;
                return;
            end
            rangeMinutes = conduction.DailySchedule.deriveTimeRangeMinutes(obj.LabAssignments);
        end

        function data = toVisualizationStruct(obj)
            %TOVISUALIZATIONSTRUCT Converts to legacy visualization structs.
            %#ok<STOUT>
            error('DailySchedule:NotImplemented', ...
                'Legacy visualization adapter not implemented.');
        end
    end

    methods (Static)
        function scheduleObj = fromLegacyStruct(scheduleStruct, resultsStruct)
            %FROMLEGACYSTRUCT Build a DailySchedule from legacy schedule/results.
            arguments
                scheduleStruct (1,1) struct
                resultsStruct struct = struct()
            end

            if ~isfield(scheduleStruct, 'labs')
                error('DailySchedule:InvalidLegacyStruct', ...
                    'Expected legacy schedule to contain a ''labs'' field.');
            end

            labAssignments = scheduleStruct.labs;
            if ~iscell(labAssignments)
                labAssignments = num2cell(labAssignments);
            end

            numLabs = numel(labAssignments);
            labs = conduction.Lab.empty;
            if numLabs > 0
                labObjs = cell(1, numLabs);
                for idx = 1:numLabs
                    labLabel = conduction.DailySchedule.defaultLabLabel(scheduleStruct, idx);
                    labObjs{idx} = conduction.Lab(labLabel, "");
                end
                labs = [labObjs{:}];
            end

            scheduleDate = conduction.DailySchedule.extractDateFromSchedule(labAssignments, scheduleStruct);

            metrics = resultsStruct;
            if ~isfield(metrics, 'timeRangeMinutes')
                metrics.timeRangeMinutes = conduction.DailySchedule.deriveTimeRangeMinutes(labAssignments);
            end

            scheduleObj = conduction.DailySchedule(scheduleDate, labs, labAssignments, metrics);
        end
    end

    methods (Static, Access = private)
        function dt = parseDate(value)
            if isa(value, 'datetime')
                dt = value;
            elseif isnumeric(value)
                dt = datetime(value, 'ConvertFrom', 'datenum');
            elseif isstring(value) || ischar(value)
                dt = datetime(string(value));
            else
                error('DailySchedule:InvalidDate', ...
                    'Unable to parse schedule date from input of type %s.', class(value));
            end
        end

        function label = defaultLabLabel(scheduleStruct, idx)
            if isfield(scheduleStruct, 'labNames') && numel(scheduleStruct.labNames) >= idx
                rawLabel = scheduleStruct.labNames{idx};
                label = string(rawLabel);
                if strlength(label) > 0
                    return;
                end
            end
            label = string(sprintf('Lab %d', idx));
        end

        function dt = extractDateFromSchedule(labAssignments, scheduleStruct)
            dt = NaT;
            if isfield(scheduleStruct, 'date') && ~isempty(scheduleStruct.date)
                dt = conduction.DailySchedule.parseDate(scheduleStruct.date);
                return;
            end

            for idx = 1:numel(labAssignments)
                cases = labAssignments{idx};
                if isempty(cases)
                    continue;
                end
                sample = cases(1);
                if isfield(sample, 'date') && ~isempty(sample.date)
                    dt = conduction.DailySchedule.parseDate(sample.date);
                    return;
                end
            end
        end

        function range = deriveTimeRangeMinutes(labAssignments)
            starts = [];
            ends = [];
            for idx = 1:numel(labAssignments)
                cases = labAssignments{idx};
                if isempty(cases)
                    continue;
                end
                if isfield(cases, 'startTime')
                    starts = [starts, [cases.startTime]]; %#ok<AGROW>
                elseif isfield(cases, 'procStartTime')
                    starts = [starts, [cases.procStartTime]]; %#ok<AGROW>
                end
                if isfield(cases, 'endTime')
                    ends = [ends, [cases.endTime]]; %#ok<AGROW>
                elseif isfield(cases, 'procEndTime')
                    ends = [ends, [cases.procEndTime]]; %#ok<AGROW>
                end
            end

            if isempty(starts) || isempty(ends)
                range = [NaN, NaN];
            else
                range = [min(starts), max(ends)];
            end
        end
    end
end

