function [dailySchedule, outcome] = optimizeDailySchedule(cases, varargin)
%OPTIMIZEDAILYSCHEDULE Optimize EP lab schedule using conduction framework.
%   [dailySchedule, outcome] = conduction.optimizeDailySchedule(cases, optionsConfig)
%   runs the integer linear programming scheduler with the provided cases and
%   options configuration struct or name/value parameters. The result is a
%   conduction.DailySchedule along with optimization metadata (objective value,
%   solver output, and the legacy-compatible schedule struct).
%
%   Options can be provided as:
%       - A conduction.scheduling.SchedulingOptions instance
%       - A struct returned by conduction.configureOptimization
%       - Name/value pairs identical to those accepted by configureOptimization.
%
%   This refactors the legacy scripts/optimizeDailySchedule.m pipeline into
%   modular components under +conduction/+scheduling.

[options, remaining] = parseOptions(varargin{:});
if ~isempty(remaining)
    error('optimizeDailySchedule:InvalidArgs', ...
        'Unexpected arguments after options configuration.');
end

scheduler = conduction.scheduling.HistoricalScheduler(options);
[dailySchedule, outcome] = scheduler.schedule(cases);
end

function [options, remaining] = parseOptions(varargin)
if nargin == 0
    options = conduction.scheduling.SchedulingOptions.fromArgs();
    remaining = {};
    return;
end

firstArg = varargin{1};
remaining = varargin(2:end);

if isa(firstArg, 'conduction.scheduling.SchedulingOptions')
    if ~isempty(remaining)
        error('optimizeDailySchedule:InvalidArgs', ...
            'When passing a SchedulingOptions object, do not supply extra parameters.');
    end
    options = firstArg;
elseif isstruct(firstArg)
    basePairs = structToPairs(firstArg);
    if mod(numel(remaining), 2) ~= 0
        error('optimizeDailySchedule:InvalidArgs', ...
            'Additional parameters must be supplied as name/value pairs.');
    end
    options = conduction.scheduling.SchedulingOptions.fromArgs(basePairs{:}, remaining{:});
    remaining = {};
else
    options = conduction.scheduling.SchedulingOptions.fromArgs(varargin{:});
    remaining = {};
end
end

function pairs = structToPairs(s)
fields = fieldnames(s);
pairs = cell(1, numel(fields) * 2);
for idx = 1:numel(fields)
    pairs{2*idx-1} = fields{idx};
    pairs{2*idx} = s.(fields{idx});
end
end
