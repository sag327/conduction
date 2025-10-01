classdef ScheduleRenderer < handle
    % SCHEDULERENDERER Controller for schedule visualization

    methods (Access = public)

        function renderEmptySchedule(~, app, labNumbers)
            % Display empty schedule with time grid and lab rows
            app.closeDrawer();
            app.DrawerCurrentCaseId = "";

            % Default time window: 6 AM to 8 PM (6 to 20 hours)
            startHour = 6;
            endHour = 20;

            % Set up main schedule axes
            ax = app.ScheduleAxes;
            cla(ax);
            hold(ax, 'on');

            % Set up axes properties to match visualizeDailySchedule styling
            set(ax, 'YDir', 'reverse', 'Color', [0 0 0]);
            ylim(ax, [startHour, endHour]);
            xlim(ax, [0.5, length(labNumbers) + 0.5]);

            % Add hour grid lines
            conduction.gui.controllers.ScheduleRenderer.addHourGridToAxes(ax, startHour, endHour, length(labNumbers));

            % Set up lab labels on x-axis
            labLabels = arrayfun(@(num) sprintf('Lab %d', num), labNumbers, 'UniformOutput', false);
            set(ax, 'XTick', 1:length(labNumbers), 'XTickLabel', labLabels);

            % Format y-axis with time labels
            conduction.gui.controllers.ScheduleRenderer.formatTimeAxisLabels(ax, startHour, endHour);

            % Add "No cases scheduled" placeholder text
            neutralText = [0.9 0.9 0.9];
            text(ax, mean(xlim(ax)), mean(ylim(ax)), 'No cases scheduled', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 16, 'FontWeight', 'bold', 'Color', neutralText);

            % Set axis properties to match visualizeDailySchedule
            axisColor = [0.9 0.9 0.9];
            gridColor = axisColor * 0.4;
            set(ax, 'GridAlpha', 0.3, 'XColor', axisColor, 'YColor', axisColor, ...
                'GridColor', gridColor, 'Box', 'on', 'LineWidth', 1);
            ax.XAxis.Color = axisColor;
            ax.YAxis.Color = axisColor;
            ylabel(ax, '', 'Color', axisColor);

            hold(ax, 'off');

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.drawUtilization(app.UtilAxes);
                app.drawFlipMetrics(app.FlipAxes);
                app.drawIdleMetrics(app.IdleAxes);
            end
        end

        function renderOptimizedSchedule(~, app, dailySchedule, metadata)
            if nargin < 4
                metadata = struct();
            end

            if isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
                app.AnalyticsRenderer.resetKPIBar(app);
                return;
            end

            conduction.visualizeDailySchedule(dailySchedule, ...
                'Title', 'Optimized Schedule', ...
                'ScheduleAxes', app.ScheduleAxes, ...
                'ShowLabels', true, ...
                'CaseClickedFcn', @(caseId) app.onScheduleBlockClicked(caseId), ...
                'LockedCaseIds', app.LockedCaseIds, ...
                'OperatorColors', app.OperatorColors);

            if app.DrawerWidth > 1 && strlength(app.DrawerCurrentCaseId) > 0
                app.DrawerController.populateDrawer(app, app.DrawerCurrentCaseId);
            end

            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            app.AnalyticsRenderer.updateKPIBar(app, dailySchedule);

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.AnalyticsRenderer.drawUtilization(app, app.UtilAxes);
                app.AnalyticsRenderer.drawFlipMetrics(app, app.FlipAxes);
                app.AnalyticsRenderer.drawIdleMetrics(app, app.IdleAxes);
            end
        end

    end

    methods (Static, Access = public)

        function addHourGridToAxes(ax, startHour, endHour, numLabs)
            % Add horizontal grid lines for each hour
            hourTicks = floor(startHour):ceil(endHour);
            xLimits = [0.5, numLabs + 0.5];

            gridColor = [0.3, 0.3, 0.3];
            for h = hourTicks
                line(ax, xLimits, [h, h], 'Color', gridColor, ...
                    'LineStyle', '-', 'LineWidth', 0.5);
            end
        end

        function formatTimeAxisLabels(ax, startHour, endHour)
            % Format axis with time labels (e.g., "06:00", "07:00")
            hourTicks = floor(startHour):ceil(endHour);
            hourLabels = arrayfun(@(h) sprintf('%02d:00', mod(h, 24)), hourTicks, 'UniformOutput', false);
            set(ax, 'YTick', hourTicks, 'YTickLabel', hourLabels);
        end

    end
end
