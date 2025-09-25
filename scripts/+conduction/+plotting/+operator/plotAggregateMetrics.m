function fig = plotAggregateMetrics(summary, varargin)
%PLOTAGGREGATEMETRICS Visualise per-operator aggregate metrics.
%   fig = conduction.plotting.operator.plotAggregateMetrics(summary) produces
%   bar charts for idle-per-turnover and flip-per-turnover using the summary
%   struct returned by conduction.analytics.analyzeScheduleCollection.
%
%   Optional name/value pairs:
%       'Metrics' - cell array selecting metrics to display. Supported values:
%                   'IdlePerTurnover' (default)
%                   'FlipPerTurnover' (default)
%                   'TotalIdleMinutes'
%                   'OvertimeMinutes'
%       'Mode'    - 'aggregate' (default) or 'median'. Median mode computes the
%                   median per day for each operator when dailyResults data is
%                   available. Mode applies only to idle/flip metrics.
%
%   The function returns a figure handle. The figure is styled using
%   conduction.plotting.utils.applyStandardStyle and annotated with
%   conduction.plotting.utils.attachVersionAnnotation.

parser = inputParser;
addParameter(parser, 'Metrics', {'IdlePerTurnover','FlipPerTurnover'}, @(x) ischar(x) || isstring(x) || iscell(x));
addParameter(parser, 'Mode', 'aggregate', @(x) any(strcmpi(string(x), {'aggregate','median'})));
parse(parser, varargin{:});

metrics = cellstr(parser.Results.Metrics);
if isempty(metrics)
    metrics = {'IdlePerTurnover','FlipPerTurnover'};
end
mode = lower(string(parser.Results.Mode));

fig = figure('Name', 'Operator Aggregate Metrics', 'Color', 'w');
tl = tiledlayout(fig, numel(metrics), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axList = gobjects(numel(metrics), 1);

for idx = 1:numel(metrics)
    metricName = string(lower(metrics{idx}));
    ax = nexttile(tl);
    axList(idx) = ax;
    switch metricName
        case 'idleperturnover'
            data = operatorRatioValues(summary, 'idle', mode);
            ylabel(ax, 'Idle minutes per turnover');
            title(ax, titleForMode('Idle per Turnover', mode));
            fmt = '%.1f';
        case 'flipperturnover'
            data = operatorRatioValues(summary, 'flip', mode);
            data.values = 100 * data.values;
            ylabel(ax, 'Flip per turnover (%)');
            title(ax, titleForMode('Flip per Turnover', mode));
            fmt = '%.0f%%';
        case 'totalidleminutes'
            data = operatorMapValues(summary.operatorSummary.operatorIdleMinutes, summary.operatorSummary.operatorNames);
            ylabel(ax, 'Total idle minutes');
            title(ax, 'Operator Total Idle Minutes');
            fmt = '%.0f';
        case 'overtimeminutes'
            data = operatorMapValues(summary.operatorSummary.operatorOvertimeMinutes, summary.operatorSummary.operatorNames);
            ylabel(ax, 'Total overtime minutes');
            title(ax, 'Operator Total Overtime Minutes');
            fmt = '%.0f';
        otherwise
            delete(ax);
            error('plotAggregateMetrics:UnsupportedMetric', ...
                'Unsupported metric selection: %s', metrics{idx});
    end

    if isempty(data.values)
        text(ax, 0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        continue;
    end

    bar(ax, categorical(data.labels), data.values);
    annotateBars(ax, data.values, fmt);
    grid(ax, 'on');
end

conduction.plotting.utils.applyStandardStyle(fig, axList(isgraphics(axList)));
conduction.plotting.utils.attachVersionAnnotation(fig);
end

% -------------------------------------------------------------------------
function data = operatorRatioValues(summary, kind, mode)
if strcmp(mode, "median") && ~isfield(summary, 'dailyResults')
    error('plotAggregateMetrics:MedianUnavailable', ...
        'Median mode requires dailyResults data in the collection summary.');
end

switch lower(kind)
    case 'idle'
        mapField = 'operatorTotalIdleMinutesPerTurnover';
        dailyField = 'idlePerTurnoverRatio';
    case 'flip'
        mapField = 'operatorFlipPerTurnoverRatio';
        dailyField = 'flipPerTurnoverRatio';
    otherwise
        error('plotAggregateMetrics:InvalidKind', 'Invalid ratio kind: %s', kind);
end

if mode == "median"
    ratioMap = medianFromDaily(summary, dailyField);
else
    ratioMap = summary.operatorSummary.(mapField);
end

data = operatorMapValues(ratioMap, summary.operatorSummary.operatorNames);
end

% -------------------------------------------------------------------------
function mapOut = medianFromDaily(summary, fieldName)
dailyResults = summary.dailyResults;
valueMap = containers.Map('KeyType','char','ValueType','any');

for idx = 1:numel(dailyResults)
    metrics = dailyResults{idx}.operatorMetrics;
    if ~isfield(metrics, fieldName) || isempty(metrics.(fieldName))
        continue;
    end
    map = metrics.(fieldName);
    keys = map.keys;
    for k = 1:numel(keys)
        key = keys{k};
        if ~valueMap.isKey(key)
            valueMap(key) = map(key);
        else
            valueMap(key) = [valueMap(key), map(key)]; %#ok<AGROW>
        end
    end
end

mapOut = containers.Map('KeyType','char','ValueType','double');
keys = valueMap.keys;
for k = 1:numel(keys)
    key = keys{k};
    values = valueMap(key);
    mapOut(key) = median(values, 'omitnan');
end
end

% -------------------------------------------------------------------------
function data = operatorMapValues(mapObj, namesMap)
if isempty(mapObj)
    data.labels = {};
    data.values = [];
    return;
end
keys = mapObj.keys;
labels = cell(0,1);
values = [];

for idx = 1:numel(keys)
    key = keys{idx};
    value = mapObj(key);
    if isnan(value)
        continue;
    end
    if nargin < 2 || isempty(namesMap) || ~namesMap.isKey(key)
        displayName = char(key);
    else
        displayName = namesMap(key);
    end
    labels{end+1,1} = displayName; %#ok<AGROW>
    values(end+1,1) = double(value); %#ok<AGROW>
end

labels = conduction.plotting.utils.formatOperatorNames(labels);

[labels, values] = sortByDescending(labels, values);

data.labels = labels;
 data.values = values;
end

% -------------------------------------------------------------------------
function annotateBars(ax, values, fmt)
labels = arrayfun(@(v) numericLabel(v, fmt), values, 'UniformOutput', false);
text(ax, 1:numel(values), values, labels, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

% -------------------------------------------------------------------------
function label = numericLabel(value, fmt)
if isnan(value)
    label = '';
else
    label = sprintf(fmt, value);
end
end

% -------------------------------------------------------------------------
function titleText = titleForMode(baseTitle, mode)
if mode == "median"
    titleText = sprintf('%s (Median)', baseTitle);
else
    titleText = sprintf('%s (Aggregate)', baseTitle);
end
end

% -------------------------------------------------------------------------
function [sortedLabels, sortedValues] = sortByDescending(labels, values)
[sortedValues, order] = sort(values, 'descend');
sortedLabels = labels(order);
end
