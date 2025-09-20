classdef OptimizationResult
    %OPTIMIZATIONRESULT Stores per-day optimization outputs.

    properties (SetAccess = immutable)
        OriginalSchedule conduction.DailySchedule
        OptimizedSchedule conduction.DailySchedule
        Outcome struct
    end

    properties (SetAccess = private)
        Metadata struct
    end

    methods
        function obj = OptimizationResult(originalSchedule, optimizedSchedule, outcome)
            obj.OriginalSchedule = originalSchedule;
            obj.OptimizedSchedule = optimizedSchedule;
            obj.Outcome = outcome;
            obj.Metadata = struct();
        end

        function obj = withMetadata(obj, metadata)
            obj.Metadata = metadata;
        end
    end
end
