classdef ScheduleRenderer < handle
    % SCHEDULERENDERER Controller for schedule visualization

    methods (Access = public)

        function renderEmptySchedule(obj, app, labNumbers)
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

            obj.drawClosedLabOverlays(app, []);

            if app.IsTimeControlActive
                obj.enableNowLineDrag(app);
            end

            obj.enableCaseDrag(app);

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.AnalyticsRenderer.drawUtilization(app, app.UtilAxes);
                app.AnalyticsRenderer.drawFlipMetrics(app, app.FlipAxes);
                app.AnalyticsRenderer.drawIdleMetrics(app, app.IdleAxes);
            end
        end

        function renderOptimizedSchedule(obj, app, dailySchedule, metadata)
            if nargin < 4
                metadata = struct();
            end

            if isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
                app.AnalyticsRenderer.resetKPIBar(app);
                app.ScheduleRenderer.updateActualTimeIndicator(app);
                return;
            end

            % Use fade effect if schedule is stale/dirty
            fadeAlpha = 1.0;  % Default: full opacity
            if app.IsOptimizationDirty
                fadeAlpha = 0.35;  % Faded when stale (35% opacity)
            end

            % REALTIME-SCHEDULING: Show draggable time line only when time control active
            currentTime = NaN;
            if app.IsTimeControlActive
                currentTime = app.CaseManager.getCurrentTime();
            end

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

            obj.drawClosedLabOverlays(app, dailySchedule);

            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            app.AnalyticsRenderer.updateKPIBar(app, dailySchedule);

            % Update optional actual time indicator after schedule renders
            app.ScheduleRenderer.updateActualTimeIndicator(app);

            if app.IsTimeControlActive
                obj.enableNowLineDrag(app);
            end

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
            nowLine.LineStyle = '-';
            nowLine.Color = [1, 1, 1];
            nowLine.ButtonDownFcn = @(src, event) obj.startDragNowLine(app, src);

            handleMarker = findobj(app.ScheduleAxes, 'Tag', 'NowHandle');
            if ~isempty(handleMarker)
                set(handleMarker, 'MarkerSize', 18, ...
                    'ButtonDownFcn', @(src, event) obj.startDragNowLine(app, src));
            end
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
            nowLine.Color = [1, 1, 1];
            nowLine.ButtonDownFcn = [];

            handleMarker = findobj(app.ScheduleAxes, 'Tag', 'NowHandle');
            if ~isempty(handleMarker)
                set(handleMarker, 'ButtonDownFcn', []);
            end
        end

        function enableCaseDrag(obj, app)
            %ENABLECASED Drag overlay rectangles for case repositioning
            if isempty(app) || isempty(app.ScheduleAxes) || ~isvalid(app.ScheduleAxes)
                return;
            end

            caseBlocks = findobj(app.ScheduleAxes, 'Tag', 'CaseBlock');
            if isempty(caseBlocks)
                return;
            end

            for idx = 1:numel(caseBlocks)
                blockHandle = caseBlocks(idx);
                if ~isgraphics(blockHandle)
                    continue;
                end
                set(blockHandle, 'ButtonDownFcn', @(src, ~) obj.onCaseBlockMouseDown(app, src));
            end
        end

        function onCaseBlockMouseDown(obj, app, rectHandle)
            %ONCASEBLOCKMOUSEDOWN Entry point for case drag or click
            if ~isgraphics(rectHandle)
                return;
            end

            obj.startDragCase(app, rectHandle);
        end

        function startDragCase(obj, app, rectHandle)
            %STARTDRAGCASE Begin dragging a case overlay
            ud = get(rectHandle, 'UserData');
            if ~isstruct(ud) || ~isfield(ud, 'caseId')
                obj.invokeCaseBlockClick(app, rectHandle);
                return;
            end

            caseId = string(ud.caseId);

            if app.IsOptimizationRunning || app.IsTimeControlActive
                obj.invokeCaseBlockClick(app, rectHandle);
                return;
            end

            if ~obj.isCaseBlockDraggable(app, caseId)
                obj.invokeCaseBlockClick(app, rectHandle);
                return;
            end

            drag.rectHandle = rectHandle;
            drag.caseId = caseId;
            drag.originalLabIndex = double(ud.labIndex);

            originalSetupStart = ud.setupStart;
            if isnan(originalSetupStart) && isfield(ud, 'procStart')
                originalSetupStart = ud.procStart;
            end
            if isnan(originalSetupStart)
                originalSetupStart = 0;
            end

            drag.originalSetupStart = originalSetupStart;
            drag.targetLabIndex = drag.originalLabIndex;
            drag.targetStartMinutes = drag.originalSetupStart;
            drag.rectWidth = rectHandle.Position(3);
            drag.rectHeight = rectHandle.Position(4);
            drag.originalPosition = rectHandle.Position;
            drag.snapMinutes = 5;
            drag.hasMoved = false;
            drag.caseClickedFcn = [];
            if isfield(ud, 'caseClickedFcn')
                drag.caseClickedFcn = ud.caseClickedFcn;
            end
            drag.availableLabIds = app.AvailableLabIds;

            currentPoint = get(app.ScheduleAxes, 'CurrentPoint');
            drag.startPoint = currentPoint(1, 1:2);

            if isprop(rectHandle, 'FaceAlpha') && rectHandle.FaceAlpha == 0
                rectHandle.FaceAlpha = 0.1;
            end

            userData = app.UIFigure.UserData;
            if ~isstruct(userData)
                userData = struct();
            end
            userData.dragCase = drag;
            app.UIFigure.UserData = userData;

            app.UIFigure.Pointer = 'hand';
            app.UIFigure.WindowButtonMotionFcn = @(~, ~) obj.updateDragCase(app);
            app.UIFigure.WindowButtonUpFcn = @(~, ~) obj.endDragCase(app);
        end

        function updateDragCase(obj, app)
            %UPDATEDRAGCASE Update overlay during drag motion
            if ~isstruct(app.UIFigure.UserData) || ~isfield(app.UIFigure.UserData, 'dragCase')
                return;
            end

            drag = app.UIFigure.UserData.dragCase;
            if isempty(drag) || ~isgraphics(drag.rectHandle)
                return;
            end

            currentPoint = get(app.ScheduleAxes, 'CurrentPoint');
            currentPoint = currentPoint(1, 1:2);

            numLabs = numel(app.LabIds);
            newLabIndex = round(currentPoint(1));
            newLabIndex = max(1, min(numLabs, newLabIndex));

            durationHours = drag.rectHeight;
            yLimits = ylim(app.ScheduleAxes);
            newStartHour = currentPoint(2);
            newStartHour = max(yLimits(1), min(yLimits(2) - durationHours, newStartHour));

            snapMinutes = max(1, drag.snapMinutes);
            newStartMinutes = round((newStartHour * 60) / snapMinutes) * snapMinutes;
            newStartHour = newStartMinutes / 60;

            newLeft = newLabIndex - drag.rectWidth / 2;
            newPosition = [newLeft, newStartHour, drag.rectWidth, drag.rectHeight];

            set(drag.rectHandle, 'Position', newPosition);

            movedInTime = abs(newStartMinutes - drag.originalSetupStart) >= snapMinutes / 2;
            movedInLab = newLabIndex ~= drag.originalLabIndex;
            drag.hasMoved = drag.hasMoved || movedInTime || movedInLab;
            drag.targetLabIndex = newLabIndex;
            drag.targetStartMinutes = newStartMinutes;

            app.UIFigure.UserData.dragCase = drag;
        end

        function endDragCase(obj, app)
            %ENDDRAGCASE Finalize drag operation
            if ~isstruct(app.UIFigure.UserData) || ~isfield(app.UIFigure.UserData, 'dragCase')
                return;
            end

            drag = app.UIFigure.UserData.dragCase;

            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.UIFigure.Pointer = 'arrow';

            userData = app.UIFigure.UserData;
            userData = rmfield(userData, 'dragCase');
            app.UIFigure.UserData = userData;

            if ~isgraphics(drag.rectHandle)
                return;
            end

            if ~drag.hasMoved
                set(drag.rectHandle, 'Position', drag.originalPosition);
                if isprop(drag.rectHandle, 'FaceAlpha')
                    drag.rectHandle.FaceAlpha = 0;
                end
                obj.invokeCaseBlockClick(app, drag.rectHandle);
                return;
            end

            numLabs = numel(app.LabIds);
            targetLabIndex = max(1, min(numLabs, drag.targetLabIndex));
            targetLabId = app.LabIds(targetLabIndex);

            if ~isempty(drag.availableLabIds) && ~ismember(targetLabId, drag.availableLabIds)
                set(drag.rectHandle, 'Position', drag.originalPosition);
                if isprop(drag.rectHandle, 'FaceAlpha')
                    drag.rectHandle.FaceAlpha = 0;
                end
                obj.showCaseDragWarning(app, 'Selected lab is not available.');
                return;
            end

            newSetupStartMinutes = drag.targetStartMinutes;
            if isnan(newSetupStartMinutes)
                set(drag.rectHandle, 'Position', drag.originalPosition);
                obj.invokeCaseBlockClick(app, drag.rectHandle);
                return;
            end

            scheduleWasUpdated = obj.applyCaseMove(app, drag.caseId, targetLabIndex, newSetupStartMinutes);
            if scheduleWasUpdated
                app.OptimizationController.markOptimizationDirty(app);
                app.markDirty();
            else
                set(drag.rectHandle, 'Position', drag.originalPosition);
                if isprop(drag.rectHandle, 'FaceAlpha')
                    drag.rectHandle.FaceAlpha = 0;
                end
            end

            if isgraphics(drag.rectHandle) && isprop(drag.rectHandle, 'FaceAlpha')
                drag.rectHandle.FaceAlpha = 0;
            end
        end

        function startDragNowLine(obj, app, lineHandle)
            %STARTDRAGNOWLINE Initialize drag state
            if ~isgraphics(lineHandle) || ~strcmp(get(lineHandle, 'Tag'), 'NowLine')
                primaryLine = findobj(app.ScheduleAxes, 'Tag', 'NowLine');
                if isempty(primaryLine)
                    return;
                end
                lineHandle = primaryLine(1);
            end

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

            % Validate line handle is still valid
            lineHandle = app.UIFigure.UserData.dragLineHandle;
            if ~isvalid(lineHandle)
                % Line was deleted, abort drag
                app.UIFigure.UserData.isDraggingNowLine = false;
                app.UIFigure.WindowButtonMotionFcn = [];
                app.UIFigure.WindowButtonUpFcn = [];
                app.UIFigure.Pointer = 'arrow';
                return;
            end

            % Get mouse position in axes coordinates
            pt = app.ScheduleAxes.CurrentPoint;
            newTimeHour = pt(1, 2); % Y-coordinate in axes

            % Constrain to schedule bounds
            yLimits = ylim(app.ScheduleAxes);
            newTimeHour = max(yLimits(1), min(yLimits(2), newTimeHour));

            % Update line position
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

            handleMarker = findobj(app.ScheduleAxes, 'Tag', 'NowHandle');
            if ~isempty(handleMarker)
                xLimits = xlim(app.ScheduleAxes);
                set(handleMarker, 'XData', xLimits(1), 'YData', newTimeHour);
            end

            shadowLine = findobj(app.ScheduleAxes, 'Tag', 'NowLineShadow');
            if ~isempty(shadowLine)
                shadowOffsetHours = 0.05;
                yLimits = ylim(app.ScheduleAxes);
                shadowY = min(yLimits(2), max(yLimits(1), newTimeHour + shadowOffsetHours));
                set(shadowLine, 'YData', [shadowY, shadowY]);
            end

            % Store current time (don't commit yet)
            lineHandle.UserData.timeMinutes = newTimeMinutes;
        end

        function endDragNowLine(obj, app)
            %ENDDRAGNOWLINE Finalize drag and update case statuses
            if ~isfield(app.UIFigure.UserData, 'isDraggingNowLine') || ~app.UIFigure.UserData.isDraggingNowLine
                return;
            end

            % Clear drag state first
            app.UIFigure.UserData.isDraggingNowLine = false;
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.UIFigure.Pointer = 'arrow';

            % Validate line handle is still valid
            lineHandle = app.UIFigure.UserData.dragLineHandle;
            if ~isvalid(lineHandle)
                % Line was deleted during drag, can't get final time
                return;
            end

            % Get final time
            finalTimeMinutes = lineHandle.UserData.timeMinutes;

            % Update CaseManager with new time
            app.CaseManager.setCurrentTime(finalTimeMinutes);

            % Auto-update case statuses based on new time
            updatedSchedule = obj.updateCaseStatusesByTime(app, finalTimeMinutes);

            % Store simulated schedule for re-rendering (e.g., when drawer opens)
            app.SimulatedSchedule = updatedSchedule;

            % Mark schedule as dirty (stale with new time)
            app.OptimizationController.markOptimizationDirty(app);

            % Re-render schedule to show updated statuses with fade effect
            app.ScheduleRenderer.renderOptimizedSchedule(app, updatedSchedule, app.OptimizationOutcome);

            % Keep NOW line draggable if time control is still active
            if app.IsTimeControlActive
                obj.enableNowLineDrag(app);
            end
        end

        function updatedSchedule = updateCaseStatusesByTime(~, app, currentTimeMinutes)
            %UPDATECASESTATUSESBYTIME Auto-update case statuses based on current time
            %   Returns a new DailySchedule with updated case statuses
            %   NOTE: This only updates visualization, not actual ProspectiveCase objects
            %         to avoid shifting case IDs during time control simulation

            if isempty(app.OptimizedSchedule)
                updatedSchedule = app.OptimizedSchedule;
                return;
            end

            % Reset lock state to baseline before applying time-control locks
            retainedLocks = app.LockedCaseIds;
            if ~isempty(app.TimeControlLockedCaseIds)
                retainedLocks = setdiff(retainedLocks, app.TimeControlLockedCaseIds);
            end

            if ~isempty(app.TimeControlBaselineLockedIds)
                retainedLocks = unique([retainedLocks(:); app.TimeControlBaselineLockedIds(:)], 'stable');
            end

            app.LockedCaseIds = retainedLocks;
            newTimeControlLocks = string.empty(0, 1);

            % Get case timing from schedule (copy for modification)
            labAssignments = app.OptimizedSchedule.labAssignments();

            for labIdx = 1:numel(labAssignments)
                labCases = labAssignments{labIdx};
                if isempty(labCases)
                    continue;
                end

                for caseIdx = 1:numel(labCases)
                    scheduledCase = labCases(caseIdx);

                    % Extract timing and case ID (coerce to scalar numeric values)
                    procStartTimeRaw = app.ScheduleRenderer.getFieldValue(scheduledCase, 'procStartTime', NaN);
                    procEndTimeRaw = app.ScheduleRenderer.getFieldValue(scheduledCase, 'procEndTime', NaN);
                    caseIdRaw = app.ScheduleRenderer.getFieldValue(scheduledCase, 'caseID', NaN);

                    procStartTime = coerceScalarNumeric(procStartTimeRaw);
                    procEndTime = coerceScalarNumeric(procEndTimeRaw);
                    caseIdStr = coerceStringIdentifier(caseIdRaw);

                    % Only require valid timing and a non-empty string case ID
                    if any(isnan([procStartTime, procEndTime])) || strlength(caseIdStr) == 0
                        continue;
                    end

                    % Determine simulated status based on time (visualization only)
                    newStatus = "";
                    shouldBeLocked = false;
                    if procEndTime <= currentTimeMinutes
                        % Case would be completed at this time
                        newStatus = "completed";
                        shouldBeLocked = true;

                        % Lock completed cases to preserve time and lab assignment
                        if ~ismember(caseIdStr, app.LockedCaseIds)
                            app.LockedCaseIds(end+1, 1) = caseIdStr;
                        end
                        if ~ismember(caseIdStr, app.TimeControlBaselineLockedIds) && ...
                                ~ismember(caseIdStr, newTimeControlLocks)
                            newTimeControlLocks(end+1, 1) = caseIdStr;
                        end
                    elseif procStartTime <= currentTimeMinutes && currentTimeMinutes < procEndTime
                        % Case would be in progress at this time
                        newStatus = "in_progress";
                        shouldBeLocked = true;

                        % Lock in-progress cases to preserve time and lab assignment
                        if ~ismember(caseIdStr, app.LockedCaseIds)
                            app.LockedCaseIds(end+1, 1) = caseIdStr;
                        end
                        if ~ismember(caseIdStr, app.TimeControlBaselineLockedIds) && ...
                                ~ismember(caseIdStr, newTimeControlLocks)
                            newTimeControlLocks(end+1, 1) = caseIdStr;
                        end
                    else
                        % Case would be pending at this time
                        newStatus = "pending";
                        shouldBeLocked = false;
                    end

                    % Update caseStatus in the schedule struct for visualization only
                    % Do NOT modify ProspectiveCase objects to keep case IDs stable
                    labAssignments{labIdx}(caseIdx).caseStatus = char(newStatus);

                    % PERSISTENT-ID: Update ProspectiveCase object status and lock for table display
                    % Use findCaseById instead of numeric index
                    if strlength(caseIdStr) > 0
                        [caseObj, ~] = app.CaseManager.findCaseById(caseIdStr);
                        if ~isempty(caseObj)
                            caseObj.CaseStatus = newStatus;
                            caseObj.IsLocked = shouldBeLocked;
                        end
                    end
                end
            end

            if ~isempty(app.LockedCaseIds)
                app.LockedCaseIds = unique(app.LockedCaseIds, 'stable');
            end

            app.TimeControlLockedCaseIds = unique(newTimeControlLocks, 'stable');

            % Update cases table to reflect status and lock changes
            app.updateCasesTable();

            % Create new DailySchedule with updated case statuses
            updatedSchedule = conduction.DailySchedule( ...
                app.OptimizedSchedule.Date, ...
                app.OptimizedSchedule.Labs, ...
                labAssignments, ...
                app.OptimizedSchedule.metrics());

            function value = coerceScalarNumeric(inputValue)
                %COERCESCALARNUMERIC Convert assorted inputs to scalar double or NaN
                value = NaN;

                if isempty(inputValue)
                    return;
                end

                if isnumeric(inputValue)
                    value = inputValue(1);
                    if isempty(value)
                        value = NaN;
                    end
                    return;
                end

                if iscell(inputValue)
                    try
                        flattened = [inputValue{:}];
                    catch
                        flattened = [];
                    end
                    value = coerceScalarNumeric(flattened);
                    return;
                end

                if isstring(inputValue)
                    num = str2double(inputValue(1));
                    if ~isnan(num)
                        value = num;
                    end
                    return;
                end

                if ischar(inputValue)
                    num = str2double(inputValue);
                    if ~isnan(num)
                        value = num;
                    end
                    return;
                end
            end

            function textId = coerceStringIdentifier(inputValue)
                %COERCESTRINGIDENTIFIER Produce a string identifier for case locking
                if isstring(inputValue)
                    textId = inputValue(1);
                    return;
                end

                if ischar(inputValue)
                    textId = string(inputValue);
                    return;
                end

                if isnumeric(inputValue) && ~isempty(inputValue)
                    textId = string(inputValue(1));
                    return;
                end

                if iscell(inputValue) && ~isempty(inputValue)
                    textId = coerceStringIdentifier(inputValue{1});
                    return;
                end

                textId = "";
            end
        end

        function updateActualTimeIndicator(obj, app)
            %UPDATEACTUALTIMEINDICATOR Draw or refresh the actual-time line
            ax = app.ScheduleAxes;
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            obj.clearActualTimeIndicator(app);

            if ~app.IsCurrentTimeVisible
                return;
            end

            actualTimeMinutes = obj.getActualCurrentTimeMinutes();
            if isnan(actualTimeMinutes)
                return;
            end

            currentTimeHour = actualTimeMinutes / 60;
            yLimits = ylim(ax);
            if isempty(yLimits) || currentTimeHour < yLimits(1) || currentTimeHour > yLimits(2)
                return;
            end

            xLimits = xlim(ax);

            lineHandle = line(ax, xLimits, [currentTimeHour, currentTimeHour], ...
                'Color', [1, 0, 0], 'LineStyle', '-', 'LineWidth', 2, ...
                'HitTest', 'off', 'Tag', 'ActualTimeLine');
            if isprop(lineHandle, 'PickableParts')
                lineHandle.PickableParts = 'none';
            end

            labelText = sprintf('Current (%s)', obj.minutesToTimeString(actualTimeMinutes));
            labelHandle = text(ax, xLimits(2) - 0.2, currentTimeHour - 0.1, labelText, ...
                'Color', [1, 0, 0], 'FontWeight', 'bold', 'FontSize', 10, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'BackgroundColor', [0, 0, 0], 'Tag', 'ActualTimeLabel');
            labelHandle.HitTest = 'off';
            if isprop(labelHandle, 'PickableParts')
                labelHandle.PickableParts = 'none';
            end
        end

        function clearActualTimeIndicator(~, app)
            %CLEARACTUALTIMEINDICATOR Remove existing actual-time line & label
            ax = app.ScheduleAxes;
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            delete(findobj(ax, 'Tag', 'ActualTimeLine'));
            delete(findobj(ax, 'Tag', 'ActualTimeLabel'));
        end

        function drawClosedLabOverlays(obj, app, dailySchedule)
            % Highlight labs that are unavailable for new assignments
            ax = app.ScheduleAxes;
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            delete(findobj(ax, 'Tag', 'ClosedLabOverlay'));

            labIds = app.LabIds;
            if isempty(labIds)
                return;
            end

            availableLabs = app.AvailableLabIds;
            if isempty(availableLabs)
                availableLabs = labIds;
            end

            closedLabs = setdiff(labIds, availableLabs);
            if isempty(closedLabs)
                return;
            end

            yLimits = ylim(ax);
            if numel(yLimits) ~= 2
                return;
            end

            assignments = {};
            if nargin >= 3 && ~isempty(dailySchedule)
                try
                    assignments = dailySchedule.labAssignments();
                catch
                    assignments = {};
                end
            end

            lockedIds = string(app.LockedCaseIds);
            lockedIds = lockedIds(lockedIds ~= "");

            restoreHold = ~ishold(ax);
            hold(ax, 'on');

            for labId = closedLabs(:)'
                closedStartHour = yLimits(1);

                if ~isempty(assignments) && labId >= 1 && labId <= numel(assignments) && ~isempty(lockedIds)
                    labCases = assignments{labId};
                    if ~isempty(labCases)
                        lastEndMinutes = NaN;
                        for idx = 1:numel(labCases)
                            caseEntry = labCases(idx);
                            caseIdentifier = string(obj.getFieldValue(caseEntry, 'caseID', ""));
                            if ismember(caseIdentifier, lockedIds)
                                procEnd = obj.getFieldValue(caseEntry, 'procEndTime', NaN);
                                postTime = obj.getFieldValue(caseEntry, 'postTime', NaN);
                                turnoverTime = obj.getFieldValue(caseEntry, 'turnoverTime', NaN);
                                if isnan(turnoverTime)
                                    turnoverTime = obj.getFieldValue(caseEntry, 'turnoverDuration', NaN);
                                end
                                if isnan(turnoverTime)
                                    turnoverTime = obj.getFieldValue(caseEntry, 'turnoverMinutes', NaN);
                                end

                                if isnan(postTime)
                                    postTime = 0;
                                end
                                if isnan(turnoverTime)
                                    turnoverTime = 0;
                                end

                                candidate = NaN;
                                if ~isnan(procEnd)
                                    candidate = procEnd + max(0, postTime) + max(0, turnoverTime);
                                end

                                if isnan(candidate)
                                    endTime = obj.getFieldValue(caseEntry, 'endTime', NaN);
                                    if ~isnan(endTime)
                                        candidate = endTime + max(0, turnoverTime);
                                    elseif ~isnan(procEnd)
                                        candidate = procEnd + max(0, turnoverTime);
                                    end
                                end

                                if ~isnan(candidate)
                                    if isnan(lastEndMinutes) || candidate > lastEndMinutes
                                        lastEndMinutes = candidate;
                                    end
                                end
                            end
                        end

                        if ~isnan(lastEndMinutes)
                            closedStartHour = max(lastEndMinutes / 60, yLimits(1));
                        end
                    end
                end

                closedEndHour = yLimits(2);
                if closedStartHour >= closedEndHour
                    continue;
                end

                xLeft = labId - 0.5;
                xRight = labId + 0.5;

                patchHandle = patch(ax, [xLeft xRight xRight xLeft], [closedStartHour closedStartHour closedEndHour closedEndHour], ...
                    [0.75 0.75 0.75], 'FaceAlpha', 0.16, 'EdgeColor', 'none', ...
                    'HitTest', 'off', 'Tag', 'ClosedLabOverlay');
                if isprop(patchHandle, 'PickableParts')
                    patchHandle.PickableParts = 'none';
                end

                if closedEndHour - closedStartHour > 0.1
                    if closedStartHour <= yLimits(1) + 1e-3
                        labelText = 'Closed (all day)';
                        labelHour = min(closedStartHour + 0.3, closedEndHour - 0.2);
                    else
                        labelText = sprintf('Closed after %s', obj.minutesToTimeString(closedStartHour * 60));
                        labelHour = min(closedStartHour + 0.3, closedEndHour - 0.2);
                    end

                    textHandle = text(ax, labId, labelHour, labelText, ...
                        'Color', [0.55 0.55 0.55], 'FontWeight', 'bold', 'FontSize', 8.5, ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                        'Clipping', 'on', 'HitTest', 'off', 'Tag', 'ClosedLabOverlay');
                    if isprop(textHandle, 'PickableParts')
                        textHandle.PickableParts = 'none';
                    end
                end
            end

            if restoreHold
                hold(ax, 'off');
            end
        end

    end

    methods (Access = private)

        function scheduleWasUpdated = applyCaseMove(obj, app, caseId, targetLabIndex, newSetupStartMinutes)
            scheduleWasUpdated = false;

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();
            labs = app.OptimizedSchedule.Labs;
            metrics = app.OptimizedSchedule.metrics();

            found = false;
            for labIdx = 1:numel(assignments)
                cases = assignments{labIdx};
                if isempty(cases)
                    continue;
                end
                for caseIdx = 1:numel(cases)
                    caseStruct = cases(caseIdx);
                    existingCaseId = string(obj.getFieldValue(caseStruct, 'caseID', ""));
                    if strlength(existingCaseId) == 0
                        existingCaseId = string(obj.getFieldValue(caseStruct, 'caseId', ""));
                    end
                    if existingCaseId == caseId
                        found = true;
                        originalStart = obj.getFieldValue(caseStruct, {'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime'}, obj.getFieldValue(caseStruct, 'procStartTime', NaN));
                        if isnan(originalStart)
                            originalStart = newSetupStartMinutes;
                        end
                        deltaMinutes = newSetupStartMinutes - originalStart;
                        caseStruct = obj.shiftCaseTimes(caseStruct, deltaMinutes);
                        if isfield(caseStruct, 'lab')
                            caseStruct.lab = targetLabIndex;
                        end
                        if isfield(caseStruct, 'labIndex')
                            caseStruct.labIndex = targetLabIndex;
                        end

                        cases(caseIdx) = [];
                        assignments{labIdx} = cases;

                        targetCases = assignments{targetLabIndex};
                        targetCases(end+1, 1) = caseStruct; %#ok<AGROW>
                        startTimes = arrayfun(@(s) obj.getFieldValue(s, {'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime', 'procStartTime'}, NaN), targetCases);
                        [~, order] = sort(startTimes, 'ascend', 'MissingPlacement', 'last');
                        assignments{targetLabIndex} = targetCases(order);

                        scheduleWasUpdated = true;
                        break;
                    end
                end
                if found
                    break;
                end
            end

            if ~found
                warning('ScheduleRenderer:CaseMoveFailed', 'Failed to locate case %s for drag operation.', caseId);
                return;
            end

            newSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, metrics);
            app.OptimizedSchedule = newSchedule;

            if ~ismember(caseId, app.LockedCaseIds)
                app.LockedCaseIds(end+1, 1) = caseId;
                app.LockedCaseIds = unique(app.LockedCaseIds, 'stable');
            end
        end

        function tf = isCaseBlockDraggable(~, app, caseId)
            tf = false;
            if isempty(caseId)
                return;
            end

            if app.IsOptimizationRunning || app.IsTimeControlActive
                return;
            end

            [caseObj, ~] = app.CaseManager.findCaseById(caseId);
            if isempty(caseObj)
                return;
            end

            tf = caseObj.isPending();
        end

        function invokeCaseBlockClick(~, app, rectHandle)
            if isempty(rectHandle) || ~isgraphics(rectHandle)
                return;
            end

            userData = get(rectHandle, 'UserData');
            callback = [];
            caseId = "";

            if isstruct(userData)
                if isfield(userData, 'caseClickedFcn')
                    callback = userData.caseClickedFcn;
                end
                if isfield(userData, 'caseId')
                    caseId = string(userData.caseId);
                end
            end

            if isempty(callback)
                if strlength(caseId) > 0
                    app.onScheduleBlockClicked(caseId);
                end
                return;
            end

            try
                callback(caseId);
            catch ME
                warning('ScheduleRenderer:CaseClickFailed', 'Case click handler failed: %s', ME.message);
            end
        end

        function caseStruct = shiftCaseTimes(~, caseStruct, deltaMinutes)
            if deltaMinutes == 0
                return;
            end

            fieldsToShift = {
                'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime', ...
                'procStartTime', 'procedureStartTime', 'procEndTime', 'procedureEndTime', ...
                'postStartTime', 'postEndTime', 'turnoverStartTime', 'turnoverEnd', ...
                'endTime', 'caseEndTime', 'scheduleEnd'
            };

            for idx = 1:numel(fieldsToShift)
                fieldName = fieldsToShift{idx};
                if isfield(caseStruct, fieldName) && ~isempty(caseStruct.(fieldName))
                    caseStruct.(fieldName) = caseStruct.(fieldName) + deltaMinutes;
                end
            end
        end

        function showCaseDragWarning(~, app, message)
            if isempty(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            uialert(app.UIFigure, message, 'Case Drag', 'Icon', 'warning');
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
            %MINUTESTOTIMESTRING Convert minutes from midnight to HH:MM (24-hour format)
            if isnan(minutes)
                timeStr = 'N/A';
                return;
            end

            % Round to nearest minute
            minutes = round(minutes);

            hours = floor(minutes / 60);
            mins = mod(minutes, 60);

            % 24-hour format
            timeStr = sprintf('%02d:%02d', mod(hours, 24), mins);
        end

        function minutes = getActualCurrentTimeMinutes()
            %GETACTUALCURRENTTIMEMINUTES Return current clock time in minutes from midnight
            nowTime = datetime('now');
            minutes = hour(nowTime) * 60 + minute(nowTime) + second(nowTime) / 60;
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
