function result = analyzeDailySchedule(dailySchedule)
%ANALYZEDAILYSCHEDULE Run all daily analyzers for a single schedule.
%   result = ANALYZEDAILYSCHEDULE(dailySchedule) returns a struct with
%   results from DailyAnalyzer, OperatorAnalyzer, and ProcedureAnalyzer.

if ~isa(dailySchedule, 'conduction.DailySchedule')
    error('analyzeDailySchedule:InvalidInput', ...
        'Expected a conduction.DailySchedule instance.');
end

result = struct();
result.date = dailySchedule.Date;
result.dailyMetrics = conduction.analytics.DailyAnalyzer.analyze(dailySchedule);

operatorResult = conduction.analytics.OperatorAnalyzer.analyze(dailySchedule);
result.operatorMetrics = operatorResult.operatorMetrics;
result.operatorDepartmentMetrics = operatorResult.departmentMetrics;

result.procedureMetrics = conduction.analytics.ProcedureAnalyzer.analyze(dailySchedule);
result.procedureSummary = conduction.analytics.helpers.ProcedureSummaryHelper.summarizeDaily( ...
    result.procedureMetrics.ProcedureMetrics);
end
