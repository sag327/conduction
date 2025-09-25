function fig = plotTrendMetrics(summary, varargin)
%PLOTTRENDTMETRICS Plot operator-level trends over time.
%   fig = conduction.plotting.operator.plotTrendMetrics(summary) renders line
%   charts showing how overall operator metrics change across the collection.
%   Summary must be produced by conduction.analytics.analyzeScheduleCollection
%   so that per-day results are available.
%
%   Name/value options:
%       'Metrics'   - cell array selecting metrics (default {'IdlePerTurnover','FlipPerTurnover'})
%                     Supported values: 'IdlePerTurnover', 'FlipPerTurnover',
%                     'OperatorIdleMinutes', 'OperatorFlipCount'
%       'Smoothing' - positive integer window size for moving average (default 1)
%
%   Returns the figure handle. Plots are styled and annotated with the current
%   refactor version.

if ~isfield(summary, 'dailyResults') || isempty(summary.dailyResults)
    error('plotTrendMetrics:MissingDailyResults', ...
        'Collection summary must include dailyResults to plot trends.');
end

parser = inputParser;
addParameter(parser, 'Metrics', {'IdlePerTurnover','FlipPerTurnover'}, @(x) ischar(x) || isstring(x) || iscell(x));
addParameter(parser, 'Smoothing', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(parser, varargin{:});

metrics = cellstr(parser.Results.Metrics);
if isempty(metrics)
    metrics = {'IdlePerTurnover','FlipPerTurnover'};
end
window = max(1, round(parser.Results.Smoothing));

[dates, deptSeries] = extractDepartmentSeries(summary);

fig = figure('Name', 'Operator Trend Metrics', 'Color', 'w');
tl = tiledlayout(fig, numel(metrics), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axList = gobjects(numel(metrics), 1);

for idx = 1:numel(metrics)
    metricName = string(lower(metrics{idx}));
    ax = nexttile(tl);
    axList(idx) = ax;
    switch metricName
        case 'idleperturnover'
            values = deptSeries.idlePerTurnover;
            ylabel(ax, 'Idle minutes per turnover');
            title(ax, 'Idle per Turnover (Department)');
        case 'flipperturnover'
            values = 100 * deptSeries.flipPerTurnover;
            ylabel(ax, 'Flip per turnover (%)');
            title(ax, 'Flip per Turnover (Department)');
        case 'operatoridleminutes'
            values = deptSeries.totalOperatorIdleMinutes;
            ylabel(ax, 'Operator idle minutes');
            title(ax, 'Total Operator Idle Minutes');
        case 'operatorflipcount'
            values = deptSeries.totalFlipCount;
            ylabel(ax, 'Operator flip count');
            title(ax, 'Operator Flip Count');
        otherwise
            delete(ax);
            error('plotTrendMetrics:UnsupportedMetric', ...
                'Unsupported metric selection: %s', metrics{idx});
    end

    if window > 1
        values = movmean(values, window, 'omitnan');
    end

    plot(ax, dates, values, '-o', 'LineWidth', 1.2);
    grid(ax, 'on');
    ax.XAxis.TickLabelFormat = 'yyyy-MM-dd';
    ax.XTickLabelRotation = 45;
end

conduction.plotting.utils.applyStandardStyle(fig, axList(isgraphics(axList)));
conduction.plotting.utils.attachVersionAnnotation(fig);
end

% -------------------------------------------------------------------------
function [dates, series] = extractDepartmentSeries(summary)
dailyResults = summary.dailyResults;
numDays = numel(dailyResults);

dates = NaT(numDays,1);
idle = nan(numDays,1);
flip = nan(numDays,1);
totalIdle = nan(numDays,1);
flipCount = nan(numDays,1);

for idx = 1:numDays
    day = dailyResults{idx};
    if isfield(day, 'date')
        dates(idx) = day.date;
    end
    dept = day.operatorDepartmentMetrics;
    idle(idx) = dept.idlePerTurnoverRatio;
    flip(idx) = dept.flipPerTurnoverRatio;
    if isfield(dept, 'totalOperatorIdleMinutes')
        totalIdle(idx) = dept.totalOperatorIdleMinutes;
    end
    flipCount(idx) = dept.totalFlipCount;
end

series = struct();
series.idlePerTurnover = idle;
series.flipPerTurnover = flip;
series.totalOperatorIdleMinutes = totalIdle;
series.totalFlipCount = flipCount;

% ensure dates sorted
[dates, order] = sort(dates);
series.idlePerTurnover = series.idlePerTurnover(order);
series.flipPerTurnover = series.flipPerTurnover(order);
series.totalOperatorIdleMinutes = series.totalOperatorIdleMinutes(order);
series.totalFlipCount = series.totalFlipCount(order);
end
