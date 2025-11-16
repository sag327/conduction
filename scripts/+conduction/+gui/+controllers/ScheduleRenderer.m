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

            % UNIFIED-TIMELINE: Always enable NOW line drag
            obj.enableNowLineDrag(app);

            obj.enableCaseDrag(app);
        obj.applyMultiSelectionHighlights(app);

        conduction.gui.renderers.ResourceOverlayRenderer.clear(app);

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

            % debug logs removed

            app.syncCaseScheduleFields(dailySchedule);

            % Use fade effect if schedule is stale/dirty
            fadeAlpha = 1.0;  % Default: full opacity
            if app.IsOptimizationDirty
                fadeAlpha = 0.35;  % Faded when stale (35% opacity)
            end

            % UNIFIED-TIMELINE: Always render NOW line (use app.NowPositionMinutes)
            currentTime = app.getNowPosition();

            % Build locked case ids on demand from per-case flags and NOW-derived auto-lock
            lockedIds = string.empty(0,1);
            try
                if ~isempty(app.CaseManager) && app.CaseManager.CaseCount > 0
                    for i = 1:app.CaseManager.CaseCount
                        c = app.CaseManager.getCase(i);
                        if c.getComputedLock(currentTime)
                            lockedIds(end+1,1) = c.CaseId; %#ok<AGROW>
                        end
                    end
                end
            catch
                lockedIds = string.empty(0,1);
            end

            % Detect and cache overlapping cases before rendering
            app.OverlappingCaseIds = obj.detectOverlappingCases(app);

            app.OperatorColors = conduction.visualizeDailySchedule(dailySchedule, ...
                'Title', 'Optimized Schedule', ...
                'ScheduleAxes', app.ScheduleAxes, ...
                'ShowLabels', true, ...
                'CaseClickedFcn', @(caseId) app.onScheduleBlockClicked(caseId), ...
                'BackgroundClickedFcn', @() app.onScheduleBackgroundClicked(), ...
                'LockedCaseIds', lockedIds, ...
                'SelectedCaseId', "", ...
                'OperatorColors', app.OperatorColors, ...
                'FadeAlpha', fadeAlpha, ...
                'CurrentTimeMinutes', currentTime, ... % REALTIME-SCHEDULING
                'OverlappingCaseIds', app.OverlappingCaseIds);

            obj.drawClosedLabOverlays(app, dailySchedule);

            % Always fetch fresh resource metadata from authoritative sources
            % This prevents stale data issues when loading sessions
            resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            resourceSummary = struct('ResourceId', {}, 'CaseIds', {});

            if ~isempty(app.CaseManager) && isvalid(app.CaseManager)
                resourceStore = app.CaseManager.getResourceStore();
                if ~isempty(resourceStore) && isvalid(resourceStore)
                    resourceTypes = resourceStore.snapshot();
                end
                resourceSummary = app.CaseManager.caseResourceSummary();
            end

            app.updateResourceLegendContents(resourceTypes, resourceSummary);
            obj.refreshResourceHighlightsForAxes(app, app.ScheduleAxes, dailySchedule, resourceTypes);


            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            app.AnalyticsRenderer.updateKPIBar(app, dailySchedule);

            % Update optional actual time indicator after schedule renders
            app.ScheduleRenderer.updateActualTimeIndicator(app);

            % UNIFIED-TIMELINE: Always enable NOW line drag
            obj.enableNowLineDrag(app);

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.AnalyticsRenderer.drawUtilization(app, app.UtilAxes);
                app.AnalyticsRenderer.drawFlipMetrics(app, app.FlipAxes);
                app.AnalyticsRenderer.drawIdleMetrics(app, app.IdleAxes);
            end

            % Bind drag after everything is drawn
            obj.enableCaseDrag(app);
            obj.applyMultiSelectionHighlights(app);
        end

        function refreshResourceHighlights(obj, app)
            % Ensure we have a valid axes to draw on
            if isempty(app) || ~isprop(app, 'ScheduleAxes') || isempty(app.ScheduleAxes) || ~isvalid(app.ScheduleAxes)
                return;
            end

            scheduleForRender = app.getScheduleForRendering();
            if isempty(scheduleForRender)
                conduction.gui.renderers.ResourceOverlayRenderer.clear(app.ScheduleAxes);
                return;
            end

            resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            try
                if ~isempty(app.LastResourceMetadata) && isfield(app.LastResourceMetadata, 'resourceTypes')
                    resourceTypes = app.LastResourceMetadata.resourceTypes;
                end
            catch
            end

            obj.refreshResourceHighlightsForAxes(app, app.ScheduleAxes, scheduleForRender, resourceTypes);
        end

        function refreshProposedResourceHighlights(obj, app, annotatedSchedule)
            if isempty(app) || ~isprop(app, 'ProposedAxes') || isempty(app.ProposedAxes) || ~isvalid(app.ProposedAxes)
                return;
            end

            if nargin < 3 || isempty(annotatedSchedule)
                if isempty(app.ProposedSchedule)
                    conduction.gui.renderers.ResourceOverlayRenderer.clear(app.ProposedAxes);
                    return;
                end
                annotatedSchedule = obj.annotateScheduleWithDerivedStatus(app, app.ProposedSchedule);
            end

            resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            try
                if ~isempty(app.LastResourceMetadata) && isfield(app.LastResourceMetadata, 'resourceTypes')
                    resourceTypes = app.LastResourceMetadata.resourceTypes;
                end
            catch
            end
            if isempty(resourceTypes)
                resourceTypes = obj.collectResourceTypes(app);
            end

            obj.refreshResourceHighlightsForAxes(app, app.ProposedAxes, annotatedSchedule, resourceTypes);
        end

        function refreshAllResourceHighlights(obj, app)
            obj.refreshResourceHighlights(app);
            obj.refreshProposedResourceHighlights(app);
        end

        function refreshResourceHighlightsForAxes(obj, app, axesHandle, schedule, resourceTypes)
            if nargin < 5
                resourceTypes = obj.collectResourceTypes(app);
            end
            if isempty(axesHandle) || ~isvalid(axesHandle)
                return;
            end
            if nargin < 4 || isempty(schedule) || ~isa(schedule, 'conduction.DailySchedule')
                conduction.gui.renderers.ResourceOverlayRenderer.clear(axesHandle);
                return;
            end

            highlightIds = string(app.ResourceHighlightIds);
            conduction.gui.renderers.ResourceOverlayRenderer.draw(axesHandle, schedule, resourceTypes, highlightIds);
        end

        function resourceTypes = collectResourceTypes(~, app)
            resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            if isempty(app) || isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end
            store = app.CaseManager.getResourceStore();
            if isempty(store) || ~isvalid(store)
                return;
            end
            resourceTypes = store.snapshot();
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

            if ~isempty(app.CaseDragController)
                app.CaseDragController.hideSoftHighlight();
            end

            caseBlocks = findobj(app.ScheduleAxes, 'Tag', 'CaseBlock');
            if isempty(caseBlocks)
                if ~isempty(app.CaseDragController)
                    app.CaseDragController.hideSelectionOverlay(false);
                    app.CaseDragController.clearRegistry();
                end
                return;
            end

            if ~isempty(app.CaseDragController)
                app.CaseDragController.registerCaseBlocks(app, caseBlocks);
            end
            for idx = 1:numel(caseBlocks)
                blockHandle = caseBlocks(idx);
                if ~isgraphics(blockHandle)
                    continue;
                end
                set(blockHandle, 'ButtonDownFcn', @(src, ~) obj.onCaseBlockMouseDown(app, src));
                try, uistack(blockHandle, 'top'); catch, end
            end

        end

        function onCaseBlockMouseDown(obj, app, rectHandle)
            %ONCASEBLOCKMOUSEDOWN Entry point for case drag or click
            if ~isgraphics(rectHandle)
                return;
            end
            % When multi-select is active, we allow selection clicks but block
            % drag initiation. We attach a lightweight motion guard that
            % shows a warning only if the user actually moves the mouse.
            if ismethod(app, 'isMultiSelectActive') && app.isMultiSelectActive()
                % Arm a transient guard to differentiate click vs drag while
                % multi-select remains active. Do not change selection yet.
                obj.setupMultiSelectDragGuard(app, rectHandle);
                return;
            end
            caseEntry = struct();
            if ~isempty(app.CaseDragController)
                [resolvedEntry, ~] = app.CaseDragController.findCaseByHandle(rectHandle);
                if ~isempty(resolvedEntry)
                    caseEntry = resolvedEntry;
                end
            end
            obj.startDragCase(app, rectHandle, caseEntry);
        end

        function setupMultiSelectDragGuard(obj, app, rectHandle)
            if isempty(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            fig = app.UIFigure;
            % Record starting point in axes data units and the target handle
            startPt = [NaN NaN];
            try
                cp = get(app.ScheduleAxes, 'CurrentPoint');
                if ~isempty(cp)
                    startPt = cp(1,1:2);
                end
            catch
            end
            % Compute small pixel thresholds in data units (≈3px)
            xThresh = 0; yThresh = 0;
            try
                if ~isempty(app.CaseDragController)
                    [xThresh, yThresh] = app.CaseDragController.pointsToDataOffsets(app.ScheduleAxes, 3);
                else
                    oldUnits = app.ScheduleAxes.Units; app.ScheduleAxes.Units = 'pixels';
                    pos = app.ScheduleAxes.Position; app.ScheduleAxes.Units = oldUnits;
                    xl = xlim(app.ScheduleAxes); yl = ylim(app.ScheduleAxes);
                    xThresh = max( (3/max(1,pos(3))) * abs(diff(xl)), eps );
                    yThresh = max( (3/max(1,pos(4))) * abs(diff(yl)), eps );
                end
            catch
                xThresh = 0; yThresh = 0;
            end

            % Suspend hover watcher to avoid handler contention
            hoverSuspended = false;
            try
                if ~isempty(app.CaseDragController)
                    app.CaseDragController.disableSelectionHoverWatcher();
                    hoverSuspended = true;
                end
            catch
            end

            guard = struct('startPoint', startPt, 'rectHandle', rectHandle, 'moved', false, ...
                           'xThresh', xThresh, 'yThresh', yThresh, 'hoverSuspended', hoverSuspended);
            fig.UserData.msSelectGuard = guard;
            % Install transient handlers; they will clear themselves on first motion/up
            fig.WindowButtonMotionFcn = @(~,~) obj.guardMultiSelectDragAttempt(app);
            fig.WindowButtonUpFcn = @(~,~) obj.finalizeMultiSelectClick(app);
            % Guard installed with thresholds; wait for motion or mouse-up
        end

        function guardMultiSelectDragAttempt(obj, app)
            if isempty(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            % Only warn if multi-select still active at the time of motion
            if ismethod(app, 'isMultiSelectActive') && app.isMultiSelectActive()
                try
                    guard = app.UIFigure.UserData.msSelectGuard;
                catch
                    guard = struct();
                end
                moved = true; dx=NaN; dy=NaN;
                try
                    cp = get(app.ScheduleAxes, 'CurrentPoint');
                    cp = cp(1,1:2);
                    if isfield(guard, 'startPoint') && numel(guard.startPoint) == 2
                        dx = abs(cp(1) - guard.startPoint(1));
                        dy = abs(cp(2) - guard.startPoint(2));
                        xThresh = 0; yThresh = 0;
                        if isfield(guard, 'xThresh'), xThresh = guard.xThresh; end
                        if isfield(guard, 'yThresh'), yThresh = guard.yThresh; end
                        moved = isfinite(dx) && isfinite(dy) && (dx > xThresh || dy > yThresh);
                    end
                catch
                    % Default: consider as moved
                    moved = true;
                end

                if moved
                    % Mark and warn once
                    guard.moved = true;
                    app.UIFigure.UserData.msSelectGuard = guard;
                    obj.showCaseDragWarning(app, 'Drag disabled while multiple cases are selected.');
                    % Clear handlers now that we've handled a true drag attempt
                    obj.clearTransientMouseHandlers(app);
                end
                return; % Keep handlers active until moved or mouse-up
            end
            % Not in multi-select anymore: clear transient handlers
            obj.clearTransientMouseHandlers(app);
        end

        function finalizeMultiSelectClick(obj, app)
            if isempty(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            % On mouse up with no motion, perform the selection click now
            try
                guard = app.UIFigure.UserData.msSelectGuard;
            catch
                guard = struct();
            end
            if isfield(guard, 'moved') && ~guard.moved && isfield(guard, 'rectHandle') && isgraphics(guard.rectHandle)
                % Still OK to perform selection click
                obj.invokeCaseBlockClick(app, guard.rectHandle);
            end
            obj.clearTransientMouseHandlers(app);
        end

        function clearTransientMouseHandlers(obj, app)
            if isempty(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            % Clear guard
            try
                guard = app.UIFigure.UserData.msSelectGuard;
                app.UIFigure.UserData.msSelectGuard = [];
                if isfield(guard,'hoverSuspended') && guard.hoverSuspended && ~isempty(app.CaseDragController)
                    try
                        app.CaseDragController.enableSelectionHoverWatcher();
                    catch
                    end
                end
            catch
            end
        end

        function startDragCase(obj, app, rectHandle, caseEntry)
            %STARTDRAGCASE Begin dragging a case overlay
            if nargin < 4
                caseEntry = struct();
            end

            dragController = app.CaseDragController;
            ud = struct();
            caseId = "";

            if ~isempty(caseEntry)
                if isfield(caseEntry, 'userData') && isstruct(caseEntry.userData)
                    ud = caseEntry.userData;
                end
                if isfield(caseEntry, 'caseId')
                    caseId = string(caseEntry.caseId);
                end
            end

            if isempty(fieldnames(ud))
                ud = get(rectHandle, 'UserData');
            end
            if strlength(caseId) == 0 && isstruct(ud) && isfield(ud, 'caseId')
                caseId = string(ud.caseId);
            end

            if ~isstruct(ud) || ~isfield(ud, 'caseId') || strlength(caseId) == 0
                if ~isempty(dragController)
                    dragController.hideSoftHighlight();
                end
                obj.restoreSelectionOverlay(app);
                obj.invokeCaseBlockClick(app, rectHandle);
                return;
            end

            if ~isempty(dragController)
                dragController.hideSelectionOverlay(false);
                dragController.showSoftHighlight(app.ScheduleAxes, rectHandle);
            end

            allowTimeControlEdits = false;
            if isprop(app, 'AllowEditInTimeControl')
                try
                    allowTimeControlEdits = logical(app.AllowEditInTimeControl);
                catch
                    allowTimeControlEdits = false;
                end
            end
            timeControlActive = isprop(app, 'IsTimeControlActive') && app.IsTimeControlActive;

            if app.IsOptimizationRunning || (timeControlActive && ~allowTimeControlEdits)
                if ~isempty(dragController)
                    dragController.hideSoftHighlight();
                end
                obj.restoreSelectionOverlay(app);
                obj.invokeCaseBlockClick(app, rectHandle);
                return;
            end

            if ~obj.isCaseBlockDraggable(app, caseId)
                if ~isempty(dragController)
                    dragController.hideSoftHighlight();
                end
                obj.restoreSelectionOverlay(app);
                obj.invokeCaseBlockClick(app, rectHandle);
                return;
            end

            % Do NOT re-render during mousedown; it would destroy the overlay and cancel drag

            drag.rectHandle = rectHandle;
            drag.caseId = caseId;
            drag.originalLabIndex = double(obj.extractField(ud, 'labIndex', NaN));

            originalSetupStart = obj.extractField(ud, 'setupStart', NaN);
            if isnan(originalSetupStart)
                originalSetupStart = obj.extractField(ud, 'procStart', NaN);
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
            drag.caseClickedFcn = obj.extractField(ud, 'caseClickedFcn', []);
            drag.availableLabIds = app.AvailableLabIds;
            drag.startPoint = get(app.ScheduleAxes, 'CurrentPoint');
            if ~isempty(drag.startPoint)
                drag.startPoint = drag.startPoint(1, 1:2);
            else
                drag.startPoint = [NaN, NaN];
            end

            % Preserve the vertical offset from the rectangle's bottom to the
            % initial mouse click so the block doesn't jump toward the cursor.
            try
                rectPos = get(rectHandle, 'Position');
            catch
                rectPos = [NaN NaN NaN NaN];
            end
            if numel(rectPos) ~= 4 || any(~isfinite(rectPos)) || any(~isfinite(drag.startPoint))
                drag.cursorOffsetHours = drag.rectHeight / 2; % safe fallback
            else
                clickOffset = drag.startPoint(2) - rectPos(2);
                % Clamp to [0, rectHeight] so we stay within the block
                clickOffset = max(0, min(drag.rectHeight, clickOffset));
                drag.cursorOffsetHours = clickOffset;
            end

            if isprop(rectHandle, 'FaceAlpha') && rectHandle.FaceAlpha == 0
                rectHandle.FaceAlpha = 0.1;
            end

            if ~isempty(dragController)
                dragController.setActiveDrag(drag);
            end

            obj.pauseNowTimerForEdit(app);

            app.UIFigure.Pointer = 'fleur';
            app.UIFigure.WindowButtonMotionFcn = @(~, ~) obj.updateDragCase(app);
            app.UIFigure.WindowButtonUpFcn = @(~, ~) obj.endDragCase(app);
        end

        function updateDragCase(obj, app)
            %UPDATEDRAGCASE Update overlay during drag motion
            dragController = app.CaseDragController;
            if isempty(dragController) || ~dragController.hasActiveDrag()
                return;
            end

            drag = dragController.getActiveDrag();
            if isempty(drag) || ~isfield(drag, 'rectHandle') || ~isgraphics(drag.rectHandle)
                return;
            end

            if dragController.shouldThrottleMotion()
                return;
            end

            currentPoint = get(app.ScheduleAxes, 'CurrentPoint');
            currentPoint = currentPoint(1, 1:2);

            numLabs = numel(app.LabIds);
            newLabIndex = round(currentPoint(1));
            newLabIndex = max(1, min(numLabs, newLabIndex));

            durationHours = drag.rectHeight;
            yLimits = ylim(app.ScheduleAxes);
            % Compute new bottom-left Y by subtracting the preserved click offset
            % so the block drags naturally from its current position.
            newBottomHour = currentPoint(2) - drag.cursorOffsetHours;
            newBottomHour = max(yLimits(1), min(yLimits(2) - durationHours, newBottomHour));

            snapMinutes = max(1, drag.snapMinutes);
            newStartMinutes = round((newBottomHour * 60) / snapMinutes) * snapMinutes;
            newStartHour = newStartMinutes / 60;

            newLeft = newLabIndex - drag.rectWidth / 2;
            newPosition = [newLeft, newStartHour, drag.rectWidth, drag.rectHeight];

            set(drag.rectHandle, 'Position', newPosition);
            dragController.moveSoftHighlight(newPosition);

            movedInTime = abs(newStartMinutes - drag.originalSetupStart) >= snapMinutes / 2;
            movedInLab = newLabIndex ~= drag.originalLabIndex;
            drag.hasMoved = drag.hasMoved || movedInTime || movedInLab;
            drag.targetLabIndex = newLabIndex;
            drag.targetStartMinutes = newStartMinutes;

            dragController.setActiveDrag(drag);
            dragController.markMotionUpdate();
        end

        function endDragCase(obj, app)
            %ENDDRAGCASE Finalize drag operation
            dragController = app.CaseDragController;
            if isempty(dragController)
                return;
            end

            dragController.hideSoftHighlight();

            if ~dragController.hasActiveDrag()
                obj.restoreSelectionOverlay(app);
                return;
            end

            drag = dragController.getActiveDrag();

            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.UIFigure.Pointer = 'arrow';
            dragController.clearActiveDrag();
            obj.resumeNowTimerAfterEdit(app);
            dragController.enableSelectionHoverWatcher();

            if ~isgraphics(drag.rectHandle)
                return;
            end

            if ~drag.hasMoved
                set(drag.rectHandle, 'Position', drag.originalPosition);
                if isprop(drag.rectHandle, 'FaceAlpha')
                    drag.rectHandle.FaceAlpha = 0;
                end
                obj.invokeCaseBlockClick(app, drag.rectHandle);
                % Note: restoreSelectionOverlay not needed here because invokeCaseBlockClick
                % triggers selection change which calls updateCaseSelectionVisuals -> showSelectionOverlay
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
                obj.restoreSelectionOverlay(app);
                return;
            end

            newSetupStartMinutes = drag.targetStartMinutes;
            if isnan(newSetupStartMinutes)
                set(drag.rectHandle, 'Position', drag.originalPosition);
                obj.invokeCaseBlockClick(app, drag.rectHandle);
                % Note: restoreSelectionOverlay not needed here because invokeCaseBlockClick
                % triggers selection change which calls updateCaseSelectionVisuals -> showSelectionOverlay
                return;
            end

            scheduleWasUpdated = obj.applyCaseMove(app, drag.caseId, targetLabIndex, newSetupStartMinutes);
            if scheduleWasUpdated
                app.OptimizationController.markOptimizationDirty(app);
                app.updateCasesTable();
                if strlength(app.DrawerCurrentCaseId) > 0 && app.DrawerCurrentCaseId == drag.caseId && ...
                        app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                    app.DrawerController.populateDrawer(app, drag.caseId);
                end
                % Note: restoreSelectionOverlay not needed here because markOptimizationDirty
                % triggers full re-render which calls registerCaseBlocks -> showSelectionOverlay
            else
                set(drag.rectHandle, 'Position', drag.originalPosition);
                if isprop(drag.rectHandle, 'FaceAlpha')
                    drag.rectHandle.FaceAlpha = 0;
                end
                % Restore overlay after failed drag (no re-render happened)
                obj.restoreSelectionOverlay(app);
            end

            if isgraphics(drag.rectHandle) && isprop(drag.rectHandle, 'FaceAlpha')
                drag.rectHandle.FaceAlpha = 0;
            end
        end

        function onCaseResizeMouseDown(obj, app, handle)
            if ~isgraphics(handle)
                return;
            end

            if ismethod(app, 'isMultiSelectActive') && app.isMultiSelectActive()
                obj.showCaseDragWarning(app, 'Resize disabled while multiple cases are selected.');
                obj.restoreSelectionOverlay(app);
                return;
            end

            dragController = app.CaseDragController;
            if isempty(dragController)
                return;
            end

            try
                ud = get(handle, 'UserData');
            catch
                return;
            end

            if ~isstruct(ud) || ~isfield(ud, 'caseId')
                return;
            end

            caseId = string(ud.caseId);
            if strlength(caseId) == 0
                return;
            end

            allowTimeControlEdits = false;
            if isprop(app, 'AllowEditInTimeControl')
                try
                    allowTimeControlEdits = logical(app.AllowEditInTimeControl);
                catch
                    allowTimeControlEdits = false;
                end
            end
            timeControlActive = isprop(app, 'IsTimeControlActive') && app.IsTimeControlActive;

            if app.IsOptimizationRunning || (timeControlActive && ~allowTimeControlEdits)
                obj.restoreSelectionOverlay(app);
                return;
            end

            if ~obj.isCaseBlockDraggable(app, caseId)
                obj.restoreSelectionOverlay(app);
                return;
            end

            caseRect = [];
            if isfield(ud, 'caseRect') && isgraphics(ud.caseRect)
                caseRect = ud.caseRect;
            else
                caseRect = obj.findCaseBlockHandle(app.ScheduleAxes, caseId);
            end
            if isempty(caseRect) || ~isgraphics(caseRect)
                return;
            end

            resize.originalCaseRectPos = get(caseRect, 'Position');
            resize.caseRectHandle = caseRect;
            resize.handleRect = handle;
            resize.caseId = caseId;
            resize.labIndex = obj.extractField(ud, 'labIndex', NaN);
            resize.snapMinutes = obj.extractField(ud, 'snapMinutes', 5);
            resize.originalProcStart = obj.extractField(ud, 'procStart', NaN);
            resize.originalProcEnd = obj.extractField(ud, 'procEnd', NaN);
            resize.setupStartMinutes = obj.extractField(ud, 'setupStart', NaN);
            resize.postDuration = obj.extractField(ud, 'postDuration', 0);
            if isnan(resize.postDuration)
                resize.postDuration = 0;
            end
            resize.turnoverDuration = obj.extractField(ud, 'turnoverDuration', 0);
            if isnan(resize.turnoverDuration)
                resize.turnoverDuration = 0;
            end
            resize.handleHeightHours = obj.extractField(ud, 'handleHeightHours', 0.08);
            resize.originalHandlePos = get(handle, 'Position');
            resize.minProcDuration = max(1, resize.snapMinutes);  % minutes
            resize.currentProcEnd = resize.originalProcEnd;
            resize.hasResized = false;

            if ~isfinite(resize.originalProcStart) || ~isfinite(resize.originalProcEnd)
                return;
            end

            dragController.hideSelectionOverlay(false);
            dragController.showSoftHighlight(app.ScheduleAxes, caseRect);
            dragController.setActiveResize(resize);
            dragController.clearActiveDrag();
            dragController.markMotionUpdate();

            obj.pauseNowTimerForEdit(app);

            app.UIFigure.Pointer = 'crosshair';
            app.UIFigure.WindowButtonMotionFcn = @(~, ~) obj.updateResizeCase(app);
            app.UIFigure.WindowButtonUpFcn = @(~, ~) obj.endResizeCase(app);
        end

        function updateResizeCase(obj, app)
            dragController = app.CaseDragController;
            if isempty(dragController) || ~dragController.hasActiveResize()
                return;
            end

            resize = dragController.getActiveResize();
            if isempty(resize) || ~isfield(resize, 'caseRectHandle') || ~isgraphics(resize.caseRectHandle)
                return;
            end

            if dragController.shouldThrottleMotion()
                return;
            end

            currentPoint = get(app.ScheduleAxes, 'CurrentPoint');
            currentPoint = currentPoint(1, 1:2);

            yLimits = ylim(app.ScheduleAxes);
            newProcEndHour = min(max(currentPoint(2), resize.setupStartMinutes/60), yLimits(2));
            newProcEndMinutes = round((newProcEndHour * 60) / resize.snapMinutes) * resize.snapMinutes;
            minProcEnd = resize.originalProcStart + resize.minProcDuration;
            if newProcEndMinutes < minProcEnd
                newProcEndMinutes = minProcEnd;
            end

            maxProcEndMinutes = yLimits(2) * 60;
            if newProcEndMinutes > maxProcEndMinutes
                newProcEndMinutes = maxProcEndMinutes;
            end

            if newProcEndMinutes < resize.originalProcStart
                newProcEndMinutes = resize.originalProcStart + resize.minProcDuration;
            end

            procDurationMinutes = newProcEndMinutes - resize.originalProcStart;
            postDurationMinutes = max(0, resize.postDuration);
            turnoverDurationMinutes = max(0, resize.turnoverDuration);
            totalDurationMinutes = procDurationMinutes + postDurationMinutes + turnoverDurationMinutes;
            caseStartHour = resize.setupStartMinutes / 60;
            totalDurationHours = totalDurationMinutes / 60;

            caseRectPos = resize.originalCaseRectPos;
            caseRectPos(2) = caseStartHour;
            caseRectPos(4) = totalDurationHours;
            set(resize.caseRectHandle, 'Position', caseRectPos);

            if isgraphics(resize.handleRect)
                handleHeight = resize.handleHeightHours;
                handleBottom = (newProcEndMinutes / 60) - handleHeight;
                handleBottom = max(caseStartHour, handleBottom);
                handleHeight = (newProcEndMinutes / 60) - handleBottom;
                handlePos = [caseRectPos(1), handleBottom, caseRectPos(3), handleHeight];
                set(resize.handleRect, 'Position', handlePos);
                resize.handleHeightHours = handleHeight;
            end

            dragController.moveSoftHighlight(caseRectPos);

            resize.currentProcEnd = newProcEndMinutes;
            resize.hasResized = resize.hasResized || abs(newProcEndMinutes - resize.originalProcEnd) >= (resize.snapMinutes / 2);
            dragController.setActiveResize(resize);
            dragController.markMotionUpdate();
        end

        function endResizeCase(obj, app)
            dragController = app.CaseDragController;
            if isempty(dragController)
                return;
            end

            resizeWasActive = dragController.hasActiveResize();
            resize = dragController.getActiveResize();

            dragController.hideSoftHighlight();
            dragController.clearActiveResize();
            if resizeWasActive
                obj.resumeNowTimerAfterEdit(app);
            end

            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.UIFigure.Pointer = 'arrow';
            dragController.enableSelectionHoverWatcher();

            if ~resizeWasActive
                obj.restoreSelectionOverlay(app);
                return;
            end

            if ~resize.hasResized || ~isfield(resize, 'currentProcEnd')
                if isfield(resize, 'caseRectHandle') && isgraphics(resize.caseRectHandle)
                    set(resize.caseRectHandle, 'Position', resize.originalCaseRectPos);
                end
                if isfield(resize, 'handleRect') && isgraphics(resize.handleRect)
                    set(resize.handleRect, 'Position', resize.originalHandlePos);
                end
                obj.restoreSelectionOverlay(app);
                return;
            end

            newProcEndMinutes = resize.currentProcEnd;
            caseId = resize.caseId;

            caseUpdated = obj.applyCaseResize(app, caseId, newProcEndMinutes);
            if ~caseUpdated
                if isfield(resize, 'caseRectHandle') && isgraphics(resize.caseRectHandle)
                    set(resize.caseRectHandle, 'Position', resize.originalCaseRectPos);
                end
                if isfield(resize, 'handleRect') && isgraphics(resize.handleRect)
                    set(resize.handleRect, 'Position', resize.originalHandlePos);
                end
                % Restore overlay after failed resize (no re-render happened)
                obj.restoreSelectionOverlay(app);
            else
                if strlength(app.DrawerCurrentCaseId) > 0 && app.DrawerCurrentCaseId == caseId && ...
                        app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                    app.DrawerController.populateDrawer(app, caseId);
                end
                % Note: restoreSelectionOverlay not needed here because applyCaseResize
                % calls markOptimizationDirty which triggers full re-render → registerCaseBlocks → showSelectionOverlay
            end
        end

        function updateCaseDragDebugLabel(~, app, textValue)
            try
                ax = app.ScheduleAxes;
                if isempty(ax) || ~isvalid(ax)
                    return;
                end
                existing = findobj(ax, 'Tag', 'CaseDragDebug');
                xLimits = xlim(ax); yLimits = ylim(ax);
                posX = xLimits(2) - 0.1; posY = yLimits(2) - 0.2;
                if isempty(existing)
                    t = text(ax, posX, posY, textValue, 'Tag', 'CaseDragDebug');
                    t.HorizontalAlignment = 'right';
                    t.VerticalAlignment = 'top';
                    t.FontSize = 8;
                    t.Color = [0.8 0.8 0.8];
                    t.BackgroundColor = [0.2 0.2 0.2];
                    t.Margin = 3;
                    t.HitTest = 'off';
                    if isprop(t, 'PickableParts'), t.PickableParts = 'none'; end
                else
                    existing.String = textValue;
                    existing.Position(1:2) = [posX, posY];
                end
            catch
                % swallow debug errors
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

            % UNIFIED-TIMELINE: Update NOW position in app state
            app.setNowPosition(finalTimeMinutes);

            % Auto-update case statuses based on new time
            updatedSchedule = obj.updateCaseStatusesByTime(app, finalTimeMinutes);

            % Check if any case statuses actually changed
            statusesChanged = obj.didCaseStatusesChange(app.OptimizedSchedule, updatedSchedule);

            % Mark schedule as dirty only if statuses changed (shows fade effect)
            if statusesChanged
                % Mark optimization dirty but don't mark session dirty yet
                app.OptimizationController.markOptimizationDirty(app, false);
            end

            % Always mark session dirty because time position is saved state
            % (even if no statuses changed, the time position itself changed)
            app.markDirty();

            % Re-render schedule to show updated statuses
            % (with fade effect if statusesChanged=true, otherwise normal)
            app.ScheduleRenderer.renderOptimizedSchedule(app, updatedSchedule, app.OptimizationOutcome);

            % UNIFIED-TIMELINE: Ensure NOW line remains draggable after re-render
            % (renderOptimizedSchedule already enables it, but keep for robustness)
            obj.enableNowLineDrag(app);

            if ismethod(app, 'refreshOptimizeButtonLabel')
                app.refreshOptimizeButtonLabel();
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
                            app.LockedCaseIds(end+1) = caseIdStr;
                        end
                        if ~ismember(caseIdStr, app.TimeControlBaselineLockedIds) && ...
                                ~ismember(caseIdStr, newTimeControlLocks)
                            newTimeControlLocks(end+1) = caseIdStr;
                        end
                    elseif procStartTime <= currentTimeMinutes && currentTimeMinutes < procEndTime
                        % Case would be in progress at this time
                        newStatus = "in_progress";
                        shouldBeLocked = true;

                        % Lock in-progress cases to preserve time and lab assignment
                        if ~ismember(caseIdStr, app.LockedCaseIds)
                            app.LockedCaseIds(end+1) = caseIdStr;
                        end
                        if ~ismember(caseIdStr, app.TimeControlBaselineLockedIds) && ...
                                ~ismember(caseIdStr, newTimeControlLocks)
                            newTimeControlLocks(end+1) = caseIdStr;
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
                            originalStatus = string(caseObj.CaseStatus);
                            originalLock = logical(caseObj.IsLocked);
                            hasStatusChange = originalStatus ~= string(newStatus);
                            hasLockChange = originalLock ~= shouldBeLocked;
                            if hasStatusChange || hasLockChange
                                app.recordTimeControlCaseBaseline(caseIdStr, originalStatus, originalLock);
                            end
                            caseObj.CaseStatus = newStatus;
                            caseObj.IsLocked = shouldBeLocked;

                            if hasStatusChange
                                if newStatus == "completed"
                                    app.CaseManager.addCaseToCompletedArchive(caseObj);
                                else
                                    app.CaseManager.removeCaseFromCompletedArchive(caseIdStr);
                                end
                            end
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
            if ismethod(app, 'refreshCaseBuckets')
                app.refreshCaseBuckets('TimeControlUpdate');
            end

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

        function changed = didCaseStatusesChange(~, originalSchedule, simulatedSchedule)
            %DIDCASESTATUSESCHANGE Check if any case statuses differ between schedules
            %   Returns true if any case statuses have changed, false otherwise
            if isempty(originalSchedule) || isempty(simulatedSchedule)
                changed = false;
                return;
            end

            origAssignments = originalSchedule.labAssignments();
            simAssignments = simulatedSchedule.labAssignments();

            if numel(origAssignments) ~= numel(simAssignments)
                changed = true;
                return;
            end

            % Compare statuses for all cases across all labs
            for labIdx = 1:numel(origAssignments)
                origCases = origAssignments{labIdx};
                simCases = simAssignments{labIdx};

                if numel(origCases) ~= numel(simCases)
                    changed = true;
                    return;
                end

                % Check each case in this lab
                for caseIdx = 1:numel(origCases)
                    origStatus = conduction.gui.controllers.ScheduleRenderer.getFieldValue(origCases(caseIdx), 'Status', "");
                    simStatus = conduction.gui.controllers.ScheduleRenderer.getFieldValue(simCases(caseIdx), 'Status', "");

                    if origStatus ~= simStatus
                        changed = true;
                        return;
                    end
                end
            end

            changed = false;
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
                        labelHour = max(closedEndHour - 0.25, yLimits(1) + 0.2);
                        textAlignment = 'top';
                    else
                        labelText = sprintf('Closed after %s', obj.minutesToTimeString(closedStartHour * 60));
                        labelHour = min(closedStartHour + 0.3, closedEndHour - 0.2);
                        textAlignment = 'middle';
                    end

                    textHandle = text(ax, labId, labelHour, labelText, ...
                        'Color', [0.55 0.55 0.55], 'FontWeight', 'bold', 'FontSize', 8.5, ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', textAlignment, ...
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

        % DURATION-EDITING: Public methods for updating case durations
        function scheduleWasUpdated = applyCaseResize(obj, app, caseId, newProcEndMinutes)
            scheduleWasUpdated = false;

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();
            originalAssignments = assignments;
            labs = app.OptimizedSchedule.Labs;
            metrics = app.OptimizedSchedule.metrics();

            beforeGlobalIds = obj.collectCaseIds(assignments);

            sourceLabIdx = NaN;
            caseIdx = NaN;
            for labIdx = 1:numel(assignments)
                casesArr = assignments{labIdx};
                if isempty(casesArr)
                    continue;
                end
                casesArr = casesArr(:);
                ids = obj.collectCaseIds(casesArr);
                matchMask = (ids == caseId);
                if any(matchMask)
                    sourceLabIdx = labIdx;
                    caseIdx = find(matchMask, 1, 'first');
                    caseStruct = casesArr(caseIdx);
                    break;
                end
            end

            if isnan(sourceLabIdx) || isnan(caseIdx)
                warning('ScheduleRenderer:CaseResizeFailed', 'Failed to locate case %s for resize operation.', caseId);
                return;
            end

            caseStruct = obj.updateCaseProcedureEnd(caseStruct, newProcEndMinutes);
            assignments{sourceLabIdx}(caseIdx) = caseStruct;
            assignments = obj.normalizeLabAssignments(assignments);

            afterGlobalIds = obj.collectCaseIds(assignments);
            afterSourceIds = obj.collectCaseIds(assignments{sourceLabIdx});
            beforeSourceIds = obj.collectCaseIds(originalAssignments{sourceLabIdx});

            [hasAnomaly, anomalyDetails] = obj.debugHasAnomalies(beforeGlobalIds, afterGlobalIds, caseId, sourceLabIdx, sourceLabIdx, beforeSourceIds, afterSourceIds, beforeSourceIds, afterSourceIds, false);
            if hasAnomaly
                warnMsg = sprintf('Resize for case %s reverted due to integrity check failure.', caseId);
                if strlength(anomalyDetails) > 0
                    warnMsg = sprintf('%s\n%s', warnMsg, char(anomalyDetails));
                end
                warning('ScheduleRenderer:CaseResizeReverted', warnMsg);
                return;
            end

            scheduleWasUpdated = true;
            app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, metrics);
            app.LastDraggedCaseId = caseId;

            % Detect and cache overlapping cases after the resize
            app.OverlappingCaseIds = obj.detectOverlappingCases(app);

            if obj.shouldAddPersistentLock(app) && ~ismember(caseId, app.LockedCaseIds)
                app.LockedCaseIds(end+1) = caseId;
                app.LockedCaseIds = unique(app.LockedCaseIds, 'stable');
            end

            obj.triggerTimeControlFinalize(app, caseId, struct( ...
                'action', 'resize', ...
                'newProcEndMinutes', newProcEndMinutes));

            % DURATION-EDITING: Update the ProspectiveCase object's EstimatedDurationMinutes
            % so the case table reflects the new duration
            [caseObj, ~] = app.CaseManager.findCaseById(caseId);
            if ~isempty(caseObj)
                procStart = obj.getFieldValue(caseStruct, {'procStartTime', 'procedureStartTime'}, NaN);
                if ~isnan(procStart)
                    newProcDurationMinutes = newProcEndMinutes - procStart;
                    caseObj.EstimatedDurationMinutes = max(0, round(newProcDurationMinutes));
                end
            end

            app.OptimizationController.markOptimizationDirty(app);
            app.updateCasesTable();

            if strlength(app.DrawerCurrentCaseId) > 0 && app.DrawerCurrentCaseId == caseId && ...
                    app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                app.DrawerController.populateDrawer(app, caseId);
            end

        end

        function updateCaseSetupDuration(obj, app, caseId, newSetupMinutes)
            % DURATION-EDITING: Update setup duration for a case in the schedule
            %   Shifts setupStart while keeping procStart fixed
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();
            labs = app.OptimizedSchedule.Labs;
            metrics = app.OptimizedSchedule.metrics();

            % Find the case
            [sourceLabIdx, caseIdx, caseStruct] = obj.findCaseInAssignments(assignments, caseId);
            if isnan(sourceLabIdx) || isnan(caseIdx)
                warning('ScheduleRenderer:CaseSetupUpdateFailed', 'Failed to locate case %s for setup duration update.', caseId);
                return;
            end

            % Update setup duration
            caseStruct = obj.setFieldIfExists(caseStruct, {'setupTime', 'setupDuration', 'setupMinutes'}, newSetupMinutes);

            % Recalculate setupStart based on procStart - newSetupMinutes
            procStart = obj.getFieldValue(caseStruct, {'procStartTime', 'procedureStartTime'}, NaN);
            if ~isnan(procStart)
                newSetupStart = procStart - newSetupMinutes;
                caseStruct = obj.setFieldIfExists(caseStruct, {'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime'}, newSetupStart);
            end

            % Update the case in assignments
            assignments{sourceLabIdx}(caseIdx) = caseStruct;
            assignments = obj.normalizeLabAssignments(assignments);

            % Update schedule
            app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, metrics);
            app.OptimizationController.markOptimizationDirty(app);

            % Refresh drawer if needed
            if strlength(app.DrawerCurrentCaseId) > 0 && app.DrawerCurrentCaseId == caseId && ...
                    app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                app.DrawerController.populateDrawer(app, caseId);
            end
        end

        function updateCasePostDuration(obj, app, caseId, newPostMinutes)
            % DURATION-EDITING: Update post duration for a case in the schedule
            %   Recalculates postEnd while keeping procEnd fixed
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();
            labs = app.OptimizedSchedule.Labs;
            metrics = app.OptimizedSchedule.metrics();

            % Find the case
            [sourceLabIdx, caseIdx, caseStruct] = obj.findCaseInAssignments(assignments, caseId);
            if isnan(sourceLabIdx) || isnan(caseIdx)
                warning('ScheduleRenderer:CasePostUpdateFailed', 'Failed to locate case %s for post duration update.', caseId);
                return;
            end

            % Update post duration
            caseStruct = obj.setFieldIfExists(caseStruct, {'postTime', 'postDuration', 'postMinutes'}, newPostMinutes);

            % Recalculate postEnd based on procEnd + newPostMinutes
            procEnd = obj.getFieldValue(caseStruct, {'procEndTime', 'procedureEndTime'}, NaN);
            if ~isnan(procEnd)
                newPostEnd = procEnd + newPostMinutes;
                caseStruct = obj.setFieldIfExists(caseStruct, {'postEndTime', 'postProcedureEndTime'}, newPostEnd);

                % Update turnover and end times
                turnoverDuration = obj.getFieldValue(caseStruct, {'turnoverTime', 'turnoverDuration'}, 0);
                if isnan(turnoverDuration)
                    turnoverDuration = 0;
                end
                newTurnoverEnd = newPostEnd + turnoverDuration;
                caseStruct = obj.setFieldIfExists(caseStruct, {'turnoverEnd', 'turnoverEndTime'}, newTurnoverEnd);
                caseStruct = obj.setFieldIfExists(caseStruct, {'endTime', 'caseEndTime', 'scheduleEnd'}, newTurnoverEnd);
            end

            % Update the case in assignments
            assignments{sourceLabIdx}(caseIdx) = caseStruct;
            assignments = obj.normalizeLabAssignments(assignments);

            % Update schedule
            app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, metrics);
            app.OptimizationController.markOptimizationDirty(app);

            % Refresh drawer if needed
            if strlength(app.DrawerCurrentCaseId) > 0 && app.DrawerCurrentCaseId == caseId && ...
                    app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                app.DrawerController.populateDrawer(app, caseId);
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
            originalAssignments = assignments;
            labs = app.OptimizedSchedule.Labs;
            metrics = app.OptimizedSchedule.metrics();

            beforeGlobalIds = obj.collectCaseIds(assignments);

            sourceLabIdx = NaN;
            movedCase = struct();
            beforeSourceIds = string.empty(0,1);
            beforeTargetIds = obj.collectCaseIds(assignments{targetLabIndex});

            newAssignments = assignments;
            for labIdx = 1:numel(assignments)
                casesArr = assignments{labIdx};
                if isempty(casesArr)
                    continue;
                end
                casesArr = casesArr(:);
                ids = obj.collectCaseIds(casesArr);
                matchMask = (ids == caseId);
                if any(matchMask)
                    sourceLabIdx = labIdx;
                    beforeSourceIds = ids;
                    movedCase = casesArr(find(matchMask, 1, 'first'));

                    originalStart = obj.getCaseStartMinutes(movedCase);
                    if isnan(originalStart)
                        originalStart = newSetupStartMinutes;
                    end
                    deltaMinutes = newSetupStartMinutes - originalStart;
                    if isnan(deltaMinutes)
                        deltaMinutes = 0;
                    end
                    movedCase = obj.shiftCaseTimes(movedCase, deltaMinutes);
                    if isfield(movedCase, 'lab'), movedCase.lab = targetLabIndex; end
                    if isfield(movedCase, 'labIndex'), movedCase.labIndex = targetLabIndex; end
                    movedCase.assignedLab = targetLabIndex;
                    movedCase.startTime = newSetupStartMinutes;
                    if ~isfield(movedCase, 'setupStartTime') || isempty(movedCase.setupStartTime)
                        movedCase.setupStartTime = newSetupStartMinutes;
                    else
                        movedCase.setupStartTime = newSetupStartMinutes;
                    end

                    casesArr(matchMask) = [];
                    newAssignments{labIdx} = casesArr;
                    break;
                end
            end

            if isnan(sourceLabIdx) || isempty(movedCase)
                warning('ScheduleRenderer:CaseMoveFailed', 'Failed to locate case %s for drag operation.', caseId);
                return;
            end

            targetCases = newAssignments{targetLabIndex};
            [targetCases, movedCase] = obj.alignStructFieldsForConcat(targetCases, movedCase);

            if isempty(targetCases)
                targetCases = movedCase;
            else
                targetCases = targetCases(:);
                startTimes = arrayfun(@(s) obj.getCaseStartMinutes(s), targetCases);
                startTimes(~isfinite(startTimes)) = inf;

                insertPos = find(startTimes > newSetupStartMinutes, 1, 'first');
                if isempty(insertPos)
                    targetCases = [targetCases; movedCase];
                else
                    targetCases = [targetCases(1:insertPos-1); movedCase; targetCases(insertPos:end)];
                end
            end

            newAssignments{targetLabIndex} = targetCases(:);
            assignments = obj.normalizeLabAssignments(newAssignments);

            afterSourceIds = obj.collectCaseIds(assignments{sourceLabIdx});
            afterTargetIds = obj.collectCaseIds(assignments{targetLabIndex});
            afterGlobalIds = obj.collectCaseIds(assignments);

            [hasAnomaly, anomalyDetails] = obj.debugHasAnomalies(beforeGlobalIds, afterGlobalIds, caseId, sourceLabIdx, targetLabIndex, beforeSourceIds, afterSourceIds, beforeTargetIds, afterTargetIds, false);
            if hasAnomaly
                warnMsg = sprintf('Move for case %s reverted due to integrity check failure.', caseId);
                if strlength(anomalyDetails) > 0
                    warnMsg = sprintf('%s\n%s', warnMsg, char(anomalyDetails));
                end
                warning('ScheduleRenderer:CaseMoveReverted', warnMsg);
                app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, originalAssignments, metrics);
                scheduleWasUpdated = false;
                return;
            end

            scheduleWasUpdated = true;
            app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, metrics);
            app.LastDraggedCaseId = caseId;

            % Detect and cache overlapping cases after the move
            app.OverlappingCaseIds = obj.detectOverlappingCases(app);

            if obj.shouldAddPersistentLock(app) && ~ismember(caseId, app.LockedCaseIds)
                app.LockedCaseIds(end+1) = caseId;
                app.LockedCaseIds = unique(app.LockedCaseIds, 'stable');
            end

            obj.triggerTimeControlFinalize(app, caseId, struct( ...
                'action', 'move', ...
                'targetLabIndex', targetLabIndex, ...
                'targetStartMinutes', newSetupStartMinutes));
        end

        function [sourceLabIdx, caseIdx, caseStruct] = findCaseInAssignments(obj, assignments, caseId)
            % DURATION-EDITING: Helper to find a case in lab assignments
            sourceLabIdx = NaN;
            caseIdx = NaN;
            caseStruct = struct();

            for labIdx = 1:numel(assignments)
                casesArr = assignments{labIdx};
                if isempty(casesArr)
                    continue;
                end
                casesArr = casesArr(:);
                ids = obj.collectCaseIds(casesArr);
                matchMask = (ids == caseId);
                if any(matchMask)
                    sourceLabIdx = labIdx;
                    caseIdx = find(matchMask, 1, 'first');
                    caseStruct = casesArr(caseIdx);
                    return;
                end
            end
        end

        function ids = collectCaseIds(obj, data)
            %COLLECTCASEIDS Helper to collect case IDs from arrays or cell arrays
            if isempty(data)
                ids = string.empty(0,1);
                return;
            end

            if iscell(data)
                ids = string.empty(0,1);
                for i = 1:numel(data)
                    ids = [ids; obj.collectCaseIds(data{i})]; %#ok<AGROW>
                end
                return;
            end

            data = data(:);
            ids = arrayfun(@(s) string(obj.getFieldValue(s, {'caseID','caseId'}, "")), data, 'UniformOutput', true);
        end

        function [anomaly, detailMsg] = debugHasAnomalies(obj, beforeGlobalIds, afterGlobalIds, movedId, sourceLabIdx, targetLabIdx, beforeSourceIds, afterSourceIds, beforeTargetIds, afterTargetIds, logDetails)
            if nargin < 11
                logDetails = false;
            end

            anomaly = false;
            detailMsg = "";

            missing = setdiff(beforeGlobalIds, afterGlobalIds, 'stable');
            extra = setdiff(afterGlobalIds, beforeGlobalIds, 'stable');
            dupIds = obj.findDuplicates(afterGlobalIds);

            if isempty(missing) && isempty(extra) && isempty(dupIds)
                return;
            end

            anomaly = true;
            lines = strings(0,1);
            lines(end+1,1) = sprintf('[CaseDrag][WARN] Integrity check failed for move of %s', movedId);
            if ~isempty(missing)
                lines(end+1,1) = sprintf('  Missing IDs: %s', strjoin(missing, ', '));
            end
            if ~isempty(extra)
                lines(end+1,1) = sprintf('  Extra IDs: %s', strjoin(extra, ', '));
            end
            if ~isempty(dupIds)
                lines(end+1,1) = sprintf('  Duplicate IDs: %s', strjoin(dupIds, ', '));
            end

            lines(end+1,1) = obj.formatLabCaseIds('Source (before)', sourceLabIdx, beforeSourceIds);
            lines(end+1,1) = obj.formatLabCaseIds('Source (after)', sourceLabIdx, afterSourceIds);
            lines(end+1,1) = obj.formatLabCaseIds('Target (before)', targetLabIdx, beforeTargetIds);
            lines(end+1,1) = obj.formatLabCaseIds('Target (after)', targetLabIdx, afterTargetIds);

            detailMsg = strjoin(lines, newline);
            if logDetails
                fprintf('\n%s\n', char(detailMsg));
            end
        end

        function message = formatLabCaseIds(~, label, labIdx, ids)
            if isempty(ids)
                idsStr = '(none)';
            else
                idsStr = strjoin(ids, ', ');
            end
            message = sprintf('  %s Lab %d: %s', label, labIdx, idsStr);
        end

        function dupIds = findDuplicates(~, ids)
            if isempty(ids)
                dupIds = string.empty(0,1);
                return;
            end
            [uniqueIds, ~, idx] = unique(ids, 'stable');
            counts = accumarray(idx, 1);
            dupIds = uniqueIds(counts > 1);
        end

        function tf = isCaseBlockDraggable(~, app, caseId)
            tf = false;
            if isempty(caseId)
                return;
            end

            allowTimeControlEdits = false;
            if isprop(app, 'AllowEditInTimeControl')
                try
                    allowTimeControlEdits = logical(app.AllowEditInTimeControl);
                catch
                    allowTimeControlEdits = false;
                end
            end
            timeControlActive = isprop(app, 'IsTimeControlActive') && app.IsTimeControlActive;

            if app.IsOptimizationRunning || (timeControlActive && ~allowTimeControlEdits)
                return;
            end

            [caseObj, ~] = app.CaseManager.findCaseById(caseId);
            if isempty(caseObj)
                return;
            end

            if timeControlActive && allowTimeControlEdits
                tf = true;
                return;
            end

            tf = caseObj.isPending();
        end

        function triggerTimeControlFinalize(obj, app, caseId, context)
            if nargin < 4
                context = struct();
            end

            controller = obj.resolveTimeControlController(app);
            if isempty(controller)
                return;
            end

            try
                controller.finalizePostEdit(app, caseId, context);
            catch ME
                warning('ScheduleRenderer:TimeControlFinalizeFailed', ...
                    'Failed to finalize Time Control edit for case %s: %s', ...
                    char(caseId), ME.message);
            end
        end

        function tf = shouldAddPersistentLock(~, app)
            tf = true;
            if isempty(app)
                return;
            end

            timeControlActive = isprop(app, 'IsTimeControlActive') && app.IsTimeControlActive;
            allowTimeControlEdits = true;
            if isprop(app, 'AllowEditInTimeControl')
                try
                    allowTimeControlEdits = logical(app.AllowEditInTimeControl);
                catch
                    allowTimeControlEdits = false;
                end
            end

            if timeControlActive && allowTimeControlEdits
                tf = false;
            end
        end

        function pauseNowTimerForEdit(obj, app)
            controller = obj.resolveTimeControlController(app);
            if isempty(controller)
                return;
            end
            try
                controller.pauseNowTimer(app);
            catch ME
                warning('ScheduleRenderer:PauseNowTimerFailed', ...
                    'Failed to pause NOW timer: %s', ME.message);
            end
        end

        function resumeNowTimerAfterEdit(obj, app)
            controller = obj.resolveTimeControlController(app);
            if isempty(controller)
                return;
            end
            try
                controller.resumeNowTimer(app);
            catch ME
                warning('ScheduleRenderer:ResumeNowTimerFailed', ...
                    'Failed to resume NOW timer: %s', ME.message);
            end
        end

        function controller = resolveTimeControlController(~, app)
            controller = [];
            if isempty(app) || ~isprop(app, 'IsTimeControlActive') || ~app.IsTimeControlActive
                return;
            end

            allowTimeControlEdits = true;
            if isprop(app, 'AllowEditInTimeControl')
                try
                    allowTimeControlEdits = logical(app.AllowEditInTimeControl);
                catch
                    allowTimeControlEdits = false;
                end
            end
            if ~allowTimeControlEdits
                return;
            end

            if ~isprop(app, 'TimeControlEditController') || isempty(app.TimeControlEditController)
                return;
            end

            candidate = app.TimeControlEditController;
            if isa(candidate, 'handle') && isvalid(candidate)
                controller = candidate;
            end
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

            % Detect double-click using SelectionType
            % This enables double-click to toggle lock directly on schedule blocks
            try
                fig = ancestor(rectHandle, 'figure');
                if isempty(fig) || ~isgraphics(fig)
                    % Fallback: no figure found, use single-click behavior
                    if isempty(callback)
                        if strlength(caseId) > 0
                            app.onScheduleBlockClicked(caseId);
                        end
                    else
                        callback(caseId);
                    end
                    return;
                end

                selectionType = string(get(fig, 'SelectionType'));
                modifiers = string(get(fig, 'CurrentModifier'));
                modifiers = modifiers(strlength(modifiers) > 0);
                hasToggleModifier = any(modifiers == "shift" | modifiers == "control" | modifiers == "command");

                if selectionType == "open"
                    % Double-click detected - toggle lock
                    callbackArg = sprintf('lock-toggle:%s', caseId);
                elseif selectionType == "extend" || hasToggleModifier
                    % Shift/Ctrl-click toggles selection membership
                    callbackArg = sprintf('toggle-select:%s', caseId);
                else
                    % Single-click or other - normal behavior
                    callbackArg = caseId;
                end

                if isempty(callback)
                    if strlength(callbackArg) > 0
                        app.onScheduleBlockClicked(callbackArg);
                    end
                else
                    try
                        callback(callbackArg);
                    catch
                        if strlength(callbackArg) > 0
                            app.onScheduleBlockClicked(callbackArg);
                        end
                    end
                end
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

        function [casesOut, movedCaseOut] = alignStructFieldsForConcat(obj, casesIn, movedCaseIn)
            %ALIGNSTRUCTFIELDSFORCONCAT Ensure case arrays share fields before concatenation
            if nargin < 3
                movedCaseIn = struct();
            end

            movedCaseOut = movedCaseIn;
            if isempty(casesIn)
                if isempty(fieldnames(movedCaseOut))
                    casesOut = struct([]);
                    return;
                end

                fieldOrder = fieldnames(movedCaseOut);
                casesOut = obj.createEmptyStructWithFields(fieldOrder);
                return;
            end

            existingFields = fieldnames(casesIn);
            newFields = fieldnames(movedCaseOut);
            allFields = unique([existingFields(:); newFields(:)], 'stable');

            casesOut = obj.ensureStructHasFields(casesIn, allFields);
            movedCaseOut = obj.ensureStructHasFields(movedCaseOut, allFields);

            casesOut = orderfields(casesOut, allFields);
            movedCaseOut = orderfields(movedCaseOut, allFields);
        end

        function s = ensureStructHasFields(~, s, fieldList)
            if isempty(fieldList)
                return;
            end

            if isempty(s)
                template = cell(1, numel(fieldList));
                [template{:}] = deal([]);
                s = cell2struct(template, fieldList, 2);
                s = s([]);
                return;
            end

            for idx = 1:numel(fieldList)
                fieldName = fieldList{idx};
                if ~isfield(s, fieldName)
                    for elementIdx = 1:numel(s)
                        s(elementIdx).(fieldName) = [];
                    end
                end
            end
        end

        function s = createEmptyStructWithFields(~, fieldList)
            if isempty(fieldList)
                s = struct([]);
                return;
            end

            template = cell(1, numel(fieldList));
            [template{:}] = deal([]);
            s = cell2struct(template, fieldList, 2);
            s = s([]);
        end

        function caseStruct = updateCaseProcedureEnd(obj, caseStruct, newProcEndMinutes)
            procStart = obj.getFieldValue(caseStruct, {'procStartTime','procedureStartTime'}, NaN);
            if isnan(procStart)
                procStart = obj.getFieldValue(caseStruct, {'startTime','setupStartTime','caseStartTime'}, NaN);
            end

            oldProcEnd = obj.getFieldValue(caseStruct, {'procEndTime','procedureEndTime'}, NaN);
            oldPostEnd = obj.getFieldValue(caseStruct, {'postEndTime','postProcedureEndTime'}, NaN);
            oldTurnoverEnd = obj.getFieldValue(caseStruct, {'turnoverEnd','turnoverEndTime'}, NaN);
            oldEndTime = obj.getFieldValue(caseStruct, {'endTime','caseEndTime','scheduleEnd'}, NaN);

            postDuration = obj.safeDifference(oldPostEnd, oldProcEnd);
            if isnan(postDuration)
                postDuration = obj.getFieldValue(caseStruct, 'postTime', 0);
            end
            if isnan(postDuration)
                postDuration = 0;
            end

            turnoverDuration = obj.safeDifference(oldTurnoverEnd, oldPostEnd);
            if isnan(turnoverDuration)
                turnoverDuration = obj.getFieldValue(caseStruct, 'turnoverTime', 0);
            end
            if isnan(turnoverDuration)
                turnoverDuration = 0;
            end

            setupStart = obj.getFieldValue(caseStruct, {'startTime','setupStartTime','caseStartTime'}, NaN);
            if isnan(setupStart)
                setupStart = obj.safeDifference(procStart, obj.getFieldValue(caseStruct, 'setupTime', NaN));
            end

            newPostEnd = newProcEndMinutes + postDuration;
            newTurnoverEnd = newPostEnd + turnoverDuration;
            newEndTime = newTurnoverEnd;

            caseStruct = obj.setFieldIfExists(caseStruct, {'procEndTime','procedureEndTime'}, newProcEndMinutes);
            if ~isnan(procStart)
                procDuration = newProcEndMinutes - procStart;
                caseStruct = obj.setFieldIfExists(caseStruct, {'procTime','procedureMinutes','procedureDuration'}, procDuration);
            end
            caseStruct = obj.setFieldIfExists(caseStruct, {'postEndTime','postProcedureEndTime'}, newPostEnd);
            caseStruct = obj.setFieldIfExists(caseStruct, {'turnoverEnd','turnoverEndTime'}, newTurnoverEnd);
            caseStruct = obj.setFieldIfExists(caseStruct, {'endTime','caseEndTime','scheduleEnd'}, newEndTime);

            if isfield(caseStruct, 'assignedLab') && isempty(caseStruct.assignedLab)
                caseStruct.assignedLab = obj.getFieldValue(caseStruct, 'labIndex', []);
            end
            if isfield(caseStruct, 'startTime') && ~isnan(setupStart)
                caseStruct.startTime = setupStart;
            end
        end

        function s = setFieldIfExists(~, s, fieldNames, value)
            if isempty(fieldNames)
                return;
            end
            if ~iscell(fieldNames)
                fieldNames = {fieldNames};
            end
            for i = 1:numel(fieldNames)
                name = fieldNames{i};
                if isfield(s, name)
                    s.(name) = value;
                end
            end
        end

        function diffValue = safeDifference(~, a, b)
            if isnan(a) || isnan(b)
                diffValue = NaN;
            else
                diffValue = a - b;
            end
        end

        function showCaseDragWarning(~, app, message)
            if isempty(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            uialert(app.UIFigure, message, 'Case Drag', 'Icon', 'warning');
        end

        function restoreSelectionOverlay(obj, app)
            if isempty(app) || isempty(app.CaseDragController)
                return;
            end

            ids = string.empty(0, 1);
            if isprop(app, 'SelectedCaseIds')
                ids = app.SelectedCaseIds;
            elseif strlength(app.SelectedCaseId) > 0
                ids = string(app.SelectedCaseId);
            end

            if isempty(ids)
                app.CaseDragController.hideSelectionOverlay(true);
                return;
            end

            if ismethod(app.CaseDragController, 'showSelectionOverlayForIds')
                app.CaseDragController.showSelectionOverlayForIds(app, ids);
            else
                app.CaseDragController.showSelectionOverlay(app.SelectedCaseId);
            end
        end

        function applyMultiSelectionHighlights(obj, app)
            if isempty(app) || isempty(app.CaseDragController)
                return;
            end

            ids = string.empty(0, 1);
            if isprop(app, 'SelectedCaseIds')
                ids = app.SelectedCaseIds;
            elseif strlength(app.SelectedCaseId) > 0
                ids = string(app.SelectedCaseId);
            end

            if isempty(ids)
                app.CaseDragController.hideSelectionOverlay(true);
                return;
            end

            if ismethod(app.CaseDragController, 'showSelectionOverlayForIds')
                app.CaseDragController.showSelectionOverlayForIds(app, ids);
            else
                app.CaseDragController.showSelectionOverlay(app.SelectedCaseId);
            end
        end

        function value = extractField(~, source, fieldName, defaultValue)
            if nargin < 4
                defaultValue = [];
            end
            value = defaultValue;
            if isstruct(source) && isfield(source, fieldName)
                value = source.(fieldName);
            end
        end

        function caseRect = findCaseBlockHandle(~, axesHandle, caseId)
            caseRect = [];
            if ~isgraphics(axesHandle)
                return;
            end
            blocks = findobj(axesHandle, 'Tag', 'CaseBlock');
            for idx = 1:numel(blocks)
                block = blocks(idx);
                if ~isgraphics(block)
                    continue;
                end
                ud = get(block, 'UserData');
                if ~isstruct(ud) || ~isfield(ud, 'caseId')
                    continue;
                end
                if string(ud.caseId) == caseId
                    caseRect = block;
                    return;
                end
            end
        end

        function overlappingIds = detectOverlappingCases(obj, app)
            %DETECTOVERLAPPINGCASES Detect all cases that should be offset (persistent tracking)
            %   Scans ALL cases for overlaps and determines which case is "on top" for each pair
            %   Preserves existing overlaps until they are resolved by moving one of the cases
            overlappingIds = string.empty(0, 1);

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();

            % Get the previous cached overlapping IDs for persistence
            previousOverlappingIds = string(app.OverlappingCaseIds);

            % Get the last dragged case ID for determining new "on top" cases
            lastDraggedCaseId = "";
            if ~isempty(app.LastDraggedCaseId) && strlength(app.LastDraggedCaseId) > 0
                lastDraggedCaseId = string(app.LastDraggedCaseId);
            end

            % Scan each lab for overlapping cases
            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases) || numel(labCases) < 2
                    continue;  % Need at least 2 cases to have overlaps
                end

                % Extract timing windows for all cases on this lab
                numCases = numel(labCases);
                caseIds = strings(numCases, 1);
                setupStarts = nan(numCases, 1);
                turnoverEnds = nan(numCases, 1);

                for i = 1:numCases
                    caseEntry = labCases(i);
                    caseIds(i) = string(obj.getFieldValue(caseEntry, {'caseID', 'caseId'}, ""));

                    % Get setupStart (or earliest time field)
                    setupStarts(i) = obj.getFieldValue(caseEntry, ...
                        {'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime', 'procStartTime'}, NaN);

                    % Get turnoverEnd (or latest time field)
                    turnoverEnds(i) = obj.getFieldValue(caseEntry, ...
                        {'turnoverEnd', 'turnoverEndTime', 'endTime', 'caseEndTime', 'scheduleEnd'}, NaN);

                    % Fallback: if no turnoverEnd, try computing from procEnd + post + turnover
                    if isnan(turnoverEnds(i))
                        procEnd = obj.getFieldValue(caseEntry, {'procEndTime', 'procedureEndTime'}, NaN);
                        postDur = obj.getFieldValue(caseEntry, {'postTime', 'postDuration'}, 0);
                        turnoverDur = obj.getFieldValue(caseEntry, {'turnoverTime', 'turnoverDuration'}, 0);
                        if ~isnan(procEnd)
                            turnoverEnds(i) = procEnd + max(0, postDur) + max(0, turnoverDur);
                        end
                    end
                end

                % Check all pairs for overlaps
                for i = 1:numCases
                    for j = (i+1):numCases
                        % Skip if either case has invalid timing
                        if isnan(setupStarts(i)) || isnan(turnoverEnds(i)) || ...
                           isnan(setupStarts(j)) || isnan(turnoverEnds(j))
                            continue;
                        end

                        % Check if time windows overlap
                        % Two intervals [a,b] and [c,d] overlap if: a < d AND c < b
                        if setupStarts(i) < turnoverEnds(j) && setupStarts(j) < turnoverEnds(i)
                            % These cases overlap - determine which is "on top"
                            topCaseId = "";

                            % Priority 1: Check if either is in the previous cached list (persistence)
                            iWasPreviouslyOnTop = ismember(caseIds(i), previousOverlappingIds);
                            jWasPreviouslyOnTop = ismember(caseIds(j), previousOverlappingIds);

                            if iWasPreviouslyOnTop && ~jWasPreviouslyOnTop
                                topCaseId = caseIds(i);
                            elseif jWasPreviouslyOnTop && ~iWasPreviouslyOnTop
                                topCaseId = caseIds(j);
                            else
                                % Priority 2: Check if either is the last dragged case (new drag)
                                if strlength(lastDraggedCaseId) > 0
                                    if caseIds(i) == lastDraggedCaseId
                                        topCaseId = caseIds(i);
                                    elseif caseIds(j) == lastDraggedCaseId
                                        topCaseId = caseIds(j);
                                    end
                                end

                                % Priority 3: Heuristic - later start time is "on top"
                                if strlength(topCaseId) == 0
                                    if setupStarts(i) > setupStarts(j)
                                        topCaseId = caseIds(i);
                                    else
                                        topCaseId = caseIds(j);
                                    end
                                end
                            end

                            % Add the "on top" case to the new overlapping list
                            if strlength(topCaseId) > 0 && ~ismember(topCaseId, overlappingIds)
                                overlappingIds(end+1, 1) = topCaseId; %#ok<AGROW>
                            end
                        end
                    end
                end
            end

            % Return unique sorted list
            if ~isempty(overlappingIds)
                overlappingIds = unique(overlappingIds, 'stable');
            end
        end

        function assignmentsOut = normalizeLabAssignments(obj, assignmentsIn)
            assignmentsOut = assignmentsIn;
            allFields = {};

            % Gather union of fields across all labs
            for labIdx = 1:numel(assignmentsIn)
                labCases = assignmentsIn{labIdx};
                if isempty(labCases)
                    continue;
                end
                labCases = labCases(:);
                fn = fieldnames(labCases);
                if isempty(allFields)
                    allFields = fn;
                else
                    allFields = union(allFields, fn, 'stable');
                end
            end

            if isempty(allFields)
                return;
            end

            for labIdx = 1:numel(assignmentsIn)
                labCases = assignmentsIn{labIdx};
                if isempty(labCases)
                    assignmentsOut{labIdx} = labCases;
                    continue;
                end

                labCases = labCases(:);
                labCases = obj.ensureStructHasFields(labCases, allFields);

                if ismember('assignedLab', allFields)
                    for caseIdx = 1:numel(labCases)
                        if ~isfield(labCases(caseIdx), 'assignedLab') || isempty(labCases(caseIdx).assignedLab)
                            labCases(caseIdx).assignedLab = labIdx;
                        end
                    end
                end

                assignmentsOut{labIdx} = labCases;
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
            if ~isempty(hourLabels)
                hourLabels{1} = '';
                if numel(hourLabels) > 1
                    hourLabels{end} = '';
                end
            end
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
            %   Accepts a single field name (char/string) or a cell array of
            %   candidate names (first match wins).
            if nargin < 3
                defaultValue = [];
            end

            % If a list of candidate names is provided, return first match
            if iscell(fieldName)
                for i = 1:numel(fieldName)
                    candidate = fieldName{i};
                    val = conduction.gui.controllers.ScheduleRenderer.getFieldValue(structOrObj, candidate, NaN);
                    % Accept the first non-empty value that is not wholly NaN
                    if ~isempty(val)
                        if isnumeric(val)
                            if ~all(isnan(val(:)))
                                value = val;
                                return;
                            end
                        else
                            value = val;
                            return;
                        end
                    end
                end
                value = defaultValue;
                return;
            end

            % Single field path
            if isstruct(structOrObj) && isfield(structOrObj, fieldName)
                value = structOrObj.(fieldName);
            elseif isobject(structOrObj) && isprop(structOrObj, fieldName)
                value = structOrObj.(fieldName);
            else
                value = defaultValue;
            end
        end

        function minutes = getCaseStartMinutes(caseStruct)
            %GETCASESTARTMINUTES Robust extraction of a case's start-time minutes
            minutes = NaN;
            try
                candidates = {'startTime','setupStartTime','scheduleStartTime','caseStartTime','procStartTime'};
                for i = 1:numel(candidates)
                    fn = candidates{i};
                    if isstruct(caseStruct) && isfield(caseStruct, fn)
                        val = caseStruct.(fn);
                    elseif isobject(caseStruct) && isprop(caseStruct, fn)
                        val = caseStruct.(fn);
                    else
                        val = [];
                    end
                    if ~isempty(val) && isnumeric(val) && ~all(isnan(val(:)))
                        minutes = double(val(1));
                        return;
                    end
                end
            catch
                minutes = NaN;
            end
        end

        function annotatedSchedule = annotateScheduleWithDerivedStatus(app, schedule)
            % Annotate schedule with status derived from NOW position
            % Replaces updateCaseStatusesByTime pattern
            %
            % Args:
            %   app: App instance
            %   schedule: DailySchedule to annotate
            %
            % Returns:
            %   annotatedSchedule: DailySchedule with caseStatus fields updated

            if isempty(schedule)
                annotatedSchedule = schedule;
                return;
            end

            nowMinutes = app.getNowPosition();
            labs = schedule.Labs;
            assignments = schedule.labAssignments();

            % Iterate through all lab assignments
            for labIdx = 1:numel(labs)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end

                for caseIdx = 1:numel(labCases)
                    caseId = string(labCases(caseIdx).caseID);
                    [caseObj, ~] = app.CaseManager.findCaseById(caseId);

                    if isempty(caseObj)
                        continue;
                    end

                    % Compute status from NOW position
                    status = caseObj.getComputedStatus(nowMinutes);

                    % Update schedule struct (for visualization only)
                    labCases(caseIdx).caseStatus = char(status);
                end

                % Update assignment
                assignments{labIdx} = labCases;
            end

            % Create new schedule with updated assignments
            annotatedSchedule = conduction.DailySchedule(schedule.Date, labs, assignments, schedule.metrics());
        end

    end
end
