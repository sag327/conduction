function fig = plotMultiCollectionResults(experiments, varargin)
%PLOTMULTICOLLECTIONRESULTS Compare metrics across collection analyses.
%   fig = plotMultiCollectionResults(experiments, ...) accepts either a cell
%   array of collection summaries returned by
%   conduction.analytics.analyzeScheduleCollection, or a struct array with
%   fields `summary` (required) and optional `name`. Metrics include operator
%   idle per turnover, flip ratios, department-level ratios, makespan, and lab
%   utilisation.
%
%   Name/value pairs:
%       'Metric'        : metric selector (default 'operatorIdlePerTurnover')
%       'PlotType'      : 'bar' (default) or 'box'
%       'Aggregation'   : 'mean' (default) or 'median' (bar plots only)
%       'ExperimentNames': override names for each experiment
%       'Title'         : custom figure title
%
%   The generated figure is styled via conduction.plotting.applyStandardStyle
%   and contains a footer annotation with the refactor version metadata from
%   conduction.version().

parser = inputParser;
validMetrics = ["operatorIdlePerTurnover", "operatorFlipPerTurnover", ...
    "departmentIdlePerTurnover", "departmentFlipPerTurnover", "makespan", "labUtilization"];
addParameter(parser, 'Metric', 'operatorIdlePerTurnover', ...
    @(x) any(strcmpi(string(x), validMetrics)));
addParameter(parser, 'PlotType', 'bar', @(x) any(strcmpi(x, {'bar','box'})));
addParameter(parser, 'Aggregation', 'mean', @(x) any(strcmpi(x, {'mean','median'})));
addParameter(parser, 'ExperimentNames', {}, @(x) iscell(x) || isstring(x));
addParameter(parser, 'Title', '', @(x) ischar(x) || isstring(x));
parse(parser, varargin{:});

metric = string(lower(parser.Results.Metric));
plotType = lower(parser.Results.PlotType);
aggregation = lower(parser.Results.Aggregation);
customNames = parser.Results.ExperimentNames;
customTitle = string(parser.Results.Title);

experiments = normaliseExperiments(experiments, customNames);
metricData = extractMetricData(experiments, metric);

if strcmp(plotType, 'box') && ~metricData.supportsBox
    error('plotMultiCollectionResults:UnsupportedPlotType', ...
        'Box plots are only valid for operator-level metrics.');
end

if strcmp(plotType, 'bar')
    values = aggregateMetric(metricData, aggregation);
    fig = plotBar(values, experiments, metricData, aggregation, customTitle);
else
    fig = plotBox(metricData, experiments, customTitle);
end

attachVersionAnnotation(fig);
end

% -------------------------------------------------------------------------
function experiments = normaliseExperiments(rawInput, customNames)
if iscell(rawInput)
    cellInput = rawInput;
elseif isstruct(rawInput)
    cellInput = num2cell(rawInput);
else
    error('plotMultiCollectionResults:InvalidExperiments', ...
        'Provide a cell array or struct array of experiment summaries.');
end

numExperiments = numel(cellInput);
experiments = repmat(struct('name', "", 'summary', []), numExperiments, 1);

for idx = 1:numExperiments
    entry = cellInput{idx};
    if isfield(entry, 'summary')
        experiments(idx).summary = entry.summary;
        if isfield(entry, 'name')
            experiments(idx).name = string(entry.name);
        end
    elseif isfield(entry, 'operatorSummary') && isfield(entry, 'dailySummary')
        experiments(idx).summary = entry;
    else
        error('plotMultiCollectionResults:InvalidSummary', ...
            'Each experiment must contain a summary from analyzeScheduleCollection.');
    end
end

if isempty(customNames)
    for idx = 1:numExperiments
        if strlength(experiments(idx).name) == 0
            experiments(idx).name = sprintf('Experiment %d', idx);
        end
    end
else
    if numel(customNames) ~= numExperiments
        error('plotMultiCollectionResults:NameMismatch', ...
            'Number of experiment names must match number of experiments.');
    end
    customNames = cellstr(customNames);
    for idx = 1:numExperiments
        experiments(idx).name = string(customNames{idx});
    end
end
end

% -------------------------------------------------------------------------
function metricData = extractMetricData(experiments, metric)
numExperiments = numel(experiments);

metricData = struct();
metricData.distributions = cell(numExperiments, 1);
metricData.values = nan(numExperiments, 1);
metricData.supportsBox = false;

switch metric
    case "operatoridleperturnover"
        metricData.label = 'Idle Time per Turnover';
        metricData.unit = 'minutes';
        metricData.supportsBox = true;
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            metricData.distributions{idx} = mapValues(summary.operatorSummary.operatorTotalIdleMinutesPerTurnover);
        end
    case "operatorflipperturnover"
        metricData.label = 'Flip per Turnover';
        metricData.unit = 'percent';
        metricData.supportsBox = true;
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            metricData.distributions{idx} = 100 * mapValues(summary.operatorSummary.operatorFlipPerTurnoverRatio);
        end
    case "departmentidleperturnover"
        metricData.label = 'Department Idle per Turnover';
        metricData.unit = 'minutes';
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            metricData.values(idx) = summary.operatorSummary.department.idlePerTurnoverRatio;
        end
    case "departmentflipperturnover"
        metricData.label = 'Department Flip per Turnover';
        metricData.unit = 'percent';
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            metricData.values(idx) = 100 * summary.operatorSummary.department.flipPerTurnoverRatio;
        end
    case "makespan"
        metricData.label = 'Median Makespan';
        metricData.unit = 'minutes';
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            metricData.values(idx) = summary.dailySummary.makespanMedian;
        end
    case "labutilization"
        metricData.label = 'Average Lab Utilisation';
        metricData.unit = 'percent';
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            metricData.values(idx) = summary.dailySummary.averageLabOccupancyMean * 100;
        end
    otherwise
        error('plotMultiCollectionResults:UnknownMetric', ...
            'Unsupported metric selection: %s', metric);
end
end

% -------------------------------------------------------------------------
function values = aggregateMetric(metricData, aggregation)
if ~isempty(metricData.distributions{1})
    numExperiments = numel(metricData.distributions);
    values = nan(numExperiments, 1);
    for idx = 1:numExperiments
        data = metricData.distributions{idx};
        switch aggregation
            case 'median'
                values(idx) = median(data, 'omitnan');
            otherwise
                values(idx) = mean(data, 'omitnan');
        end
    end
else
    values = metricData.values;
end
end

% -------------------------------------------------------------------------
function fig = plotBar(values, experiments, metricData, aggregation, customTitle)
names = {experiments.name};
fig = figure('Name', 'Collection Metric Comparison', 'Color', 'w');
ax = axes(fig);
bar(ax, values);
ax.XTick = 1:numel(names);
ax.XTickLabel = names;
ax.XTickLabelRotation = 20;
ax.YLabel.String = labelWithUnit(metricData.label, metricData.unit);
ax.Title.String = titleOrDefault(customTitle, metricData.label);

for idx = 1:numel(values)
    if isnan(values(idx))
        continue;
    end
    text(ax, idx, values(idx), formatValue(values(idx), metricData.unit), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

conduction.plotting.applyStandardStyle(fig, ax);
grid(ax, 'on');

annotation(fig, 'textbox', [0.01 0.96 0.3 0.03], 'String', ...
    sprintf('Aggregation: %s', aggregation), 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 9, 'Interpreter', 'none');
end

% -------------------------------------------------------------------------
function fig = plotBox(metricData, experiments, customTitle)
names = {experiments.name};
fig = figure('Name', 'Collection Metric Comparison', 'Color', 'w');
ax = axes(fig);
hold(ax, 'on');

for idx = 1:numel(names)
    data = metricData.distributions{idx};
    if isempty(data)
        continue;
    end
    boxchart(ax, repmat(idx, numel(data), 1), data);
end

ax.XTick = 1:numel(names);
ax.XTickLabel = names;
ax.XTickLabelRotation = 20;
ax.YLabel.String = labelWithUnit(metricData.label, metricData.unit);
ax.Title.String = titleOrDefault(customTitle, metricData.label);

conduction.plotting.applyStandardStyle(fig, ax);
grid(ax, 'on');
hold(ax, 'off');
end

% -------------------------------------------------------------------------
function label = labelWithUnit(baseLabel, unit)
if isempty(unit)
    label = baseLabel;
elseif strcmpi(unit, 'percent')
    label = sprintf('%s (%%)', baseLabel);
else
    label = sprintf('%s (%s)', baseLabel, unit);
end
end

% -------------------------------------------------------------------------
function out = titleOrDefault(customTitle, baseLabel)
if strlength(customTitle) > 0
    out = char(customTitle);
else
    out = sprintf('Comparison: %s', baseLabel);
end
end

% -------------------------------------------------------------------------
function vals = mapValues(mapObj)
if isempty(mapObj)
    vals = [];
    return;
end

if isa(mapObj, 'containers.Map')
    raw = values(mapObj);
else
    error('plotMultiCollectionResults:InvalidMap', ...
        'Expected values to be stored in containers.Map.');
end

if isempty(raw)
    vals = [];
else
    vals = cellfun(@double, raw);
end
end

% -------------------------------------------------------------------------
function txt = formatValue(value, unit)
if isnan(value)
    txt = '';
elseif strcmpi(unit, 'percent')
    txt = sprintf('%.1f%%', value);
else
    txt = sprintf('%.1f', value);
end
end

% -------------------------------------------------------------------------
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

% -------------------------------------------------------------------------
function out = abbreviate(commit)
if isempty(commit) || strcmpi(commit, 'unknown')
    out = 'unknown';
else
    chars = char(commit);
    out = chars(1:min(numel(chars), 7));
end
end

% -------------------------------------------------------------------------
function out = ternary(condition, ifTrue, ifFalse)
if condition
    out = ifTrue;
else
    out = ifFalse;
end
end
