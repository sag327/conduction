classdef HistoricalDataset
    %HISTORICALDATASET Wraps historical EP data with typed accessors.
    %   dataset = eprefactor.HistoricalDataset() loads the default dataset and
    %   exposes both the normalized table and the strongly-typed collections
    %   used throughout the refactor.

    properties (SetAccess = immutable)
        Table table
        Procedures containers.Map
        Operators containers.Map
        Labs containers.Map
        CaseRequests conduction.CaseRequest
    end

    methods (Static)
        function dataset = fromFile(filePath)
            arguments
                filePath (1,1) string
            end

            [tableData, historicalEntities] = conduction.loadHistoricalData(filePath);
            dataset = conduction.HistoricalDataset(tableData, historicalEntities);
        end
    end

    methods
        function obj = HistoricalDataset(tableData, entities)
            arguments
                tableData table
                entities struct
            end

            obj.Table = tableData;
            obj.Procedures = entities.procedures;
            obj.Operators = entities.operators;
            obj.Labs = entities.labs;
            obj.CaseRequests = entities.caseRequests;

        end

        function summary = dailyCaseSummary(obj)
            dates = dateshift(obj.Table.date, 'start', 'day');
            uniqueDates = unique(dates);
            numDates = numel(uniqueDates);

            summary = table('Size', [numDates 4], ...
                'VariableTypes', {'datetime', 'double', 'double', 'double'}, ...
                'VariableNames', {'Date', 'CaseCount', 'UniqueOperators', 'UniqueLabs'});

            for i = 1:numDates
                currentDate = uniqueDates(i);
                cases = obj.casesOnDate(currentDate);
                operatorNames = arrayfun(@(c) c.Operator.Name, cases, 'UniformOutput', false);
                labObjects = arrayfun(@(c) c.Lab, cases, 'UniformOutput', false);
                labObjects = labObjects(~cellfun(@isempty, labObjects));

                summary.Date(i) = currentDate;
                summary.CaseCount(i) = numel(cases);
                summary.UniqueOperators(i) = numel(unique(string(operatorNames)));
                if isempty(labObjects)
                    summary.UniqueLabs(i) = 0;
                else
                    labNames = cellfun(@(lab) lab.Id, labObjects, 'UniformOutput', false);
                    summary.UniqueLabs(i) = numel(unique(string(labNames)));
                end
            end
        end

        function cases = casesOnDate(obj, targetDate)
            targetDate = datetime(targetDate);
            mask = dateshift(obj.Table.date, 'start', 'day') == dateshift(targetDate, 'start', 'day');
            cases = obj.CaseRequests(mask);
        end

        function schedule = dailyScheduleForDate(obj, targetDate)
            arguments
                obj
                targetDate
            end

            if isempty(obj.Table)
                schedule = conduction.DailySchedule.empty;
                return;
            end

            dayValue = dateshift(datetime(targetDate), 'start', 'day');
            dateVector = dateshift(obj.Table.date, 'start', 'day');
            mask = dateVector == dayValue;
            if ~any(mask)
                schedule = conduction.DailySchedule.empty;
                return;
            end

            dayTable = obj.Table(mask, :);
            schedule = conduction.DailySchedule.fromHistoricalTable(dayTable, obj.Labs);
        end

        function schedules = dailySchedules(obj)
            if isempty(obj.Table)
                schedules = conduction.DailySchedule.empty;
                return;
            end

            uniqueDates = unique(dateshift(obj.Table.date, 'start', 'day'));
            scheduleCells = cell(1, numel(uniqueDates));
            count = 0;
            for idxDate = 1:numel(uniqueDates)
                schedule = obj.dailyScheduleForDate(uniqueDates(idxDate));
                if ~isempty(schedule)
                    count = count + 1;
                    scheduleCells{count} = schedule;
                end
            end

            if count == 0
                schedules = conduction.DailySchedule.empty;
            else
                schedules = [scheduleCells{1:count}];
            end
        end

        function cases = casesBetween(obj, startDate, endDate)
            startDate = datetime(startDate);
            endDate = datetime(endDate);
            mask = obj.Table.date >= startDate & obj.Table.date <= endDate;
            cases = obj.CaseRequests(mask);
        end

        function cases = casesByAdmissionStatus(obj, status)
            status = string(status);
            mask = string(obj.Table.admission_status) == status;
            cases = obj.CaseRequests(mask);
        end

        function cases = casesForOperator(obj, operatorIdentifier)
            arguments
                obj
                operatorIdentifier (1,1) string
            end

            operatorId = conduction.Operator.canonicalId(operatorIdentifier);
            mask = arrayfun(@(c) c.Operator.Id == operatorId, obj.CaseRequests);
            cases = obj.CaseRequests(mask);
        end

        function operators = operatorsForProcedure(obj, procedureIdentifier)
            cases = obj.casesForProcedure(procedureIdentifier);
            operatorNames = arrayfun(@(c) c.Operator.Name, cases, 'UniformOutput', false);
            operators = unique(string(operatorNames));
        end

        function cases = casesForProcedure(obj, procedureIdentifier)
            arguments
                obj
                procedureIdentifier (1,1) string
            end

            procedureId = conduction.Procedure.canonicalId(procedureIdentifier);
            mask = arrayfun(@(c) c.Procedure.Id == procedureId, obj.CaseRequests);
            cases = obj.CaseRequests(mask);
        end

        function operatorList = operatorsOnDate(obj, targetDate)
            cases = obj.casesOnDate(targetDate);
            operatorNames = arrayfun(@(c) c.Operator.Name, cases, 'UniformOutput', false);
            operatorList = unique(string(operatorNames));
        end

        function labList = labsOnDate(obj, targetDate)
            cases = obj.casesOnDate(targetDate);
            if isempty(cases)
                labList = string.empty(0, 1);
                return;
            end
            labObjects = arrayfun(@(c) c.Lab, cases, 'UniformOutput', false);
            labObjects = labObjects(~cellfun(@isempty, labObjects));
            if isempty(labObjects)
                labList = string.empty(0, 1);
                return;
            end
            labNames = cellfun(@(lab) lab.Id, labObjects, 'UniformOutput', false);
            labList = unique(string(labNames));
        end

        function labSummary = labsOnDateWithCounts(obj, targetDate)
            cases = obj.casesOnDate(targetDate);
            labSummary = table(string.empty(0,1), double.empty(0,1), 'VariableNames', {'LabId', 'CaseCount'});
            if isempty(cases)
                return;
            end

            labObjects = arrayfun(@(c) c.Lab, cases, 'UniformOutput', false);
            labObjects = labObjects(~cellfun(@isempty, labObjects));
            if isempty(labObjects)
                return;
            end

            labIds = string(cellfun(@(lab) lab.Id, labObjects, 'UniformOutput', false));
            [uniqueLabIds, ~, idx] = unique(labIds);
            counts = accumarray(idx, 1);
            labSummary = table(uniqueLabIds, counts, 'VariableNames', {'LabId', 'CaseCount'});
        end

        function procList = proceduresForOperator(obj, operatorIdentifier)
            cases = obj.casesForOperator(operatorIdentifier);
            procNames = arrayfun(@(c) c.Procedure.Name, cases, 'UniformOutput', false);
            procList = unique(string(procNames));
        end

        function volumeMap = procedureVolumeByOperator(obj, operatorIdentifier)
            cases = obj.casesForOperator(operatorIdentifier);
            procedureNames = arrayfun(@(c) c.Procedure.Name, cases, 'UniformOutput', false);
            [uniqueNames, ~, idx] = unique(string(procedureNames));
            counts = accumarray(idx, 1);
            volumeMap = containers.Map(cellstr(uniqueNames), num2cell(counts));
        end

        function values = procedureIds(obj)
            values = obj.Procedures.keys;
        end

        function ids = operatorIds(obj)
            ids = obj.Operators.keys;
        end

        function labIds = labIds(obj)
            labIds = obj.Labs.keys;
        end
    end

    methods (Access = private)
        function [schedules, indexMap] = buildDailySchedules(obj)
            if isempty(obj.Table)
                schedules = conduction.DailySchedule.empty;
                indexMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
                return;
            end

            uniqueDates = unique(dateshift(obj.Table.date, 'start', 'day'));
            scheduleCells = cell(1, numel(uniqueDates));
            indexMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
            count = 0;
            dateVector = dateshift(obj.Table.date, 'start', 'day');
            for idxDate = 1:numel(uniqueDates)
                dayValue = uniqueDates(idxDate);
                mask = dateVector == dayValue;
                dayTable = obj.Table(mask, :);
                schedule = conduction.DailySchedule.fromHistoricalTable(dayTable, obj.Labs);
                if ~isempty(schedule)
                    count = count + 1;
                    scheduleCells{count} = schedule;
                    indexMap(conduction.HistoricalDataset.scheduleKey(dayValue)) = count;
                end
            end

            if count == 0
                schedules = conduction.DailySchedule.empty;
            else
                schedules = [scheduleCells{1:count}];
            end
        end
    end

end
