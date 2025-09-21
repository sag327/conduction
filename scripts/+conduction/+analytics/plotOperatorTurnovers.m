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
dailyResults = summary.dailyResults;

opStruct = struct('id', {}, 'name', {}, 'idleMedian', {}, 'flipMedian', {});

for idx = 1:numel(operatorIds)
    opId = operatorIds{idx};

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

    if isempty(flips) && isempty(idles)
        continue;
    end

    entry = struct();
    entry.id = opId;
    entry.name = summary.operatorSummary.operatorNames(opId);
    entry.idleMedian = median(idles, 'omitnan');
    entry.flipMedian = median(flips, 'omitnan');

    opStruct(end+1) = entry; %#ok<AGROW>
end

if isempty(opStruct)
    warning('plotOperatorTurnovers:NoData', 'No operator turnover data available to plot.');
    return;
end

rawOperatorNames = {opStruct.name};
labels = conduction.plotting.formatOperatorNames(rawOperatorNames);
idleMedians = [opStruct.idleMedian];
flipMedians = [opStruct.flipMedian];

figure('Name', 'Operator Turnover Metrics', 'Color', 'w');
subplot(2,1,1);
idleBars = bar(categorical(labels), idleMedians);
ylabel('Median idle minutes per turnover');
title('Operator Idle per Turnover (Median)');

ylimitIdle = ylim;
ylim([0, ylimitIdle(2)]);

ytickformat('%.1f');
idleXTicks = idleBars.XEndPoints;
idleYTicks = idleBars.YEndPoints;
idleLabels = arrayfun(@(v) sprintf('%.1f', v), idleMedians, 'UniformOutput', false);
text(idleXTicks, idleYTicks, idleLabels, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

subplot(2,1,2);
flipValuesPercent = 100 * flipMedians;
flipBars = bar(categorical(labels), flipValuesPercent);
ylabel('Median flip per turnover (%)');
xlabel('Operator');
title('Operator Flip per Turnover (Median)');

ylim([0, 100]);
ytickformat('%.0f');
flipXTicks = flipBars.XEndPoints;
flipYTicks = flipBars.YEndPoints;
flipLabels = arrayfun(@(v) sprintf('%.0f%%', v), flipValuesPercent, 'UniformOutput', false);
text(flipXTicks, flipYTicks, flipLabels, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

conduction.plotting.applyStandardStyle(gcf);

end
