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

        function scheduleObj = fromHistoricalTable(dayTable, labsMap)
            %FROMHISTORICALTABLE Build a DailySchedule from historical table rows.
            arguments
                dayTable table
                labsMap containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'any')
            end

            if isempty(dayTable)
                scheduleObj = conduction.DailySchedule.empty;
                return;
            end

            if ~istable(dayTable)
                error('DailySchedule:InvalidHistoricalData', ...
                    'Historical data must be provided as a table.');
            end

            scheduleDate = conduction.DailySchedule.extractDateFromTable(dayTable);
            [labs, labAssignments] = conduction.DailySchedule.buildAssignmentsFromTable(dayTable, labsMap);

            metrics = struct(); % Metrics will be computed in dedicated analytics later.
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
            if isnat(dt)
                dt = NaT;
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
                if isfield(cases, 'procEndTime')
                    ends = [ends, [cases.procEndTime]]; %#ok<AGROW>
                elseif isfield(cases, 'endTime')
                    ends = [ends, [cases.endTime]]; %#ok<AGROW>
                end
            end

            if isempty(starts) || isempty(ends)
                range = [NaN, NaN];
            else
                range = [min(starts), max(ends)];
            end
        end

        function dt = extractDateFromTable(dayTable)
            dt = NaT;
            if ismember('date', dayTable.Properties.VariableNames)
                dateValues = dayTable.date;
                for idx = 1:numel(dateValues)
                    candidate = conduction.DailySchedule.parseDate(dateValues(idx));
                    if ~isnat(candidate)
                        dt = dateshift(candidate, 'start', 'day');
                        return;
                    end
                end
            end
            if isnat(dt)
                dt = NaT;
            end
        end

        function [labs, assignments] = buildAssignmentsFromTable(dayTable, labsMap)
            rooms = repmat("", height(dayTable), 1);
            if ismember('room', dayTable.Properties.VariableNames)
                rooms = string(dayTable.room);
            end

            labKeys = arrayfun(@(name) conduction.DailySchedule.labKeyForRoom(name), rooms, ...
                'UniformOutput', false);
            if isempty(labKeys)
                labs = conduction.Lab.empty(1, 0);
                assignments = cell(1, 0);
                return;
            end

            [uniqueKeys, ~, groupIdx] = unique(labKeys, 'stable');
            numLabs = numel(uniqueKeys);

            labCells = cell(1, numLabs);
            assignments = cell(1, numLabs);
            for labIdx = 1:numLabs
                rows = dayTable(groupIdx == labIdx, :);
                sampleRow = rows(1, :);
                roomName = "";
                if ismember('room', rows.Properties.VariableNames)
                    roomName = conduction.DailySchedule.getStringFromRow(sampleRow, 'room');
                end
                location = "";
                if ismember('location', rows.Properties.VariableNames)
                    location = conduction.DailySchedule.getStringFromRow(sampleRow, 'location');
                end

                labCells{labIdx} = conduction.DailySchedule.labForKey(uniqueKeys{labIdx}, roomName, location, labsMap);
                assignments{labIdx} = conduction.DailySchedule.buildCasesForLab(rows);
            end

            labs = [labCells{:}];
        end

        function key = labKeyForRoom(roomName)
            roomStr = string(roomName);
            if strlength(roomStr) == 0 || roomStr == "<missing>"
                key = 'lab_unassigned';
            else
                key = char(conduction.Lab.canonicalId(roomStr));
            end
        end

        function labObj = labForKey(key, roomName, location, labsMap)
            if labsMap.isKey(key)
                labObj = labsMap(key);
                return;
            end

            label = string(roomName);
            if strlength(label) == 0
                label = "Unassigned Lab";
            end

            loc = string(location);
            if strlength(loc) == 0
                loc = "";
            end

            labObj = conduction.Lab(label, loc);
        end

        function cases = buildCasesForLab(tableSlice)
            baseStruct = conduction.DailySchedule.baseCaseStruct();
            cases = repmat(baseStruct, 0, 1);

            for idx = 1:height(tableSlice)
                row = tableSlice(idx, :);
                caseStruct = conduction.DailySchedule.buildCaseFromRow(row);
                cases(end+1) = caseStruct; %#ok<AGROW>
            end

            if isempty(cases)
                cases = struct([]);
                return;
            end

            procStarts = [cases.procStartTime];
            [~, order] = sort(procStarts);
            cases = cases(order);
        end

        function caseStruct = buildCaseFromRow(row)
            caseStruct = conduction.DailySchedule.baseCaseStruct();

            caseIdValue = conduction.DailySchedule.getStringFromRow(row, 'case_id');
            operatorValue = conduction.DailySchedule.getStringFromRow(row, 'surgeon');
            roomValue = conduction.DailySchedule.getStringFromRow(row, 'room');

            caseStruct.caseID = char(caseIdValue);
            caseStruct.operator = char(operatorValue);
            caseStruct.room = char(roomValue);

            caseStruct.date = conduction.DailySchedule.getDatetimeFromRow(row, 'date');

            procStartDt = conduction.DailySchedule.getDatetimeFromRow(row, 'procedure_start_datetime');
            procEndDt = conduction.DailySchedule.getDatetimeFromRow(row, 'procedure_complete_datetime');

            procStartMinutes = conduction.DailySchedule.datetimeToMinutes(procStartDt);
            procEndMinutes = conduction.DailySchedule.datetimeToMinutes(procEndDt);

            setupMinutes = conduction.DailySchedule.getNumericFromRow(row, 'setup_minutes');
            procedureMinutes = conduction.DailySchedule.getNumericFromRow(row, 'procedure_minutes');
            postMinutes = conduction.DailySchedule.getNumericFromRow(row, 'post_procedure_minutes');
            turnoverMinutes = conduction.DailySchedule.getNumericFromRow(row, 'turnover_minutes');

            if isnan(postMinutes)
                postMinutes = 0;
            end
            if isnan(turnoverMinutes)
                turnoverMinutes = 0;
            end

            startMinutes = NaN;
            if ~isnan(procStartMinutes) && ~isnan(setupMinutes)
                startMinutes = procStartMinutes - setupMinutes;
            elseif ~isnan(procStartMinutes)
                startMinutes = procStartMinutes;
            end

            if isnan(procEndMinutes) && ~isnan(procStartMinutes) && ~isnan(procedureMinutes)
                procEndMinutes = procStartMinutes + procedureMinutes;
            end

            if ~isnan(startMinutes) && startMinutes < 0
                startMinutes = max(startMinutes, 0);
            end

            caseStruct.startTime = startMinutes;
            caseStruct.procStartTime = procStartMinutes;
            caseStruct.procEndTime = procEndMinutes;
            caseStruct.postTime = max(postMinutes, 0);
            caseStruct.turnoverTime = max(turnoverMinutes, 0);
            caseStruct.procedureMinutes = procedureMinutes;
            caseStruct.procedureDuration = procedureMinutes;
        end

        function baseStruct = baseCaseStruct()
            baseStruct = struct( ...
                'caseID', "", ...
                'operator', "", ...
                'startTime', NaN, ...
                'procStartTime', NaN, ...
                'procEndTime', NaN, ...
                'postTime', 0, ...
                'turnoverTime', 0, ...
                'procedureMinutes', NaN, ...
                'procedureDuration', NaN, ...
                'date', NaT, ...
                'room', "" ...
            );
        end

        function value = getNumericFromRow(row, varName)
            if ~ismember(varName, row.Properties.VariableNames)
                value = NaN;
                return;
            end
            raw = row.(varName);
            if istable(raw)
                raw = raw{1,1};
            end
            if iscell(raw)
                raw = raw{1};
            end
            if isstring(raw) || ischar(raw)
                value = str2double(raw);
            else
                value = double(raw);
            end
            if isnan(value)
                value = NaN;
            end
        end

        function str = getStringFromRow(row, varName)
            if ~ismember(varName, row.Properties.VariableNames)
                str = "";
                return;
            end
            raw = row.(varName);
            if istable(raw)
                raw = raw{1,1};
            end
            if iscell(raw)
                raw = raw{1};
            end
            if isstring(raw)
                str = raw(1);
            elseif ischar(raw)
                str = string(raw);
            elseif isnumeric(raw)
                if isempty(raw)
                    str = "";
                else
                    str = string(raw(1));
                end
            else
                str = "";
            end
        end

        function dt = getDatetimeFromRow(row, varName)
            if ~ismember(varName, row.Properties.VariableNames)
                dt = NaT;
                return;
            end
            raw = row.(varName);
            if istable(raw)
                raw = raw{1,1};
            end
            if iscell(raw)
                raw = raw{1};
            end
            if isa(raw, 'datetime')
                dt = raw;
            elseif isnumeric(raw)
                dt = datetime(raw, 'ConvertFrom', 'excel');
            elseif isstring(raw) || ischar(raw)
                try
                    dt = datetime(string(raw));
                catch
                    dt = NaT;
                end
            else
                dt = NaT;
            end
        end

        function mins = datetimeToMinutes(dt)
            if isempty(dt) || isnat(dt)
                mins = NaN;
                return;
            end
            mins = minutes(timeofday(dt));
        end
    end
end

