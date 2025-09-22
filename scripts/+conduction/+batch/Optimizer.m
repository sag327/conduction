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
            versionInfo = conduction.version();
            generatedAt = datetime('now','TimeZone','UTC');
            metadata = struct('version', versionInfo, 'generatedAt', generatedAt);
            if isempty(schedules)
                batchResult = struct('results', conduction.batch.OptimizationResult.empty, ...
                    'failures', [], 'metadata', metadata);
                return;
            end

            filter = obj.Options.DateFilter;
            mask = arrayfun(@(ds) filter(ds.Date), schedules);
            schedules = schedules(mask);

            if isempty(schedules)
                batchResult = struct('results', conduction.batch.OptimizationResult.empty, ...
                    'failures', [], 'metadata', metadata);
                return;
            end

            numDays = numel(schedules);
            failures = strings(0,1);

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

            skippedCount = sum(~validMask);
            schedules = schedules(validMask);
            numDays = numel(schedules);
            resultCells = cell(numDays, 1);

            if obj.Options.ShowProgress
                if skippedCount > 0
                    fprintf('Skipping %d day(s) due to missing procedure durations.\n', skippedCount);
                end
                fprintf('Optimizing %d day(s)...\n', numDays);
                if numDays > 0
                    progressBar = conduction.internal.util.ProgressBar(numDays);
                end
            end

            if obj.Options.Parallel
                scheduleCells = num2cell(schedules);
                schedOptions = obj.Options.SchedulingOptions;
                progressQueue = [];
                if obj.Options.ShowProgress && numDays > 0
                    progressQueue = parallel.pool.DataQueue;
                    afterEach(progressQueue, @(~) progressBar.increment());
                end
                parfor idx = 1:numDays
                    dailySchedule = scheduleCells{idx};
                    [optSchedule, outcome] = conduction.optimizeDailySchedule(dailySchedule, schedOptions);
                    result = conduction.batch.OptimizationResult(dailySchedule, optSchedule, outcome);
                    resultCells{idx} = result.withMetadata(metadata);
                    if obj.Options.ShowProgress && numDays > 0
                        send(progressQueue, idx);
                    end
                end
            else
                for idx = 1:numDays
                    try
                        [optSchedule, outcome] = conduction.optimizeDailySchedule(schedules(idx), obj.Options.SchedulingOptions);
                        result = conduction.batch.OptimizationResult(schedules(idx), optSchedule, outcome);
                        resultCells{idx} = result.withMetadata(metadata);
                        if obj.Options.ShowProgress && numDays > 0; progressBar.increment(); end
                    catch ME
                        failures(end+1,1) = sprintf('%s (%s)', datestr(schedules(idx).Date), ME.message); %#ok<AGROW>
                        result = conduction.batch.OptimizationResult(schedules(idx), conduction.DailySchedule.empty, struct('error', ME));
                        resultCells{idx} = result.withMetadata(metadata);
                        if obj.Options.ShowProgress && numDays > 0; progressBar.increment(); end
                    end
                end
            end
            results = [resultCells{:}]';

            optimizedSchedules = conduction.DailySchedule.empty(1,0);
            if ~isempty(results)
                scheduleCells = cell(numel(results),1);
                count = 0;
                for idxResult = 1:numel(results)
                    candidate = results(idxResult).OptimizedSchedule;
                    if ~isempty(candidate)
                        count = count + 1;
                        scheduleCells{count} = candidate;
                    end
                end
                if count > 0
                    optimizedSchedules = [scheduleCells{1:count}];
                end
            end

            optimizedCollection = conduction.ScheduleCollection.fromSchedules(optimizedSchedules);

            batchResult = struct('results', results, ...
                'failures', failures, ...
                'optimizedSchedules', optimizedSchedules, ...
                'optimizedCollection', optimizedCollection, ...
                'metadata', metadata);

            if obj.Options.ShowProgress && exist('progressBar', 'var')
                progressBar.finish();
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
