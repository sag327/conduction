classdef StatsHelper
    %STATSHELPER Statistical utilities for analytics aggregators.

    methods (Static)
        function stats = summarize(values)
            values = values(:);
            values = values(~isnan(values));
            if isempty(values)
                stats = struct('count', 0, 'mean', NaN, 'median', NaN, 'p70', NaN, 'p90', NaN);
                return;
            end

            stats = struct();
            stats.count = numel(values);
            stats.mean = mean(values);
            stats.median = median(values);
            stats.p70 = prctile(values, 70);
            stats.p90 = prctile(values, 90);
        end
    end
end
