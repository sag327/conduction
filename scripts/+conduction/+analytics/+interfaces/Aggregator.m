classdef (Abstract) Aggregator < handle
    %AGGREGATOR Base interface for analytics aggregators.

    methods (Abstract)
        accumulate(obj, dailyResult)
        summary = summarize(obj)
    end

    methods
        function reset(obj) %#ok<INUSD>
            % Optional reset; override where needed.
        end
    end
end
