classdef OptimizationOptions
    %OPTIMIZATIONOPTIONS Batch optimization configuration wrapper.

    properties (SetAccess = immutable)
        SchedulingOptions (1,1) conduction.scheduling.SchedulingOptions
        DateFilter function_handle = @(dt) true
        Parallel logical = false
        PreserveResults logical = false
        ShowProgress logical = true
    end

    methods (Static)
        function obj = fromArgs(varargin)
            parser = inputParser;
            defaultScheduling = conduction.scheduling.SchedulingOptions.fromArgs();
            addParameter(parser, 'SchedulingOptions', defaultScheduling, ...
                @(x) isa(x, 'conduction.scheduling.SchedulingOptions'));
            addParameter(parser, 'SchedulingConfig', struct(), @(x) isstruct(x));
            addParameter(parser, 'DateFilter', @(dt) true, @(f) isa(f, 'function_handle'));
            addParameter(parser, 'Parallel', false, @islogical);
            addParameter(parser, 'PreserveResults', false, @islogical);
            addParameter(parser, 'ShowProgress', true, @islogical);
            parse(parser, varargin{:});
            results = parser.Results;
            if ~isempty(fieldnames(results.SchedulingConfig))
                configPairs = conduction.batch.OptimizationOptions.structToPairs(results.SchedulingConfig);
                results.SchedulingOptions = conduction.scheduling.SchedulingOptions.fromArgs(configPairs{:});
            end
            if isfield(results, 'SchedulingConfig')
                results = rmfield(results, 'SchedulingConfig');
            end
            obj = conduction.batch.OptimizationOptions(results);
        end
    end

    methods
        function obj = OptimizationOptions(args)
            if nargin == 0
                args = struct();
            end
            if ~isfield(args, 'SchedulingOptions')
                args.SchedulingOptions = conduction.scheduling.SchedulingOptions.fromArgs();
            end
            if ~isfield(args, 'DateFilter'); args.DateFilter = @(dt) true; end
            if ~isfield(args, 'Parallel'); args.Parallel = false; end
            if ~isfield(args, 'PreserveResults'); args.PreserveResults = false; end
            if ~isfield(args, 'ShowProgress'); args.ShowProgress = true; end
            obj.SchedulingOptions = args.SchedulingOptions;
            obj.DateFilter = args.DateFilter;
            obj.Parallel = args.Parallel;
            obj.PreserveResults = args.PreserveResults;
            obj.ShowProgress = args.ShowProgress;
        end
    end

    methods (Static, Access = private)
        function pairs = structToPairs(configStruct)
            fields = fieldnames(configStruct);
            pairs = cell(1, numel(fields)*2);
            for idx = 1:numel(fields)
                pairs{2*idx-1} = fields{idx};
                pairs{2*idx} = configStruct.(fields{idx});
            end
        end
    end
end
