function batchResult = optimizeScheduleCollection(input, config, varargin)
%OPTIMIZESCHEDULECOLLECTION Optimize every day in a schedule collection.
%   batchResult = OPTIMIZESCHEDULECOLLECTION(collection, config, ...) runs the
%   batch optimizer across all daily schedules in the provided
%   ScheduleCollection (or file path). The second argument must be the
%   optimization configuration produced by conduction.configureOptimization
%   (or a conduction.scheduling.SchedulingOptions instance). Name/value
%   pairs after the config are forwarded to conduction.batch.OptimizationOptions.

if nargin < 2
    error('optimizeScheduleCollection:MissingConfig', ...
        'Provide the optimization configuration from configureOptimization.');
end

collection = resolveCollection(input);
schedulingOptions = resolveSchedulingOptions(config);

if isempty(varargin)
    optOptions = conduction.batch.OptimizationOptions('SchedulingOptions', schedulingOptions);
elseif isa(varargin{1}, 'conduction.batch.OptimizationOptions')
    existing = varargin{1};
    optStruct = struct(existing);
    optStruct.SchedulingOptions = schedulingOptions;
    optOptions = conduction.batch.OptimizationOptions(optStruct);
    if numel(varargin) > 1
        warning('optimizeScheduleCollection:UnusedArgs', ...
            'Additional arguments ignored because an OptimizationOptions object was supplied.');
    end
else
    optOptions = conduction.batch.OptimizationOptions('SchedulingOptions', schedulingOptions, varargin{:});
end

optimizer = conduction.batch.Optimizer(optOptions);
batchResult = optimizer.run(collection);
end

function collection = resolveCollection(input)
if isa(input, 'conduction.ScheduleCollection')
    collection = input;
elseif ischar(input) || isstring(input)
    collection = conduction.ScheduleCollection.fromFile(string(input));
else
    error('optimizeScheduleCollection:InvalidInput', ...
        'Provide a ScheduleCollection or file path to optimize.');
end
end

function schedulingOptions = resolveSchedulingOptions(config)
if isa(config, 'conduction.scheduling.SchedulingOptions')
    schedulingOptions = config;
elseif isstruct(config)
    fields = fieldnames(config);
    pairs = cell(1, numel(fields) * 2);
    for idx = 1:numel(fields)
        pairs{2*idx-1} = fields{idx};
        pairs{2*idx} = config.(fields{idx});
    end
    schedulingOptions = conduction.scheduling.SchedulingOptions.fromArgs(pairs{:});
else
    error('optimizeScheduleCollection:InvalidConfig', ...
        'Config must be a struct from configureOptimization or a SchedulingOptions object.');
end
end
