function config = configureOptimization(varargin)
%CONFIGUREOPTIMIZATION Build an optimization config struct for scheduling.
%   config = conduction.configureOptimization('NumLabs', 5, ...) returns a
%   struct capturing options suitable for conduction.optimizeDailySchedule.

options = conduction.scheduling.SchedulingOptions.fromArgs(varargin{:});
config = options.toStruct();
end
