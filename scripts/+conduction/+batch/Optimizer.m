classdef Optimizer
    %OPTIMIZER Runs daily schedule optimization across an entire collection.

    properties (SetAccess = immutable)
        Options (1,1) conduction.batch.OptimizationOptions
    end

    methods
        function obj = Optimizer(options)
            arguments
                options conduction.batch.OptimizationOptions
            end
            obj.Options = options;
        end

        function batchResult = run(obj, scheduleCollection)

            schedules = scheduleCollection.dailySchedules();
            if isempty(schedules)
                batchResult = struct('results', conduction.batch.OptimizationResult.empty, 'failures', []);
                return;
            end

            filter = obj.Options.DateFilter;
            mask = arrayfun(@(ds) filter(ds.Date), schedules);
            schedules = schedules(mask);

            if isempty(schedules)
                batchResult = struct('results', conduction.batch.OptimizationResult.empty, 'failures', []);
                return;
            end

            numDays = numel(schedules);
            failures = strings(0,1);

            if obj.Options.ShowProgress
                fprintf('Optimizing %d day(s)...\n', numDays);
            end

            validMask = true(numDays,1);
            for idx = 1:numDays
                try
                    trialCases = schedules(idx).toOptimizationCases();
                    if any(isnan([trialCases.procTime]))
                        validMask(idx) = false;
                        failures(end+1,1) = sprintf('Missing procedure time on %s', datestr(schedules(idx).Date)); %#ok<AGROW>
                    end
                catch ME
                    validMask(idx) = false;
                    failures(end+1,1) = sprintf('Preprocessing failed on %s (%s)', datestr(schedules(idx).Date), ME.message); %#ok<AGROW>
                end
            end

            if obj.Options.ShowProgress && any(~validMask)
                fprintf('  Skipping %d day(s) due to missing procedure durations.\n', sum(~validMask));
            end

            schedules = schedules(validMask);
            numDays = numel(schedules);
            resultCells = cell(numDays, 1);

            if obj.Options.Parallel
                scheduleCells = num2cell(schedules);
                schedOptions = obj.Options.SchedulingOptions;
                if obj.Options.ShowProgress
                    progressQueue = parallel.pool.DataQueue;
                    progressCount = 0; %#ok<NASGU>
                    afterEach(progressQueue, @updateProgress);
                end
                parfor idx = 1:numDays
                    dailySchedule = scheduleCells{idx};
                    [optSchedule, outcome] = conduction.optimizeDailySchedule(dailySchedule, schedOptions);
                    resultCells{idx} = conduction.batch.OptimizationResult(dailySchedule, optSchedule, outcome);
                    if obj.Options.ShowProgress
                        send(progressQueue, idx);
                    end
                end
            else
                for idx = 1:numDays
                    try
                        [optSchedule, outcome] = conduction.optimizeDailySchedule(schedules(idx), obj.Options.SchedulingOptions);
                        resultCells{idx} = conduction.batch.OptimizationResult(schedules(idx), optSchedule, outcome);
                        if obj.Options.ShowProgress
                            fprintf('  (%d/%d) %s\n', idx, numDays, datestr(schedules(idx).Date));
                        end
                    catch ME
                        failures(end+1,1) = sprintf('%s (%s)', datestr(schedules(idx).Date), ME.message); %#ok<AGROW>
                        resultCells{idx} = conduction.batch.OptimizationResult(schedules(idx), conduction.DailySchedule.empty, struct('error', ME));
                        if obj.Options.ShowProgress
                            fprintf('  (%d/%d) %s [skipped]\n', idx, numDays, datestr(schedules(idx).Date));
                        end
                    end
                end
            end
            results = [resultCells{:}]';
            batchResult = struct('results', results, 'failures', failures);

            function updateProgress(dayIdx)
                persistent count total
                if isempty(count)
                    count = 0;
                    total = numDays;
                end
                count = count + 1;
                fprintf('  (%d/%d) %s\n', count, total, datestr(schedules(dayIdx).Date));
                if count == total
                    count = [];
                    total = [];
                end
            end
        end
    end

    methods (Static)
        function batchResult = runWithOptions(scheduleCollection, varargin)
            options = conduction.batch.OptimizationOptions.fromArgs(varargin{:});
            optimizer = conduction.batch.Optimizer(options);
            batchResult = optimizer.run(scheduleCollection);
        end
    end
end
