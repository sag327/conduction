classdef ScheduleCollectionAnalyzer < handle
    %SCHEDULECOLLECTIONANALYZER Orchestrate daily analyzers across schedules.

    properties (Access = private)
        Analyzers cell   % each cell: struct('name', string, 'fn', function_handle)
        Aggregators struct
        DailyOutputs struct
    end

    methods
        function obj = ScheduleCollectionAnalyzer()
            obj.Analyzers = {};
            obj.Aggregators = struct();
            obj.DailyOutputs = struct();
        end

        function registerAnalyzer(obj, name, analyzerFn, aggregatorFn)
            arguments
                obj
                name (1,1) string
                analyzerFn (1,1) function_handle
                aggregatorFn (1,1) function_handle
            end

            if obj.hasAnalyzer(name)
                return;
            end

            entry = struct('name', char(name), 'fn', analyzerFn, 'aggregatorFn', aggregatorFn);
            obj.Analyzers{end+1} = entry;
        end

        function addProcedureAnalyzer(obj)
            obj.registerAnalyzer("procedureMetrics", ...
                @(schedule) conduction.analytics.ProcedureAnalyzer.analyze(schedule), ...
                @conduction.analytics.ProcedureMetricsAggregator);
        end

        function results = run(obj, schedules)
            arguments
                obj
                schedules conduction.DailySchedule
            end

            if isempty(obj.Analyzers)
                obj.addProcedureAnalyzer();
            end

            analyzerCount = numel(obj.Analyzers);
            for idx = 1:analyzerCount
                analyzerName = char(obj.Analyzers{idx}.name);
                obj.Aggregators.(analyzerName) = obj.Analyzers{idx}.aggregatorFn();
                obj.DailyOutputs.(analyzerName) = {}; %#ok<STRCL>
            end

            for scheduleIdx = 1:numel(schedules)
                dailySchedule = schedules(scheduleIdx);
                for analyzerIdx = 1:analyzerCount
                    analyzerEntry = obj.Analyzers{analyzerIdx};
                    analyzerName = char(analyzerEntry.name);
                    analyzerFn = analyzerEntry.fn;

                    dailyResult = analyzerFn(dailySchedule);

                    if isa(obj.Aggregators.(analyzerName), 'handle') && ...
                            ismethod(obj.Aggregators.(analyzerName), 'accumulate')
                        obj.Aggregators.(analyzerName).accumulate(dailyResult);
                    end

                    obj.DailyOutputs.(analyzerName){end+1} = dailyResult; %#ok<*AGROW>
                end
            end

            results = struct();
            resultFields = fieldnames(obj.Aggregators);
            for idx = 1:numel(resultFields)
                field = resultFields{idx};
                aggregator = obj.Aggregators.(field);
                if isa(aggregator, 'handle') && ismethod(aggregator, "summarize")
                    results.(field) = aggregator.summarize();
                else
                    results.(field) = aggregator;
                end
            end

            results.daily = obj.DailyOutputs;
        end
    end

    methods (Access = private)
        function tf = hasAnalyzer(obj, name)
            tf = false;
            target = char(name);
            for idx = 1:numel(obj.Analyzers)
                if strcmp(obj.Analyzers{idx}.name, target)
                    tf = true;
                    return;
                end
            end
        end
    end
end
