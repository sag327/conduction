classdef SchedulingOptions
    %SCHEDULINGOPTIONS Configuration for historical scheduling optimization.
    %   Encapsulates all tunable parameters passed to the ILP scheduler so we
    %   can validate inputs once and share them across the pipeline.

    properties (SetAccess = immutable)
        NumLabs (1,1) double {mustBePositive, mustBeFinite} = 5
        LabStartTimes cell = {}
        LabEarliestStartMinutes double = double.empty(1, 0)
        OptimizationMetric (1,1) string = "operatorIdle"
        CaseFilter (1,1) string = "all"
        MaxOperatorTime (1,1) double {mustBePositive, mustBeFinite} = 480
        TurnoverTime (1,1) double {mustBeNonnegative, mustBeFinite} = 15
        EnforceMidnight (1,1) logical = true
        PrioritizeOutpatient (1,1) logical = true
        OperatorAvailability containers.Map = containers.Map('KeyType','char','ValueType','double')
        LockedCaseConstraints struct = struct([])  % Locked case time windows and assignments
        AvailableLabs double = double.empty(1, 0)
        Verbose (1,1) logical = true
        TimeStep (1,1) double {mustBePositive, mustBeFinite} = 10
        ResourceTypes struct = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {})
        OutpatientInpatientMode string {mustBeMember(OutpatientInpatientMode, ["TwoPhaseStrict", "TwoPhaseAutoFallback", "SinglePhaseFlexible"])} = "TwoPhaseAutoFallback"
    end

    properties (Constant, Access = private)
        DEFAULT_NUM_LABS = 5;
        DEFAULT_LAB_START = "08:00";
        DEFAULT_OPTIMIZATION = "operatorIdle";
        DEFAULT_CASE_FILTER = "all";
        DEFAULT_MAX_OPERATOR_TIME = 480;   % minutes
        DEFAULT_TURNOVER_TIME = 15;        % minutes
        DEFAULT_ENFORCE_MIDNIGHT = true;
        DEFAULT_PRIORITIZE_OUTPATIENT = true;
        DEFAULT_VERBOSE = false;
        DEFAULT_TIME_STEP = 10;            % minutes
        DEFAULT_OUTPATIENT_INPATIENT_MODE = "TwoPhaseAutoFallback";

        VALID_METRICS = ["operatorIdle", "labIdle", "makespan", "operatorOvertime"];
        VALID_CASE_FILTERS = ["all", "outpatient", "inpatient"];
        VALID_OUTPATIENT_INPATIENT_MODES = ["TwoPhaseStrict", "TwoPhaseAutoFallback", "SinglePhaseFlexible"];
    end

    methods (Static)
        function obj = fromArgs(varargin)
            %FROMARGS Build options from name/value pairs or struct input.
            if nargin == 1 && isstruct(varargin{1})
                params = conduction.scheduling.SchedulingOptions.structToPairs(varargin{1});
            else
                params = varargin;
            end

            parser = inputParser;
            parser.FunctionName = 'SchedulingOptions';

            addParameter(parser, 'NumLabs', conduction.scheduling.SchedulingOptions.DEFAULT_NUM_LABS, ...
                @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
            addParameter(parser, 'LabStartTimes', {}, @(x) iscell(x) || isstring(x) || ischar(x));
            addParameter(parser, 'LabEarliestStartMinutes', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
            addParameter(parser, 'OptimizationMetric', conduction.scheduling.SchedulingOptions.DEFAULT_OPTIMIZATION, ...
                @(x) any(strcmpi(string(x), conduction.scheduling.SchedulingOptions.VALID_METRICS)));
            addParameter(parser, 'CaseFilter', conduction.scheduling.SchedulingOptions.DEFAULT_CASE_FILTER, ...
                @(x) any(strcmpi(string(x), conduction.scheduling.SchedulingOptions.VALID_CASE_FILTERS)));
            addParameter(parser, 'MaxOperatorTime', conduction.scheduling.SchedulingOptions.DEFAULT_MAX_OPERATOR_TIME, ...
                @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
            addParameter(parser, 'TurnoverTime', conduction.scheduling.SchedulingOptions.DEFAULT_TURNOVER_TIME, ...
                @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative'}));
            addParameter(parser, 'EnforceMidnight', conduction.scheduling.SchedulingOptions.DEFAULT_ENFORCE_MIDNIGHT, @islogical);
            addParameter(parser, 'PrioritizeOutpatient', conduction.scheduling.SchedulingOptions.DEFAULT_PRIORITIZE_OUTPATIENT, @islogical);
            addParameter(parser, 'OperatorAvailability', containers.Map('KeyType','char','ValueType','double'), ...
                @(x) isa(x, 'containers.Map'));
            addParameter(parser, 'LockedCaseConstraints', struct([]), @isstruct);
            addParameter(parser, 'AvailableLabs', [], @(x) isnumeric(x) && isvector(x));
            addParameter(parser, 'Verbose', conduction.scheduling.SchedulingOptions.DEFAULT_VERBOSE, @islogical);
            addParameter(parser, 'TimeStep', conduction.scheduling.SchedulingOptions.DEFAULT_TIME_STEP, ...
                @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
            addParameter(parser, 'ResourceTypes', struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {}), ...
                @(x) isempty(x) || isstruct(x));
            addParameter(parser, 'OutpatientInpatientMode', conduction.scheduling.SchedulingOptions.DEFAULT_OUTPATIENT_INPATIENT_MODE, ...
                @(x) isstring(x) || ischar(x));

            parse(parser, params{:});
            results = parser.Results;

            obj = conduction.scheduling.SchedulingOptions( ...
                results.NumLabs, ...
                results.LabStartTimes, ...
                results.OptimizationMetric, ...
                results.CaseFilter, ...
                results.MaxOperatorTime, ...
                results.TurnoverTime, ...
                results.EnforceMidnight, ...
                results.PrioritizeOutpatient, ...
                results.OperatorAvailability, ...
                results.LockedCaseConstraints, ...
                results.AvailableLabs, ...
                results.Verbose, ...
                results.TimeStep, ...
                results.ResourceTypes, ...
                results.OutpatientInpatientMode, ...
                results.LabEarliestStartMinutes);
        end
    end

    methods
        function obj = SchedulingOptions(numLabs, labStartTimes, optimizationMetric, caseFilter, ...
                maxOperatorTime, turnoverTime, enforceMidnight, prioritizeOutpatient, operatorAvailability, ...
                lockedCaseConstraints, availableLabs, verbose, timeStep, resourceTypes, outpatientInpatientMode, labEarliestStartMinutes)

            if nargin == 0
                numLabs = conduction.scheduling.SchedulingOptions.DEFAULT_NUM_LABS;
                labStartTimes = {};
                optimizationMetric = conduction.scheduling.SchedulingOptions.DEFAULT_OPTIMIZATION;
                caseFilter = conduction.scheduling.SchedulingOptions.DEFAULT_CASE_FILTER;
                maxOperatorTime = conduction.scheduling.SchedulingOptions.DEFAULT_MAX_OPERATOR_TIME;
                turnoverTime = conduction.scheduling.SchedulingOptions.DEFAULT_TURNOVER_TIME;
                enforceMidnight = conduction.scheduling.SchedulingOptions.DEFAULT_ENFORCE_MIDNIGHT;
                prioritizeOutpatient = conduction.scheduling.SchedulingOptions.DEFAULT_PRIORITIZE_OUTPATIENT;
                operatorAvailability = containers.Map('KeyType','char','ValueType','double');
                lockedCaseConstraints = struct([]);
                availableLabs = [];
                verbose = conduction.scheduling.SchedulingOptions.DEFAULT_VERBOSE;
                timeStep = conduction.scheduling.SchedulingOptions.DEFAULT_TIME_STEP;
                resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
                outpatientInpatientMode = conduction.scheduling.SchedulingOptions.DEFAULT_OUTPATIENT_INPATIENT_MODE;
            elseif nargin < 14
                resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
                outpatientInpatientMode = conduction.scheduling.SchedulingOptions.DEFAULT_OUTPATIENT_INPATIENT_MODE;
            elseif nargin < 15
                outpatientInpatientMode = conduction.scheduling.SchedulingOptions.DEFAULT_OUTPATIENT_INPATIENT_MODE;
                labEarliestStartMinutes = [];
            elseif nargin < 16
                labEarliestStartMinutes = [];
            end

            if isempty(labStartTimes)
                defaultStart = repmat(conduction.scheduling.SchedulingOptions.DEFAULT_LAB_START, 1, numLabs);
                labStartTimes = cellstr(defaultStart);
            elseif isstring(labStartTimes) || ischar(labStartTimes)
                labStartTimes = cellstr(labStartTimes);
            end

            if numel(labStartTimes) ~= numLabs
                error('SchedulingOptions:InvalidInput', ...
                    'Number of lab start times (%d) must equal NumLabs (%d).', numel(labStartTimes), numLabs);
            end

            obj.NumLabs = numLabs;
            obj.LabStartTimes = labStartTimes(:)';
            obj.OptimizationMetric = conduction.scheduling.SchedulingOptions.normalizeMetric(optimizationMetric);
            obj.CaseFilter = conduction.scheduling.SchedulingOptions.normalizeCaseFilter(caseFilter);
            obj.MaxOperatorTime = maxOperatorTime;
            obj.TurnoverTime = turnoverTime;
            obj.EnforceMidnight = enforceMidnight;
            obj.PrioritizeOutpatient = prioritizeOutpatient;
            obj.OperatorAvailability = operatorAvailability;
            obj.LockedCaseConstraints = lockedCaseConstraints;
            obj.AvailableLabs = conduction.scheduling.SchedulingOptions.normalizeAvailableLabs(availableLabs, numLabs);
            obj.Verbose = verbose;
            obj.TimeStep = timeStep;
            obj.ResourceTypes = conduction.scheduling.SchedulingOptions.normalizeResourceTypes(resourceTypes);
            obj.OutpatientInpatientMode = conduction.scheduling.SchedulingOptions.normalizeOutpatientInpatientMode(outpatientInpatientMode);

            % Normalize LabEarliestStartMinutes
            if isempty(labEarliestStartMinutes)
                obj.LabEarliestStartMinutes = double.empty(1, 0);
            else
                v = double(labEarliestStartMinutes(:)');
                if numel(v) ~= numLabs
                    error('SchedulingOptions:InvalidInput', ...
                        'LabEarliestStartMinutes length (%d) must equal NumLabs (%d).', numel(v), numLabs);
                end
                obj.LabEarliestStartMinutes = max(0, v);
            end
        end

        function metric = normalizedMetric(obj)
            metric = obj.OptimizationMetric;
        end

        function tf = isTwoPhaseEnabled(obj)
            % Two-phase is enabled based on OutpatientInpatientMode setting
            % OutpatientInpatientMode takes precedence over legacy PrioritizeOutpatient

            % If explicit mode is SinglePhaseFlexible, use single-phase
            if obj.OutpatientInpatientMode == "SinglePhaseFlexible"
                tf = false;
                return;
            end

            % If explicit mode is TwoPhaseStrict or TwoPhaseAutoFallback, use two-phase
            if obj.OutpatientInpatientMode == "TwoPhaseStrict" || ...
               obj.OutpatientInpatientMode == "TwoPhaseAutoFallback"
                tf = obj.CaseFilter ~= "inpatient";
                return;
            end

            % Legacy fallback: use PrioritizeOutpatient checkbox (for backward compatibility)
            tf = obj.PrioritizeOutpatient && obj.CaseFilter ~= "inpatient";
        end

        function s = toStruct(obj)
            s = struct( ...
                'NumLabs', obj.NumLabs, ...
                'LabStartTimes', {obj.LabStartTimes}, ...
                'LabEarliestStartMinutes', obj.LabEarliestStartMinutes, ...
                'OptimizationMetric', obj.OptimizationMetric, ...
                'CaseFilter', obj.CaseFilter, ...
                'MaxOperatorTime', obj.MaxOperatorTime, ...
                'TurnoverTime', obj.TurnoverTime, ...
                'EnforceMidnight', obj.EnforceMidnight, ...
                'PrioritizeOutpatient', obj.PrioritizeOutpatient, ...
                'OperatorAvailability', obj.OperatorAvailability, ...
                'LockedCaseConstraints', obj.LockedCaseConstraints, ...
                'AvailableLabs', obj.AvailableLabs, ...
                'Verbose', obj.Verbose, ...
                'TimeStep', obj.TimeStep, ...
                'ResourceTypes', obj.ResourceTypes, ...
                'OutpatientInpatientMode', obj.OutpatientInpatientMode);
        end

        function newObj = with(obj, varargin)
            overrides = conduction.scheduling.SchedulingOptions.structToPairs(obj.toStruct());
            overrides = conduction.scheduling.SchedulingOptions.applyOverrides(overrides, varargin{:});
            newObj = conduction.scheduling.SchedulingOptions.fromArgs(overrides{:});
        end
    end

    methods (Static, Access = private)
        function s = structToPairs(inputStruct)
            fields = fieldnames(inputStruct);
            s = cell(1, numel(fields) * 2);
            for idx = 1:numel(fields)
                s{2*idx-1} = fields{idx};
                s{2*idx} = inputStruct.(fields{idx});
            end
        end

        function metric = normalizeMetric(value)
            cand = string(value);
            matches = strcmpi(cand, conduction.scheduling.SchedulingOptions.VALID_METRICS);
            if ~any(matches)
                error('SchedulingOptions:InvalidMetric', ...
                    'Unsupported optimization metric: %s', cand);
            end
            metric = conduction.scheduling.SchedulingOptions.VALID_METRICS(matches);
        end

        function filter = normalizeCaseFilter(value)
            cand = string(value);
            matches = strcmpi(cand, conduction.scheduling.SchedulingOptions.VALID_CASE_FILTERS);
            if ~any(matches)
                error('SchedulingOptions:InvalidCaseFilter', ...
                    'Unsupported case filter: %s', cand);
            end
            filter = conduction.scheduling.SchedulingOptions.VALID_CASE_FILTERS(matches);
        end

        function resources = normalizeResourceTypes(candidate)
            base = struct('Id', "", 'Name', "", 'Capacity', 0, 'Color', [0.5 0.5 0.5]);

            if nargin == 0 || isempty(candidate)
                resources = repmat(base, 0, 1);
                return;
            end

            if ~isstruct(candidate)
                error('SchedulingOptions:InvalidResourceTypes', ...
                    'ResourceTypes must be provided as a struct array.');
            end

            resources = repmat(base, 1, numel(candidate));
            for idx = 1:numel(candidate)
                entry = candidate(idx);

                if ~isfield(entry, 'Id') || isempty(entry.Id)
                    error('SchedulingOptions:InvalidResourceTypes', ...
                        'Each resource entry must include an Id field.');
                end
                resources(idx).Id = string(entry.Id);

                if isfield(entry, 'Name') && ~isempty(entry.Name)
                    resources(idx).Name = string(entry.Name);
                else
                    resources(idx).Name = resources(idx).Id;
                end

                if isfield(entry, 'Capacity') && ~isempty(entry.Capacity)
                    capacityValue = double(entry.Capacity);
                else
                    capacityValue = 0;
                end
                if ~isfinite(capacityValue) || capacityValue < 0
                    error('SchedulingOptions:InvalidResourceCapacity', ...
                        'Resource capacity must be a finite, nonnegative value.');
                end
                resources(idx).Capacity = capacityValue;

                if isfield(entry, 'Color') && ~isempty(entry.Color)
                    colorValue = double(entry.Color(:)');
                    if numel(colorValue) ~= 3 || any(~isfinite(colorValue))
                        error('SchedulingOptions:InvalidResourceColor', ...
                            'Resource color must be a finite 1x3 RGB array.');
                    end
                    resources(idx).Color = colorValue;
                else
                    resources(idx).Color = base.Color;
                end
            end
        end

        function labs = normalizeAvailableLabs(candidate, numLabs)
            if isempty(candidate)
                labs = 1:numLabs;
                return;
            end

            labs = unique(double(candidate(:)'));
            if any(~isfinite(labs)) || any(labs < 1) || any(labs > numLabs)
                error('SchedulingOptions:InvalidAvailableLabs', ...
                    'Available labs must be integers between 1 and %d.', numLabs);
            end
        end

        function mode = normalizeOutpatientInpatientMode(candidate)
            mode = string(candidate);
            validModes = conduction.scheduling.SchedulingOptions.VALID_OUTPATIENT_INPATIENT_MODES;
            if ~any(mode == validModes)
                error('SchedulingOptions:InvalidOutpatientInpatientMode', ...
                    'OutpatientInpatientMode must be one of: %s', strjoin(validModes, ', '));
            end
        end

        function pairs = applyOverrides(pairs, varargin)
            if isempty(varargin)
                return;
            end

            baseStruct = conduction.scheduling.SchedulingOptions.pairsToStruct(pairs);

            if numel(varargin) == 1 && isstruct(varargin{1})
                overrideStruct = varargin{1};
                overrideFields = fieldnames(overrideStruct);
                for idx = 1:numel(overrideFields)
                    fieldName = overrideFields{idx};
                    baseStruct.(fieldName) = overrideStruct.(fieldName);
                end
            else
                if mod(numel(varargin), 2) ~= 0
                    error('SchedulingOptions:InvalidOverride', ...
                        'Overrides must be provided as name/value pairs.');
                end
                for idx = 1:2:numel(varargin)
                    fieldName = varargin{idx};
                    if ~ischar(fieldName) && ~isstring(fieldName)
                        error('SchedulingOptions:InvalidOverrideKey', ...
                            'Override names must be strings.');
                    end
                    baseStruct.(char(fieldName)) = varargin{idx+1};
                end
            end

            pairs = conduction.scheduling.SchedulingOptions.structToPairs(baseStruct);
        end

        function s = pairsToStruct(pairs)
            names = pairs(1:2:end);
            values = pairs(2:2:end);
            s = struct();
            for idx = 1:numel(names)
                s.(char(names{idx})) = values{idx};
            end
        end
    end
end
