function plotOperatorTurnovers(summary, varargin)
%PLOTOPERATORTURNOVERS Plot operator idle/flip turnover metrics.
%   PLOTOPERATORTURNOVERS(summary) expects the struct returned by
%   conduction.analytics.analyzeScheduleCollection and plots the median
%   idle minutes per turnover and median flip percentage per turnover for
%   each operator. Pass 'Mode','aggregate' to plot the aggregate totals
%   (total idle minutes ÷ total turnovers, and total flips ÷ total turnovers).

p = inputParser;
p.addParameter('Mode', 'median', @(x) any(strcmpi(x, {'median','aggregate'})));
p.parse(varargin{:});
mode = lower(string(p.Results.Mode));

hasDailyResults = isstruct(summary) && isfield(summary, 'dailyResults');
if ~(isstruct(summary) && isfield(summary, 'operatorSummary') && ...
        (strcmp(mode, "aggregate") || hasDailyResults))
    error('plotOperatorTurnovers:InvalidInput', ...
        'Provide the summary struct returned by analyzeScheduleCollection.');
end

operatorIds = summary.operatorSummary.operatorNames.keys;
opStruct = struct('name', {}, 'idleValue', {}, 'flipValue', {});

switch mode
    case "aggregate"
        idleMap = summary.operatorSummary.operatorTotalIdleMinutesPerTurnover;
        flipMap = summary.operatorSummary.operatorFlipPerTurnoverRatio;
        namesMap = summary.operatorSummary.operatorNames;

        for idx = 1:numel(operatorIds)
            opId = operatorIds{idx};
        hasIdle = idleMap.isKey(opId) && ~isnan(idleMap(opId));
        hasFlip = flipMap.isKey(opId) && ~isnan(flipMap(opId));
            if ~(hasIdle || hasFlip)
                continue;
            end

            entry = struct();
        entry.name = namesMap(opId);
        if hasIdle
            entry.idleValue = idleMap(opId);
        else
            entry.idleValue = NaN;
        end
        if hasFlip
            entry.flipValue = flipMap(opId);
        else
            entry.flipValue = NaN;
        end
            opStruct(end+1) = entry; %#ok<AGROW>
        end

    otherwise % "median"
        dailyResults = summary.dailyResults;
        namesMap = summary.operatorSummary.operatorNames;

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
            entry.name = namesMap(opId);
            entry.idleValue = median(idles, 'omitnan');
            entry.flipValue = median(flips, 'omitnan');
            opStruct(end+1) = entry; %#ok<AGROW>
        end
end

if isempty(opStruct)
    warning('plotOperatorTurnovers:NoData', ...
        'No operator turnover data available to plot.');
    return;
end

rawNames = {opStruct.name};
labels = conduction.plotting.formatOperatorNames(rawNames);
idleValues = [opStruct.idleValue];
flipValues = [opStruct.flipValue];

figure('Name', 'Operator Turnover Metrics', 'Color', 'w');
subplot(2,1,1);
idleBars = bar(categorical(labels), idleValues);
ylabel('Idle minutes per turnover');
if mode == "median"
    title('Operator Idle per Turnover (Median)');
else
    title('Operator Idle per Turnover (Aggregate)');
end

ylimitIdle = ylim;
ylim([0, ylimitIdle(2)]);

ytickformat('%.1f');
text(idleBars.XEndPoints, idleBars.YEndPoints, ...
    arrayfun(@(v) sprintf('%.1f', v), idleValues, 'UniformOutput', false), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

subplot(2,1,2);
flipPercent = 100 * flipValues;
flipBars = bar(categorical(labels), flipPercent);
ylabel('Flip per turnover (%)');
xlabel('Operator');
if mode == "median"
    title('Operator Flip per Turnover (Median)');
else
    title('Operator Flip per Turnover (Aggregate)');
end

ylim([0, 100]);
ytickformat('%.0f');
text(flipBars.XEndPoints, flipBars.YEndPoints, ...
    arrayfun(@(v) sprintf('%.0f%%', v), flipPercent, 'UniformOutput', false), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

conduction.plotting.applyStandardStyle(gcf);

end
