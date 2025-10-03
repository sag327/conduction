classdef ScheduleRenderer < handle
    % SCHEDULERENDERER Controller for schedule visualization

    methods (Access = public)

        function renderEmptySchedule(~, app, labNumbers)
            % Display empty schedule with time grid and lab rows
            app.DrawerController.closeDrawer(app);
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
                app.AnalyticsRenderer.drawUtilization(app, app.UtilAxes);
                app.AnalyticsRenderer.drawFlipMetrics(app, app.FlipAxes);
                app.AnalyticsRenderer.drawIdleMetrics(app, app.IdleAxes);
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

            % Use fade effect if schedule is stale/dirty
            fadeAlpha = 1.0;  % Default: full opacity
            if app.IsOptimizationDirty
                fadeAlpha = 0.35;  % Faded when stale (35% opacity)
            end

            % REALTIME-SCHEDULING: Get current time from CaseManager
            currentTime = app.CaseManager.getCurrentTime();

            app.OperatorColors = conduction.visualizeDailySchedule(dailySchedule, ...
                'Title', 'Optimized Schedule', ...
                'ScheduleAxes', app.ScheduleAxes, ...
                'ShowLabels', true, ...
                'CaseClickedFcn', @(caseId) app.onScheduleBlockClicked(caseId), ...
                'BackgroundClickedFcn', @() app.onScheduleBackgroundClicked(), ...
                'LockedCaseIds', app.LockedCaseIds, ...
                'SelectedCaseId', app.SelectedCaseId, ...
                'OperatorColors', app.OperatorColors, ...
                'FadeAlpha', fadeAlpha, ...
                'CurrentTimeMinutes', currentTime);  % REALTIME-SCHEDULING

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

        % REALTIME-SCHEDULING: NOW Line Drag Functionality
        function enableNowLineDrag(obj, app)
            %ENABLENOWLINEDRAG Make NOW line draggable
            nowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
            if isempty(nowLine)
                return;
            end

            % Make line thicker and change to dashed when draggable
            nowLine.LineWidth = 4;
            nowLine.LineStyle = '--';
            nowLine.ButtonDownFcn = @(src, event) obj.startDragNowLine(app, src);
        end

        function disableNowLineDrag(~, app)
            %DISABLENOWLINEDRAG Make NOW line non-interactive
            nowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
            if isempty(nowLine)
                return;
            end

            % Restore normal appearance
            nowLine.LineWidth = 3;
            nowLine.LineStyle = '-';
            nowLine.ButtonDownFcn = [];
        end

        function startDragNowLine(obj, app, lineHandle)
            %STARTDRAGNOWLINE Initialize drag state
            app.UIFigure.UserData.isDraggingNowLine = true;
            app.UIFigure.UserData.dragLineHandle = lineHandle;

            % Set motion and release callbacks
            app.UIFigure.WindowButtonMotionFcn = @(~,~) obj.updateNowLinePosition(app);
            app.UIFigure.WindowButtonUpFcn = @(~,~) obj.endDragNowLine(app);

            % Change cursor
            app.UIFigure.Pointer = 'hand';
        end

        function updateNowLinePosition(~, app)
            %UPDATENOWLINEPOSITION Update line position during drag
            if ~isfield(app.UIFigure.UserData, 'isDraggingNowLine') || ~app.UIFigure.UserData.isDraggingNowLine
                return;
            end

            % Get mouse position in axes coordinates
            pt = app.ScheduleAxes.CurrentPoint;
            newTimeHour = pt(1, 2); % Y-coordinate in axes

            % Constrain to schedule bounds
            yLimits = ylim(app.ScheduleAxes);
            newTimeHour = max(yLimits(1), min(yLimits(2), newTimeHour));

            % Update line position
            lineHandle = app.UIFigure.UserData.dragLineHandle;
            lineHandle.YData = [newTimeHour, newTimeHour];

            % Update text label
            newTimeMinutes = newTimeHour * 60;
            timeStr = app.ScheduleRenderer.minutesToTimeString(newTimeMinutes);

            % Find and update NOW label
            nowLabel = findobj(app.ScheduleAxes, 'Tag', 'NowLabel');
            if ~isempty(nowLabel)
                nowLabel.String = sprintf('NOW (%s)', timeStr);
                nowLabel.Position(2) = newTimeHour - 0.1;
            end

            % Store current time (don't commit yet)
            lineHandle.UserData.timeMinutes = newTimeMinutes;
        end

        function endDragNowLine(obj, app)
            %ENDDRAGNOWLINE Finalize drag and update case statuses
            if ~isfield(app.UIFigure.UserData, 'isDraggingNowLine') || ~app.UIFigure.UserData.isDraggingNowLine
                return;
            end

            % Get final time
            lineHandle = app.UIFigure.UserData.dragLineHandle;
            finalTimeMinutes = lineHandle.UserData.timeMinutes;

            % Update CaseManager with new time
            app.CaseManager.setCurrentTime(finalTimeMinutes);

            % Auto-update case statuses based on new time
            obj.updateCaseStatusesByTime(app, finalTimeMinutes);

            % Clear drag state
            app.UIFigure.UserData.isDraggingNowLine = false;
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.UIFigure.Pointer = 'arrow';

            % Re-render schedule to show updated statuses
            app.OptimizationController.renderCurrentSchedule(app);
        end

        function updateCaseStatusesByTime(~, app, currentTimeMinutes)
            %UPDATECASESTATUSESBYTIME Auto-update case statuses based on current time
            cases = app.CaseManager.getAllCases();

            if isempty(cases) || isempty(app.OptimizedSchedule)
                return;
            end

            % Get case timing from schedule
            labAssignments = app.OptimizedSchedule.labAssignments();

            for labIdx = 1:numel(labAssignments)
                labCases = labAssignments{labIdx};
                if isempty(labCases)
                    continue;
                end

                for caseIdx = 1:numel(labCases)
                    scheduledCase = labCases(caseIdx);

                    % Extract timing
                    procStartTime = app.ScheduleRenderer.getFieldValue(scheduledCase, 'procStartTime', NaN);
                    procEndTime = app.ScheduleRenderer.getFieldValue(scheduledCase, 'procEndTime', NaN);
                    caseId = app.ScheduleRenderer.getFieldValue(scheduledCase, 'caseID', NaN);

                    if isnan(procStartTime) || isnan(procEndTime) || isnan(caseId)
                        continue;
                    end

                    % Find corresponding ProspectiveCase
                    prospectiveCaseIdx = double(caseId);
                    if prospectiveCaseIdx > numel(cases)
                        continue;
                    end

                    prospectiveCase = cases(prospectiveCaseIdx);

                    % Determine new status based on time
                    if procEndTime <= currentTimeMinutes
                        % Case is completed
                        if prospectiveCase.CaseStatus ~= "completed"
                            actualTimes = struct();
                            actualTimes.ActualProcStartTime = procStartTime;
                            actualTimes.ActualProcEndTime = procEndTime;
                            actualTimes.ActualStartTime = app.ScheduleRenderer.getFieldValue(scheduledCase, 'startTime', procStartTime);
                            actualTimes.ActualEndTime = app.ScheduleRenderer.getFieldValue(scheduledCase, 'endTime', procEndTime);

                            app.CaseManager.setCaseStatus(prospectiveCaseIdx, "completed", actualTimes);
                        end
                    elseif procStartTime <= currentTimeMinutes && currentTimeMinutes < procEndTime
                        % Case is in progress
                        if prospectiveCase.CaseStatus ~= "in_progress"
                            app.CaseManager.setCaseStatus(prospectiveCaseIdx, "in_progress");
                        end
                    else
                        % Case is pending (procStartTime > currentTimeMinutes)
                        if prospectiveCase.CaseStatus ~= "pending"
                            % Reset to pending (only if not completed)
                            prospectiveCase.CaseStatus = "pending";
                        end
                    end
                end
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

        function timeStr = minutesToTimeString(minutes)
            %MINUTESTOTIMESTRING Convert minutes from midnight to HH:MM AM/PM
            if isnan(minutes)
                timeStr = 'N/A';
                return;
            end

            hours = floor(minutes / 60);
            mins = mod(minutes, 60);

            if hours >= 12
                period = 'PM';
                displayHour = hours;
                if hours > 12
                    displayHour = hours - 12;
                end
            else
                period = 'AM';
                displayHour = hours;
                if hours == 0
                    displayHour = 12;
                end
            end

            timeStr = sprintf('%d:%02d %s', displayHour, mins, period);
        end

        function value = getFieldValue(structOrObj, fieldName, defaultValue)
            %GETFIELDVALUE Safely extract field value from struct or object
            if isstruct(structOrObj) && isfield(structOrObj, fieldName)
                value = structOrObj.(fieldName);
            elseif isobject(structOrObj) && isprop(structOrObj, fieldName)
                value = structOrObj.(fieldName);
            else
                value = defaultValue;
            end
        end

    end
end
