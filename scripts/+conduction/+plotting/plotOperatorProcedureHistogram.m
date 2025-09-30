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
%
%   EXAMPLE:
%       scheduleCollection = conduction.ScheduleCollection.fromFile('data.csv');
%       fig = conduction.plotting.plotOperatorProcedureHistogram(...
%           scheduleCollection, 'Dr. Smith', 'Appendectomy', 'procedureMinutes');
%
%   The function returns a minimalistic figure with median, p70, and p90 lines.

parser = inputParser;
addParameter(parser, 'BinCount', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
parse(parser, varargin{:});

binCount = parser.Results.BinCount;

% Extract duration data using helper
durations = conduction.analytics.helpers.OperatorProcedureDurationHelper...
    .getOperatorProcedureDurations(scheduleCollectionOrAggregator, operatorName, procedureName, durationField);

if isempty(durations)
    error('plotOperatorProcedureHistogram:NoData', ...
        'No data found for operator "%s" performing "%s".', operatorName, procedureName);
end

% Remove NaN values
durations = durations(~isnan(durations));
if isempty(durations)
    error('plotOperatorProcedureHistogram:NoValidData', ...
        'No valid duration data found for operator "%s" performing "%s".', operatorName, procedureName);
end

% Check if we have fewer than 3 procedures - if so, use all operators for this procedure
usedAllOperators = false;
if length(durations) < 3
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

% Calculate statistics
medianVal = median(durations);
p70Val = prctile(durations, 70);
p90Val = prctile(durations, 90);

% Create figure with specified dimensions
fig = figure('Position', [100, 100, 420, 260], 'Color', [0 0 0]);
ax = axes('Parent', fig);
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

% Add floating legend text in upper right corner with aligned labels and values
xLimits = xlim(ax);
labelX = xLimits(1) + (xLimits(2) - xLimits(1)) * 0.88;  % Label right-aligned
valueX = xLimits(1) + (xLimits(2) - xLimits(1)) * 0.90;  % Value left-aligned
rightEdgeX = xLimits(1) + (xLimits(2) - xLimits(1)) * 0.98;  % Right edge for white text
centerX = (labelX + valueX) / 2;  % Center point for sample count
legendYStart = yLimits(2) * 0.75;  % Moved down from 0.95 to 0.75
legendYSpacing = yLimits(2) * 0.08;

% Sample count line (right-aligned with right edge of colored text)
nSamples = length(durations);
text(ax, rightEdgeX, legendYStart + legendYSpacing, sprintf('n = %d procedures', nSamples), ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', [0.9 0.9 0.9], 'FontWeight', 'normal');

% Median
text(ax, labelX, legendYStart, 'median', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', medianColor);
text(ax, valueX, legendYStart, sprintf('%.0fm', medianVal), ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', medianColor);

% P70
text(ax, labelX, legendYStart - legendYSpacing, 'p70', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', p70Color);
text(ax, valueX, legendYStart - legendYSpacing, sprintf('%.0fm', p70Val), ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', p70Color);

% P90
text(ax, labelX, legendYStart - 2*legendYSpacing, 'p90', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', p90Color);
text(ax, valueX, legendYStart - 2*legendYSpacing, sprintf('%.0fm', p90Val), ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'Color', p90Color);

% Add note if using all operators data (below the statistics with double space, three lines)
if usedAllOperators
    text(ax, rightEdgeX, legendYStart - 4*legendYSpacing, '(too few procedures:', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', 10, 'Color', [0.8 0.8 0.8], 'FontAngle', 'italic');
    text(ax, rightEdgeX, legendYStart - 4.8*legendYSpacing, 'using data from', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', 10, 'Color', [0.8 0.8 0.8], 'FontAngle', 'italic');
    text(ax, rightEdgeX, legendYStart - 5.6*legendYSpacing, 'all operators)', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', 10, 'Color', [0.8 0.8 0.8], 'FontAngle', 'italic');
end

% Dark mode styling - remove y-axis, titles, labels
set(ax, 'YTick', [], 'YColor', 'none');
set(ax, 'XTick', [], 'Box', 'off');
set(ax, 'Color', [0 0 0]);
set(ax, 'XColor', [0.5 0.5 0.5]);

hold(ax, 'off');

end