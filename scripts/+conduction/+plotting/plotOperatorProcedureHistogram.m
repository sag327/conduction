function fig = plotOperatorProcedureHistogram(scheduleCollectionOrAggregator, operatorName, procedureName, durationField, varargin)
%PLOTOPERATORPROCEDUREHISTOGRAM Plot minimalistic histogram of durations for operator-procedure.
%   fig = plotOperatorProcedureHistogram(scheduleCollectionOrAggregator, operatorName, procedureName, durationField)
%   creates a minimalistic histogram showing the distribution of durations for the specified
%   operator performing the specified procedure.
%
%   INPUTS:
%       scheduleCollectionOrAggregator - Either:
%                          (1) A ScheduleCollection object (automatically aggregates)
%                          (2) An array of DailySchedule objects (automatically aggregates)
%                          (3) A ProcedureMetricsAggregator object (uses existing aggregation)
%       operatorName    - Name of operator (string or char)
%       procedureName   - Name of procedure (string or char)
%       durationField   - Duration field to plot:
%                         'totalCaseMinutes', 'procedureMinutes', 'setupMinutes',
%                         'postMinutes', 'turnoverMinutes'
%
%   Optional name/value pairs:
%       'BinCount'      - Number of histogram bins (default: auto)
%       'Parent'        - Axes to plot into (if not specified, creates new figure)
%
%   EXAMPLE:
%       scheduleCollection = conduction.ScheduleCollection.fromFile('data.csv');
%       fig = conduction.plotting.plotOperatorProcedureHistogram(...
%           scheduleCollection, 'Dr. Smith', 'Appendectomy', 'procedureMinutes');
%
%   The function returns a figure handle (or empty if Parent was specified).

parser = inputParser;
addParameter(parser, 'BinCount', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(parser, 'Parent', [], @(x) isempty(x) || isa(x, 'matlab.ui.control.UIAxes') || isa(x, 'matlab.graphics.axis.Axes'));
addParameter(parser, 'MinimalMode', false, @islogical);
addParameter(parser, 'BackgroundColor', [0 0 0], @(x) isnumeric(x) && numel(x) == 3);
parse(parser, varargin{:});

binCount = parser.Results.BinCount;
parentAxes = parser.Results.Parent;
minimalMode = parser.Results.MinimalMode;
bgColor = parser.Results.BackgroundColor;

% Extract duration data using helper
durations = conduction.analytics.helpers.OperatorProcedureDurationHelper...
    .getOperatorProcedureDurations(scheduleCollectionOrAggregator, operatorName, procedureName, durationField);

% Remove NaN values from operator-specific data
if ~isempty(durations)
    durations = durations(~isnan(durations));
end

% Check if we have fewer than 3 procedures - if so, use all operators for this procedure
usedAllOperators = false;
if isempty(durations) || length(durations) < 3
    % Get data for all operators performing this procedure
    durationsAllOps = conduction.analytics.helpers.OperatorProcedureDurationHelper...
        .getAllOperatorsProcedureDurations(scheduleCollectionOrAggregator, procedureName, durationField);

    if ~isempty(durationsAllOps)
        durationsAllOps = durationsAllOps(~isnan(durationsAllOps));
        if length(durationsAllOps) >= 3
            durations = durationsAllOps;
            usedAllOperators = true;
        end
    end
end

% Final check - if still no data, throw error
if isempty(durations)
    error('plotOperatorProcedureHistogram:NoData', ...
        'No data found for operator "%s" performing "%s".', operatorName, procedureName);
end

% Calculate statistics
medianVal = median(durations);
p70Val = prctile(durations, 70);
p90Val = prctile(durations, 90);

% Create figure or use provided axes
if isempty(parentAxes)
    fig = figure('Position', [100, 100, 420, 260], 'Color', [0 0 0]);
    ax = axes('Parent', fig);
else
    fig = [];
    ax = parentAxes;
end
hold(ax, 'on');

% Fit and overlay a smooth distribution curve (no histogram bars)
[f, xi] = ksdensity(durations);
plot(ax, xi, f, 'Color', [0.3 0.8 1.0], 'LineWidth', 2);

% Get y-axis limits for vertical lines
yLimits = ylim(ax);

% Define colors for each line
medianColor = [0.9 0.3 0.3];  % Red
p70Color = [0.9 0.7 0.2];     % Orange/Yellow
p90Color = [0.5 0.9 0.5];     % Green

% Add vertical lines for median, p70, p90 with ':' linestyle and different colors
line(ax, [medianVal medianVal], yLimits, 'LineStyle', ':', 'Color', medianColor, 'LineWidth', 1.5);
line(ax, [p70Val p70Val], yLimits, 'LineStyle', ':', 'Color', p70Color, 'LineWidth', 1.5);
line(ax, [p90Val p90Val], yLimits, 'LineStyle', ':', 'Color', p90Color, 'LineWidth', 1.5);

% Add small filled circles at the top of each line
circleSize = 40;
scatter(ax, medianVal, yLimits(2), circleSize, medianColor, 'filled');
scatter(ax, p70Val, yLimits(2), circleSize, p70Color, 'filled');
scatter(ax, p90Val, yLimits(2), circleSize, p90Color, 'filled');

% Only add text elements if not in minimal mode
if ~minimalMode

    % Larger font size for better readability
    textFontSize = 13;

    % Add floating legend text in upper right corner with aligned labels and values
    xLimits = xlim(ax);
    labelX = xLimits(1) + (xLimits(2) - xLimits(1)) * 0.88;  % Label right-aligned
    valueX = xLimits(1) + (xLimits(2) - xLimits(1)) * 0.90;  % Value left-aligned
    rightEdgeX = xLimits(1) + (xLimits(2) - xLimits(1)) * 0.98;  % Right edge for white text
    centerX = (labelX + valueX) / 2;  % Center point for sample count
    legendYStart = yLimits(2) * 0.75;  % Moved down from 0.95 to 0.75
    legendYSpacing = yLimits(2) * 0.065;  % Tighter spacing between lines

    % Sample count line (right-aligned with right edge of colored text)
    nSamples = length(durations);
    text(ax, rightEdgeX, legendYStart + legendYSpacing, sprintf('n = %d procedures', nSamples), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', [0.9 0.9 0.9], 'FontWeight', 'normal');

    % Median
    text(ax, labelX, legendYStart, 'median', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', medianColor);
    text(ax, valueX, legendYStart, sprintf('%.0fm', medianVal), ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', medianColor);

    % P70
    text(ax, labelX, legendYStart - legendYSpacing, 'p70', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', p70Color);
    text(ax, valueX, legendYStart - legendYSpacing, sprintf('%.0fm', p70Val), ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', p70Color);

    % P90
    text(ax, labelX, legendYStart - 2*legendYSpacing, 'p90', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', p90Color);
    text(ax, valueX, legendYStart - 2*legendYSpacing, sprintf('%.0fm', p90Val), ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontSize', textFontSize, 'Color', p90Color);

    % Add note if using all operators data (below the statistics with double space, three lines)
    if usedAllOperators
        text(ax, rightEdgeX, legendYStart - 4*legendYSpacing, '(too few procedures:', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'FontSize', textFontSize, 'Color', [0.8 0.8 0.8], 'FontAngle', 'italic');
        text(ax, rightEdgeX, legendYStart - 4.8*legendYSpacing, 'using data from', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'FontSize', textFontSize, 'Color', [0.8 0.8 0.8], 'FontAngle', 'italic');
        text(ax, rightEdgeX, legendYStart - 5.6*legendYSpacing, 'all operators)', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'FontSize', textFontSize, 'Color', [0.8 0.8 0.8], 'FontAngle', 'italic');
    end
end

% Dark mode styling - remove y-axis, titles, labels
set(ax, 'YTick', [], 'YTickLabel', [], 'YColor', 'none');
set(ax, 'XTick', [], 'XTickLabel', []);

if minimalMode
    % No box outline in minimal mode
    set(ax, 'Box', 'off');
    set(ax, 'XColor', 'none', 'YColor', 'none');
else
    % White box border for full mode
    set(ax, 'Box', 'on');
    set(ax, 'XColor', [1 1 1], 'YColor', [1 1 1]);
    set(ax, 'LineWidth', 1);
end

% Set background color
set(ax, 'Color', bgColor);

% Don't override position when parent is provided - respect the fixed pixel size
if isempty(parentAxes)
    % For standalone figure, no additional position adjustments needed
end

hold(ax, 'off');

end