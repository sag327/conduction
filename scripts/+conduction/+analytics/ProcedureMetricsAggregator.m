classdef ProcedureMetricsAggregator < conduction.analytics.interfaces.Aggregator
    %PROCEDUREMETRICSAGGREGATOR Accumulate ProcedureDailyResult objects across days.

    properties (Access = private)
        ProcedureMap containers.Map % procedureId -> ProcedureEntry (aggregate)
    end

    methods
        function obj = ProcedureMetricsAggregator()
            obj.reset();
        end

        function reset(obj)
            obj.ProcedureMap = containers.Map('KeyType','char','ValueType','any');
        end

        function accumulate(obj, dailyResult)
            if isempty(dailyResult) || ~isa(dailyResult, 'conduction.analytics.models.ProcedureDailyResult')
                return;
            end

            procKeys = dailyResult.ProcedureMetrics.keys;
            for idx = 1:numel(procKeys)
                key = procKeys{idx};
                dailyEntry = dailyResult.ProcedureMetrics(key);

                if ~isKey(obj.ProcedureMap, key)
                    aggregateEntry = conduction.analytics.models.ProcedureEntry(dailyEntry.ProcedureId, dailyEntry.ProcedureName);
                else
                    aggregateEntry = obj.ProcedureMap(key);
                end

                aggregateEntry.Samples = conduction.analytics.ProcedureMetricsAggregator.concatSamples( ...
                    aggregateEntry.Samples, dailyEntry.Samples);

                operatorKeys = dailyEntry.OperatorMetrics.keys;
                for opIdx = 1:numel(operatorKeys)
                    opKey = operatorKeys{opIdx};
                    dailyOpEntry = dailyEntry.OperatorMetrics(opKey);

                    operatorMap = aggregateEntry.OperatorMetrics;
                    if ~isKey(operatorMap, opKey)
                        aggregateOpEntry = conduction.analytics.models.ProcedureOperatorEntry(dailyOpEntry.OperatorId, dailyOpEntry.OperatorName);
                    else
                        aggregateOpEntry = operatorMap(opKey);
                    end

                    aggregateOpEntry.Samples = conduction.analytics.ProcedureMetricsAggregator.concatSamples( ...
                        aggregateOpEntry.Samples, dailyOpEntry.Samples);
                    operatorMap(opKey) = aggregateOpEntry;
                    aggregateEntry.OperatorMetrics = operatorMap;
                end

                obj.ProcedureMap(key) = aggregateEntry;
            end
        end

        function summary = summarize(obj)
            summary = struct();
            summary.procedures = containers.Map('KeyType','char','ValueType','any');
            summary.totalProcedures = obj.ProcedureMap.Count;

            procKeys = obj.ProcedureMap.keys;
            for idx = 1:numel(procKeys)
                key = procKeys{idx};
                aggregateEntry = obj.ProcedureMap(key);

                overallStats = conduction.analytics.helpers.StatsHelper.summarize( ...
                    aggregateEntry.Samples.procedureMinutes);

                operatorSummaries = containers.Map('KeyType','char','ValueType','any');
                opKeys = aggregateEntry.OperatorMetrics.keys;
                for opIdx = 1:numel(opKeys)
                    opKey = opKeys{opIdx};
                    opEntry = aggregateEntry.OperatorMetrics(opKey);
                    opStats = conduction.analytics.helpers.StatsHelper.summarize(opEntry.Samples.procedureMinutes);
                    operatorSummaries(opKey) = struct( ...
                        'operatorId', opEntry.OperatorId, ...
                        'operatorName', opEntry.OperatorName, ...
                        'stats', opStats ...
                    );
                end

                summary.procedures(key) = struct( ...
                    'procedureId', aggregateEntry.ProcedureId, ...
                    'procedureName', aggregateEntry.ProcedureName, ...
                    'overall', overallStats, ...
                    'operators', operatorSummaries ...
                );
            end
        end

        function map = getProcedureMap(obj)
            %GETPROCEDUREMAP Public accessor for the internal ProcedureMap.
            %   Returns the raw procedure map containing ProcedureEntry objects
            %   with operator metrics and sample data.
            map = obj.ProcedureMap;
        end
    end

    methods (Static, Access = private)
        function combined = concatSamples(existingSamples, newSamples)
            if isempty(existingSamples.setupMinutes)
                combined = newSamples;
                return;
            end

            combined = existingSamples;
            combined.setupMinutes = [combined.setupMinutes; newSamples.setupMinutes(:)];
            combined.procedureMinutes = [combined.procedureMinutes; newSamples.procedureMinutes(:)];
            combined.postMinutes = [combined.postMinutes; newSamples.postMinutes(:)];
            combined.turnoverMinutes = [combined.turnoverMinutes; newSamples.turnoverMinutes(:)];
            combined.totalCaseMinutes = [combined.totalCaseMinutes; newSamples.totalCaseMinutes(:)];
        end
    end
end
