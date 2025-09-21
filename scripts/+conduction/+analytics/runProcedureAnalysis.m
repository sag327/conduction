function summary = runProcedureAnalysis(scheduleCollection)
%RUNPROCEDUREANALYSIS Convenience helper to analyze all procedures in a collection.
%   summary = RUNPROCEDUREANALYSIS(collection) loads each daily schedule,
%   runs the procedure analyzer, and returns aggregated statistics from
%   ProcedureMetricsAggregator.
%
%   scheduleCollection can be a conduction.ScheduleCollection or an array of
%   conduction.DailySchedule objects.

if isa(scheduleCollection, 'conduction.ScheduleCollection')
    schedules = scheduleCollection.dailySchedules();
elseif isa(scheduleCollection, 'conduction.DailySchedule')
    schedules = scheduleCollection;
else
    error('runProcedureAnalysis:InvalidInput', ...
        'Expected ScheduleCollection or array of DailySchedule objects.');
end

analyzer = conduction.analytics.ScheduleCollectionAnalyzer();
analyzer.addProcedureAnalyzer();
results = analyzer.run(schedules);
summary = results.procedureMetrics;
end
