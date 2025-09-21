function plotOperatorTurnovers(summary)
%PLOTOPERATORTURNOVERS Visualize operator flip/idle ratios from analyzed data.
%   PLOTOPERATORTURNOVERS(summary) expects the struct returned by
%   conduction.analytics.analyzeScheduleCollection (must contain
%   operatorSummary and dailyResults). The function produces bar charts for
%   median idle-per-turnover and median flip-per-turnover per operator.

if ~(isstruct(summary) && isfield(summary, 'operatorSummary') && ...
        isfield(summary, 'dailyResults'))
    error('plotOperatorTurnovers:InvalidInput', ...
        'Provide the summary struct returned by analyzeScheduleCollection.');
end

operatorIds = summary.operatorSummary.operatorNames.keys;
numOps = numel(operatorIds);

flipMedians = zeros(numOps, 1);
idleMedians = zeros(numOps, 1);
rawOperatorNames = cell(numOps, 1);

dailyResults = summary.dailyResults;

for idx = 1:numOps
    opId = operatorIds{idx};
    rawOperatorNames{idx} = summary.operatorSummary.operatorNames(opId);

    flips = [];
    idles = [];

    for dayIdx = 1:numel(dailyResults)
        dayMetrics = dailyResults{dayIdx}.operatorMetrics;
        if dayMetrics.flipPerTurnoverRatio.isKey(opId)
            flips(end+1) = dayMetrics.flipPerTurnoverRatio(opId); %#ok<AGROW>
        end
        if dayMetrics.idlePerTurnoverRatio.isKey(opId)
            idles(end+1) = dayMetrics.idlePerTurnoverRatio(opId); %#ok<AGROW>
        end
    end

    flipMedians(idx) = median(flips, 'omitnan');
    idleMedians(idx) = median(idles, 'omitnan');
end

labels = conduction.plotting.formatOperatorNames(rawOperatorNames);

figure('Name', 'Operator Turnover Metrics', 'Color', 'w');
subplot(2,1,1);
bar(categorical(labels), idleMedians);
ylabel('Median idle minutes per turnover');
title('Operator Idle per Turnover (Median)');

ylimitIdle = ylim;
ylim([0, ylimitIdle(2)]);

ytickformat('%.1f');

subplot(2,1,2);
bar(categorical(labels), 100 * flipMedians);
ylabel('Median flip per turnover (%)');
xlabel('Operator');
title('Operator Flip per Turnover (Median)');

ylim([0, 100]);
ytickformat('%.0f');

conduction.plotting.applyStandardStyle(gcf);

end
