function plotOperatorTurnovers(summary, varargin)
%PLOTOPERATORTURNOVERS Plot operator idle/flip turnover metrics.
%   plotOperatorTurnovers(summary) expects the struct returned by
%   conduction.analytics.analyzeScheduleCollection and plots the aggregate
%   idle minutes per turnover and aggregate flip percentage per turnover
%   for each operator.  Pass 'Mode','median' to instead plot the medians of
%   the per-day ratios.
%
%   Example:
%       summary = conduction.analytics.analyzeScheduleCollection(collection);
%       conduction.analytics.plotOperatorTurnovers(summary);
%       conduction.analytics.plotOperatorTurnovers(summary, 'Mode', 'median');

p = inputParser;
p.addParameter('Mode', 'aggregate', @(x) any(strcmpi(x, {'median','aggregate'})));
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

fig = figure('Name', 'Operator Turnover Metrics', 'Color', 'w');
subplot(2,1,1);
idBars = bar(categorical(labels), idleValues);
ylabel('Idle minutes per turnover');
if mode == "median"
    title('Operator Idle per Turnover (Median)');
else
    title('Operator Idle per Turnover (Aggregate)');
end

maxIdle = max(idleValues, [], 'omitnan');
if isempty(maxIdle) || isnan(maxIdle)
    maxIdle = 1;
end
ylim([0, maxIdle * 1.1]);
ytickformat('%.1f');
annotateBars(idBars, idleValues, '%.1f');

subplot(2,1,2);
flipPercent = 100 * flipValues;
flipBars = bar(categorical(labels), flipPercent);
ylabel('Flip per turnover (%)');
xlabel('');
if mode == "median"
    title('Operator Flip per Turnover (Median)');
else
    title('Operator Flip per Turnover (Aggregate)');
end

maxFlip = max(flipPercent, [], 'omitnan');
if isempty(maxFlip) || isnan(maxFlip)
    maxFlip = 1;
end
ylim([0, max(100, maxFlip * 1.1)]);
ytickformat('%.0f');
annotateBars(flipBars, flipPercent, '%.0f%%');

conduction.plotting.applyStandardStyle(fig);
attachVersionAnnotation(fig);
end

function annotateBars(barSeries, values, fmt)
labels = arrayfun(@(v) formatNumericLabel(v, fmt), values, 'UniformOutput', false);
text(barSeries.XEndPoints, barSeries.YEndPoints, labels, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

function label = formatNumericLabel(value, fmt)
if isnan(value)
    label = '';
else
    label = sprintf(fmt, value);
end
end

function attachVersionAnnotation(fig)
info = conduction.version();
commitLabel = abbreviate(info.Commit);
dirtyMark = ternary(info.Dirty, '*', '');
label = sprintf('conduction %s (%s%s)', info.Version, commitLabel, dirtyMark);
annotation(fig, 'textbox', [0.0 0.0 0.99 0.03], ...
    'String', label, 'HorizontalAlignment', 'right', ...
    'EdgeColor', 'none', 'Interpreter', 'none', 'FontSize', 8);
userData = get(fig, 'UserData');
if ~isstruct(userData)
    userData = struct();
end
userData.conductionVersion = info;
set(fig, 'UserData', userData);
end

function out = abbreviate(commit)
if isempty(commit) || strcmpi(commit, 'unknown')
    out = 'unknown';
else
    chars = char(commit);
    out = chars(1:min(numel(chars), 7));
end
end

function out = ternary(condition, ifTrue, ifFalse)
if condition
    out = ifTrue;
else
    out = ifFalse;
end
end
