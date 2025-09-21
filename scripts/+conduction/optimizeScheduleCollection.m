function batchResult = optimizeScheduleCollection(input, varargin)
%OPTIMIZESCHEDULECOLLECTION Optimize every day in a schedule collection.
%   result = OPTIMIZESCHEDULECOLLECTION(collection) runs the batch optimizer
%   across all daily schedules in the provided ScheduleCollection.
%
%   result = OPTIMIZESCHEDULECOLLECTION(collection, options) accepts an
%   existing conduction.batch.OptimizationOptions object.
%
%   result = OPTIMIZESCHEDULECOLLECTION(collection, Name,Value,...) creates
%   an OptimizationOptions object using the supplied Name/Value pairs before
%   running the optimizer.
%
%   result = OPTIMIZESCHEDULECOLLECTION(filePath, ...) loads the collection
%   from the specified file (e.g., Excel) before optimizing.

if isa(input, 'conduction.ScheduleCollection')
    collection = input;
elseif isstring(input) || ischar(input)
    collection = conduction.ScheduleCollection.fromFile(string(input));
else
    error('optimizeScheduleCollection:InvalidInput', ...
        'Provide a ScheduleCollection or file path to optimize.');
end

if isempty(varargin)
    optOptions = conduction.batch.OptimizationOptions();
elseif isa(varargin{1}, 'conduction.batch.OptimizationOptions')
    optOptions = varargin{1};
    if numel(varargin) > 1
        warning('optimizeScheduleCollection:UnusedArgs', ...
            'Additional arguments ignored because an options object was supplied.');
    end
else
    optOptions = conduction.batch.OptimizationOptions(varargin{:});
end

optimizer = conduction.batch.Optimizer(optOptions);
batchResult = optimizer.run(collection);
end
