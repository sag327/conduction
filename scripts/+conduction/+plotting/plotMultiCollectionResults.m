function plotMultiCollectionResults(experiments, varargin)
%PLOTMULTICOLLECTIONRESULTS Compare metrics across collection analyses.
%   plotMultiCollectionResults(experiments) accepts a cell array of
%   collection summaries (returned by conduction.analytics.analyzeScheduleCollection)
%   or a struct array with fields "summary" and optional "name". The function
%   plots comparative metrics across experiments such as operator idle time per
%   turnover, flip ratios, department-level ratios, makespan, or lab
%   utilisation.
%
%   plotMultiCollectionResults(experiments, 'Metric', metric) selects which
%   metric to visualise. Supported metrics:
%       - 'operatorIdlePerTurnover'  (minutes per turnover)
%       - 'operatorFlipPerTurnover'  (percentage)
%       - 'departmentIdlePerTurnover' (minutes per turnover)
%       - 'departmentFlipPerTurnover' (percentage)
%       - 'makespan' (median daily makespan, minutes)
%       - 'labUtilization' (mean daily lab utilisation, percentage)
%
%   Additional name/value options:
%       'PlotType'       : 'bar' (default) or 'box'. Box plots are supported
%                          only for operator-level metrics.
%       'Aggregation'    : 'mean' (default) or 'median' for aggregating
%                          operator-level data when using bar plots.
%       'ExperimentNames': cell array of labels (defaults to names supplied
%                          in the experiment structs or auto-generated).
%       'Title'          : custom plot title (default auto-generated).
%
%   Examples
%       summaries = {baselineSummary, optimizedSummary};
%       plotMultiCollectionResults(summaries, 'Metric', 'operatorFlipPerTurnover');
%
%       experiments = struct('name', {"Baseline", "Optimised"}, ...
%           'summary', {baselineSummary, optimizedSummary});
%       plotMultiCollectionResults(experiments, 'Metric', 'makespan', ...
%           'PlotType', 'bar');
parser = inputParser;
validMetrics = ["operatorIdlePerTurnover", "operatorFlipPerTurnover", ...
    "departmentIdlePerTurnover", "departmentFlipPerTurnover", ...
    "makespan", "labUtilization"];
addParameter(parser, 'Metric', 'operatorIdlePerTurnover', ...
    @(x) any(strcmpi(string(x), validMetrics)));
addParameter(parser, 'PlotType', 'bar', @(x) any(strcmpi(x, {'bar', 'box'})));
addParameter(parser, 'Aggregation', 'mean', @(x) any(strcmpi(x, {'mean', 'median'})));
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
        'Box plot is only supported for operator-level metrics.');
end

if strcmp(plotType, 'bar')
    values = aggregateMetric(metricData, aggregation);
    plotBar(values, experiments, metricData, aggregation, customTitle);
else
    plotBox(metricData, experiments, customTitle);
end

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
            'Each experiment must contain a collection summary produced by analyzeScheduleCollection.');
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
            'Number of experiment names must match the number of experiments.');
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
            values = mapValues(summary.operatorSummary.operatorTotalIdleMinutesPerTurnover);
            metricData.distributions{idx} = values;
        end
    case "operatorflipperturnover"
        metricData.label = 'Flip per Turnover';
        metricData.unit = 'percent';
        metricData.supportsBox = true;
        for idx = 1:numExperiments
            summary = experiments(idx).summary;
            ratios = mapValues(summary.operatorSummary.operatorFlipPerTurnoverRatio) * 100;
            metricData.distributions{idx} = ratios;
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
            ratio = summary.operatorSummary.department.flipPerTurnoverRatio;
            metricData.values(idx) = ratio * 100;
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
function plotBar(values, experiments, metricData, aggregation, customTitle)
names = {experiments.name};

fig = figure('Name', 'Multi Experiment Comparison');
ax = axes(fig);
bar(ax, values);
ax.XTick = 1:numel(names);
ax.XTickLabel = names;
ax.XTickLabelRotation = 20;
ax.YLabel.String = labelWithUnit(metricData.label, metricData.unit);
ax.Title.String = titleOrDefault(customTitle, metricData.label);

for idx = 1:numel(values)
    text(ax, idx, values(idx), formatValue(values(idx), metricData.unit), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

conduction.plotting.applyStandardStyle(fig, ax);
grid(ax, 'on');
end

% -------------------------------------------------------------------------
function plotBox(metricData, experiments, customTitle)
names = {experiments.name};
fig = figure('Name', 'Multi Experiment Comparison');
ax = axes(fig);
hold(ax, 'on');

for idx = 1:numel(names)
    data = metricData.distributions{idx};
    if isempty(data)
        continue;
    end
    boxchart(ax, repmat(idx, numel(data), 1), data, 'MarkerColor', ax.ColorOrder(mod(idx-1, size(ax.ColorOrder,1))+1, :));
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
        'Expected values in containers.Map.');
end

if isempty(raw)
    vals = [];
else
    vals = cellfun(@double, raw);
end
end

% -------------------------------------------------------------------------
function formatted = formatValue(value, unit)
if strcmpi(unit, 'percent')
    formatted = sprintf('%.1f%%', value);
else
    formatted = sprintf('%.1f', value);
end
end
