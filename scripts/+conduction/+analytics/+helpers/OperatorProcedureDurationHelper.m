classdef OperatorProcedureDurationHelper
    %OPERATORPROCEDUREDURATIONHELPER Extract duration arrays for operator-procedure combinations.

    methods (Static)
        function durations = getOperatorProcedureDurations(scheduleCollectionOrAggregator, operatorName, procedureName, durationField)
            %GETOPERATORPROCEDUREDURATIONS Get array of durations for specific operator-procedure combo.
            %
            %   durations = getOperatorProcedureDurations(scheduleCollectionOrAggregator, operatorName, procedureName, durationField)
            %   extracts an array of duration values for the specified operator performing
            %   the specified procedure.
            %
            %   INPUTS:
            %       scheduleCollectionOrAggregator - Either:
            %                          (1) A ScheduleCollection object (automatically aggregates)
            %                          (2) An array of DailySchedule objects (automatically aggregates)
            %                          (3) A ProcedureMetricsAggregator object (uses existing aggregation)
            %       operatorName     - Name of operator (string or char)
            %       procedureName    - Name of procedure (string or char)
            %       durationField    - Duration field to extract:
            %                          'totalCaseMinutes', 'procedureMinutes', 'setupMinutes',
            %                          'postMinutes', 'turnoverMinutes'
            %
            %   OUTPUT:
            %       durations        - Column vector of duration values (may include NaN)
            %                          Returns empty [] if no data found
            %
            %   EXAMPLES:
            %       % From ScheduleCollection (easiest)
            %       scheduleCollection = conduction.ScheduleCollection.fromFile('data.csv');
            %       durations = conduction.analytics.helpers.OperatorProcedureDurationHelper...
            %           .getOperatorProcedureDurations(scheduleCollection, 'Dr. Smith', 'Appendectomy', 'procedureMinutes');
            %
            %       % From DailySchedule array
            %       schedules = scheduleCollection.dailySchedules();
            %       durations = conduction.analytics.helpers.OperatorProcedureDurationHelper...
            %           .getOperatorProcedureDurations(schedules, 'Dr. Smith', 'Appendectomy', 'procedureMinutes');

            arguments
                scheduleCollectionOrAggregator
                operatorName {mustBeTextScalar}
                procedureName {mustBeTextScalar}
                durationField {mustBeTextScalar}
            end

            % Initialize empty result
            durations = [];

            % Validate inputs
            operatorName = string(operatorName);
            procedureName = string(procedureName);
            durationField = string(durationField);

            % Validate duration field
            validFields = ["totalCaseMinutes", "procedureMinutes", "setupMinutes", "postMinutes", "turnoverMinutes"];
            if ~any(durationField == validFields)
                error('OperatorProcedureDurationHelper:InvalidField', ...
                    'Duration field must be one of: %s', strjoin(validFields, ', '));
            end

            % Get or create the aggregator based on input type
            if isa(scheduleCollectionOrAggregator, 'conduction.ScheduleCollection')
                % Extract schedules and aggregate
                schedules = scheduleCollectionOrAggregator.dailySchedules();
                aggregator = conduction.analytics.helpers.OperatorProcedureDurationHelper.buildAggregator(schedules);
            elseif isa(scheduleCollectionOrAggregator, 'conduction.DailySchedule')
                % Aggregate the schedule array
                aggregator = conduction.analytics.helpers.OperatorProcedureDurationHelper.buildAggregator(scheduleCollectionOrAggregator);
            elseif isa(scheduleCollectionOrAggregator, 'conduction.analytics.ProcedureMetricsAggregator')
                % Use provided aggregator
                aggregator = scheduleCollectionOrAggregator;
            else
                error('OperatorProcedureDurationHelper:InvalidInput', ...
                    'First argument must be a ScheduleCollection, DailySchedule array, or ProcedureMetricsAggregator.');
            end

            % Get the procedure map using public accessor
            procedureMap = aggregator.getProcedureMap();

            % Search through procedures map
            procedureKeys = keys(procedureMap);

            for i = 1:length(procedureKeys)
                procEntry = procedureMap(procedureKeys{i});

                % Check if this is the right procedure (ProcedureEntry object)
                if ~isprop(procEntry, 'ProcedureName') && ~isfield(procEntry, 'ProcedureName')
                    continue;
                end

                entryProcName = procEntry.ProcedureName;
                if ~strcmp(string(entryProcName), procedureName)
                    continue;
                end

                % Check if we have operator metrics
                if ~isprop(procEntry, 'OperatorMetrics') && ~isfield(procEntry, 'OperatorMetrics')
                    continue;
                end

                operatorMetrics = procEntry.OperatorMetrics;
                if ~isa(operatorMetrics, 'containers.Map')
                    continue;
                end

                % Look through operator metrics for matching operator
                operatorKeys = keys(operatorMetrics);
                for j = 1:length(operatorKeys)
                    operatorEntry = operatorMetrics(operatorKeys{j});

                    % Get operator name
                    if isprop(operatorEntry, 'OperatorName')
                        entryOpName = operatorEntry.OperatorName;
                    elseif isfield(operatorEntry, 'OperatorName')
                        entryOpName = operatorEntry.OperatorName;
                    else
                        continue;
                    end

                    if ~strcmp(string(entryOpName), operatorName)
                        continue;
                    end

                    % Extract the requested duration field from Samples
                    if isprop(operatorEntry, 'Samples')
                        samples = operatorEntry.Samples;
                    elseif isfield(operatorEntry, 'Samples')
                        samples = operatorEntry.Samples;
                    else
                        continue;
                    end

                    if ~isfield(samples, char(durationField))
                        continue;
                    end

                    durations = samples.(char(durationField));

                    % Ensure column vector
                    if isrow(durations)
                        durations = durations(:);
                    end

                    return;
                end
            end
        end

        function aggregator = buildAggregator(schedules)
            %BUILDAGGREGATOR Create and populate a ProcedureMetricsAggregator from schedules.

            arguments
                schedules conduction.DailySchedule
            end

            aggregator = conduction.analytics.ProcedureMetricsAggregator();

            for i = 1:numel(schedules)
                result = conduction.analytics.ProcedureAnalyzer.analyze(schedules(i));
                aggregator.accumulate(result);
            end
        end

        function durations = getAllOperatorsProcedureDurations(scheduleCollectionOrAggregator, procedureName, durationField)
            %GETALLOPERATORSPROCEDUREDURATIONS Get durations for a procedure across all operators.
            %
            %   durations = getAllOperatorsProcedureDurations(scheduleCollectionOrAggregator, procedureName, durationField)
            %   extracts all duration values for the specified procedure across all operators.

            arguments
                scheduleCollectionOrAggregator
                procedureName {mustBeTextScalar}
                durationField {mustBeTextScalar}
            end

            % Initialize empty result
            durations = [];

            % Validate inputs
            procedureName = string(procedureName);
            durationField = string(durationField);

            % Get or create the aggregator
            if isa(scheduleCollectionOrAggregator, 'conduction.ScheduleCollection')
                schedules = scheduleCollectionOrAggregator.dailySchedules();
                aggregator = conduction.analytics.helpers.OperatorProcedureDurationHelper.buildAggregator(schedules);
            elseif isa(scheduleCollectionOrAggregator, 'conduction.DailySchedule')
                aggregator = conduction.analytics.helpers.OperatorProcedureDurationHelper.buildAggregator(scheduleCollectionOrAggregator);
            elseif isa(scheduleCollectionOrAggregator, 'conduction.analytics.ProcedureMetricsAggregator')
                aggregator = scheduleCollectionOrAggregator;
            else
                return;
            end

            % Get the procedure map
            procedureMap = aggregator.getProcedureMap();

            % Search through procedures map
            procedureKeys = keys(procedureMap);

            for i = 1:length(procedureKeys)
                procEntry = procedureMap(procedureKeys{i});

                % Check if this is the right procedure
                if ~isprop(procEntry, 'ProcedureName') && ~isfield(procEntry, 'ProcedureName')
                    continue;
                end

                entryProcName = procEntry.ProcedureName;
                if ~strcmp(string(entryProcName), procedureName)
                    continue;
                end

                % Get operator metrics
                if ~isprop(procEntry, 'OperatorMetrics') && ~isfield(procEntry, 'OperatorMetrics')
                    continue;
                end

                operatorMetrics = procEntry.OperatorMetrics;
                if ~isa(operatorMetrics, 'containers.Map')
                    continue;
                end

                % Collect durations from all operators
                operatorKeys = keys(operatorMetrics);
                allDurations = [];

                for j = 1:length(operatorKeys)
                    operatorEntry = operatorMetrics(operatorKeys{j});

                    % Extract samples
                    if isprop(operatorEntry, 'Samples')
                        samples = operatorEntry.Samples;
                    elseif isfield(operatorEntry, 'Samples')
                        samples = operatorEntry.Samples;
                    else
                        continue;
                    end

                    if ~isfield(samples, char(durationField))
                        continue;
                    end

                    opDurations = samples.(char(durationField));
                    if ~isempty(opDurations)
                        allDurations = [allDurations; opDurations(:)]; %#ok<AGROW>
                    end
                end

                durations = allDurations;
                return;
            end
        end
    end
end