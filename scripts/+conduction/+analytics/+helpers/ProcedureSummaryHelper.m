classdef ProcedureSummaryHelper
    %PROCEDURESUMMARYHELPER Convenience conversions for procedure maps.

    methods (Static)
        function summaryList = summarizeDaily(procedureMap)
            if isempty(procedureMap)
                summaryList = struct('procedureId', {}, 'procedureName', {}, 'count', {}, 'meanMinutes', {}, 'medianMinutes', {});
                return;
            end

            keys = procedureMap.keys;
            summaryList = repmat(struct('procedureId', "", 'procedureName', "", 'count', 0, 'meanMinutes', NaN, 'medianMinutes', NaN), numel(keys), 1);
            for idx = 1:numel(keys)
                key = keys{idx};
                entry = procedureMap(key);
                stats = conduction.analytics.helpers.StatsHelper.summarize(entry.Samples.procedureMinutes);
                summaryList(idx).procedureId = entry.ProcedureId;
                summaryList(idx).procedureName = entry.ProcedureName;
                summaryList(idx).count = stats.count;
                summaryList(idx).meanMinutes = stats.mean;
                summaryList(idx).medianMinutes = stats.median;
            end
        end
    end
end
