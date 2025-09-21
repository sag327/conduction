classdef ProcedureAnalyzer
    %PROCEDUREANALYZER Compute per-procedure samples for a DailySchedule.

    methods (Static)
        function result = analyze(dailySchedule)
            arguments
                dailySchedule conduction.DailySchedule
            end

            samples = conduction.analytics.helpers.ProcedureSampleHelper.collectSamples(dailySchedule);

            metricsMap = containers.Map('KeyType','char','ValueType','any');
            if isempty(samples)
                result = conduction.analytics.models.ProcedureDailyResult(dailySchedule.Date, metricsMap);
                return;
            end

            for idx = 1:numel(samples)
                sample = samples(idx);
                procKey = char(sample.procedureId);

                if ~isKey(metricsMap, procKey)
                    procEntry = conduction.analytics.models.ProcedureEntry(sample.procedureId, sample.procedureName);
                else
                    procEntry = metricsMap(procKey);
                end

                procEntry.Samples = conduction.analytics.helpers.ProcedureSampleHelper.appendSample(procEntry.Samples, sample);

                operatorKey = char(sample.operatorId);
                operatorMap = procEntry.OperatorMetrics;
                if ~isKey(operatorMap, operatorKey)
                    operatorEntry = conduction.analytics.models.ProcedureOperatorEntry(sample.operatorId, sample.operatorName);
                else
                    operatorEntry = operatorMap(operatorKey);
                end
                operatorEntry.Samples = conduction.analytics.helpers.ProcedureSampleHelper.appendSample(operatorEntry.Samples, sample);
                operatorMap(operatorKey) = operatorEntry;
                procEntry.OperatorMetrics = operatorMap;

                metricsMap(procKey) = procEntry;
            end

            result = conduction.analytics.models.ProcedureDailyResult(dailySchedule.Date, metricsMap);
        end
    end
end
