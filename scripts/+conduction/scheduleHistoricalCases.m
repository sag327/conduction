function [dailySchedule, outcome] = scheduleHistoricalCases(cases, varargin)
%SCHEDULEHISTORICALCASES Optimize EP lab schedule using conduction framework.
%   [dailySchedule, outcome] = conduction.scheduleHistoricalCases(cases, ...)
%   runs the integer linear programming scheduler with the provided cases and
%   optional name/value parameters. The result is a conduction.DailySchedule
%   along with optimization metadata (objective value, solver output, and the
%   legacy-compatible schedule struct).
%
%   This refactors the legacy scripts/scheduleHistoricalCases.m pipeline into
%   modular components under +conduction/+scheduling.

options = conduction.scheduling.SchedulingOptions.fromArgs(varargin{:});
scheduler = conduction.scheduling.HistoricalScheduler(options);
[dailySchedule, outcome] = scheduler.schedule(cases);
end
