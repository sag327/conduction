classdef CaseDragController < handle
    %CASEDAGCONTROLLER Maintains registry and state for schedule case dragging.
    %   This controller centralizes knowledge of rendered case blocks so drag
    %   handlers can look up handles and metadata without repeatedly scanning
    %   the axes. Future updates will extend this class to manage drag state
    %   and throttling, but the initial version simply tracks block metadata.

    properties (Access = private)
        CaseIds string
        RectHandles = gobjects(0, 1)
        UserDataCells cell
        HandleIndex containers.Map
        AppHandle conduction.gui.ProspectiveSchedulerApp = conduction.gui.ProspectiveSchedulerApp.empty
        LastRegistryUpdate datetime = NaT

        % Motion throttling state
        LastMotionTimer uint64 = uint64(0)
        MotionThrottleSeconds double = 0.016  % ~60 Hz default
        ActiveDrag struct = struct()
        ActiveResize struct = struct()

        % Soft highlight behaviour
        SoftSelectOnMouseDown logical = true
        DragStartMovementThresholdPx double = 4
        SoftHighlightRect = gobjects(0, 1)
        SoftHighlightAxes = gobjects(0, 1)
        SoftHighlightColor double = [1 1 1]
        SoftHighlightLineWidth double = 2.5
        SoftHighlightLastPosition double = [NaN NaN NaN NaN]
        DebugTiming logical = false

        SelectionRect = gobjects(0, 1)
        SelectionAxes = gobjects(0, 1)
        SelectionColor double = [1 1 1]
        SelectionLineWidth double = 3
        SelectionLastPosition double = [NaN NaN NaN NaN]
        SelectionCaseId string = ""
        SelectionGrip = gobjects(0, 1)
    end

    methods
        function obj = CaseDragController()
            obj.clearRegistry();
        end

        function registerCaseBlocks(obj, app, caseBlocks)
            %REGISTERCASEBLOCKS Record the current interactive case blocks.
            %   Replaces the previous registry entirely – intended to be invoked
            %   after each schedule render.

            if nargin < 3
                caseBlocks = gobjects(0, 1);
            end

            obj.clearRegistry();
            if isa(app, 'conduction.gui.ProspectiveSchedulerApp')
                obj.AppHandle = app;
            else
                obj.AppHandle = conduction.gui.ProspectiveSchedulerApp.empty;
            end

            if isempty(caseBlocks)
                return;
            end

            caseIds = strings(0, 1);
            rectHandles = gobjects(0, 1);
            userDataCells = cell(0, 1);

            for idx = 1:numel(caseBlocks)
                h = caseBlocks(idx);
                if ~isgraphics(h)
                    continue;
                end

                ud = get(h, 'UserData');
                if ~isstruct(ud) || ~isfield(ud, 'caseId')
                    continue;
                end

                caseId = string(ud.caseId);
                if strlength(caseId) == 0
                    continue;
                end

                caseIds(end+1, 1) = caseId; %#ok<AGROW>
                rectHandles(end+1, 1) = h; %#ok<AGROW>
                userDataCells{end+1, 1} = ud; %#ok<AGROW>
            end

            if isempty(caseIds)
                return;
            end

            obj.CaseIds = caseIds;
            obj.RectHandles = rectHandles;
            obj.UserDataCells = userDataCells;
            obj.HandleIndex = obj.buildHandleIndex(rectHandles);
            obj.LastRegistryUpdate = datetime('now');

            if strlength(obj.SelectionCaseId) > 0
                obj.showSelectionOverlay(obj.SelectionCaseId);
            end
        end

        function clearRegistry(obj)
            %CLEARREGISTRY Remove all tracked case block metadata.
            obj.hideSoftHighlight();
            obj.hideSelectionOverlay(false);
            obj.CaseIds = string.empty(0, 1);
            obj.RectHandles = gobjects(0, 1);
            obj.UserDataCells = cell(0, 1);
            obj.HandleIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.LastRegistryUpdate = NaT;
            obj.LastMotionTimer = uint64(0);
            obj.AppHandle = conduction.gui.ProspectiveSchedulerApp.empty;
            obj.ActiveDrag = struct();
            obj.ActiveResize = struct();
        end

        function ids = listCaseIds(obj)
            %LISTCASEIDS Return all registered case IDs.
            ids = obj.CaseIds;
        end

        function showSoftHighlight(obj, axesHandle, rectHandle)
            %SHOWSOFTHIGHLIGHT Draw lightweight outline to provide immediate feedback.
            if ~obj.SoftSelectOnMouseDown
                return;
            end
            if nargin < 3 || isempty(axesHandle) || isempty(rectHandle)
                return;
            end
            if ~(isgraphics(axesHandle) && isgraphics(rectHandle))
                return;
            end

            pos = get(rectHandle, 'Position');
            if numel(pos) ~= 4 || any(~isfinite(pos))
                return;
            end

            % Expand soft highlight outward by the lock line thickness so it never
            % overlaps a red locked outline when both are present.
            lockLinePts = 3;  % match lock outline width
            [growX, growY] = obj.pointsToDataOffsets(axesHandle, lockLinePts);
            posDraw = [pos(1)-growX, pos(2)-growY, pos(3)+2*growX, pos(4)+2*growY];

            ticOverall = [];
            if obj.debugTimingEnabled()
                ticOverall = tic;
                fprintf('[SoftHighlight] start\n');
            end

            if isempty(obj.SoftHighlightRect) || ~isgraphics(obj.SoftHighlightRect)
                obj.SoftHighlightRect = rectangle(axesHandle, ...
                    'Position', posDraw, ...
                    'EdgeColor', obj.SoftHighlightColor, ...
                    'LineWidth', obj.SoftHighlightLineWidth, ...
                    'FaceColor', 'none', ...
                    'HitTest', 'off', ...
                    'PickableParts', 'none', ...
                    'Clipping', 'on', ...
                    'Tag', 'CaseSoftHighlight');
                if obj.debugTimingEnabled()
                    fprintf('[SoftHighlight] rectangle created in %.4f ms\n', toc(ticOverall)*1e3);
                end
            else
                if obj.SoftHighlightRect.Parent ~= axesHandle
                    set(obj.SoftHighlightRect, 'Parent', axesHandle);
                end
                set(obj.SoftHighlightRect, 'Position', posDraw, 'Visible', 'on');
            end

            obj.SoftHighlightAxes = axesHandle;
            obj.SoftHighlightLastPosition = posDraw;
            try
                uistack(obj.SoftHighlightRect, 'top');
            catch
                % ignore stacking issues
            end

            if obj.debugTimingEnabled()
                ticFlush = tic;
                drawnow limitrate nocallbacks;
                fprintf('[SoftHighlight] drawnow took %.4f ms\n', toc(ticFlush)*1e3);
            else
                try
                    drawnow limitrate nocallbacks;
                catch
                    % drawnow may be unsupported in select contexts; ignore
                end
            end

            if obj.debugTimingEnabled()
                fprintf('[SoftHighlight] total %.4f ms\n', toc(ticOverall)*1e3);
            end
        end

        function moveSoftHighlight(obj, newPosition)
            %MOVESOFTHIGHLIGHT Reposition overlay during drag motion.
            if ~obj.SoftSelectOnMouseDown
                return;
            end
            if isempty(obj.SoftHighlightRect) || ~isgraphics(obj.SoftHighlightRect)
                return;
            end
            if numel(newPosition) ~= 4 || any(~isfinite(newPosition))
                return;
            end
            if isequal(obj.SoftHighlightLastPosition, newPosition)
                return;
            end

            set(obj.SoftHighlightRect, 'Position', newPosition, 'Visible', 'on');
            obj.SoftHighlightLastPosition = newPosition;

            try
                drawnow limitrate nocallbacks;
            catch
                % drawnow may be unsupported in select contexts; ignore
            end
        end

        function hideSelectionOverlay(obj, clearCaseId)
            %HIDESELECTIONOVERLAY Remove persistent selection overlay.
            if nargin < 2
                clearCaseId = false;
            end
            if ~isempty(obj.SelectionRect) && isgraphics(obj.SelectionRect)
                delete(obj.SelectionRect);
            end
            obj.SelectionRect = gobjects(0, 1);
            obj.SelectionAxes = gobjects(0, 1);
            obj.SelectionLastPosition = [NaN NaN NaN NaN];
            if clearCaseId
                obj.SelectionCaseId = "";
            end
        end

        function success = showSelectionOverlay(obj, caseId)
            %SHOWSELECTIONOVERLAY Draw persistent selection outline without full redraw.
            success = false;
            if nargin < 2
                caseId = obj.SelectionCaseId;
            end

            caseId = string(caseId);
            if strlength(caseId) == 0
                obj.hideSelectionOverlay(true);
                return;
            end

            obj.SelectionCaseId = caseId;
            [entry, ~] = obj.findCaseById(caseId);
            if isempty(entry) || ~isfield(entry, 'rectHandle') || ~isgraphics(entry.rectHandle)
                obj.hideSelectionOverlay(false);
                return;
            end

            isLocked = obj.isCaseLocked(caseId);
            timeControlActive = obj.isTimeControlActive();

            rectHandle = entry.rectHandle;
            axesHandle = ancestor(rectHandle, 'axes');
            if isempty(axesHandle) || ~isgraphics(axesHandle)
                obj.hideSelectionOverlay(false);
                return;
            end

            pos = get(rectHandle, 'Position');
            if numel(pos) ~= 4 || any(~isfinite(pos))
                return;
            end

            % Expand selection rectangle outward by lock line thickness to avoid overlap
            lockLinePts = 3;  % Must match lock outline in visualizeDailySchedule
            [growX, growY] = obj.pointsToDataOffsets(axesHandle, lockLinePts);
            selPos = [pos(1)-growX, pos(2)-growY, pos(3)+2*growX, pos(4)+2*growY];

            if isempty(obj.SelectionRect) || ~isgraphics(obj.SelectionRect)
                obj.SelectionRect = rectangle(axesHandle, ...
                    'Position', selPos, ...
                    'EdgeColor', obj.SelectionColor, ...
                    'LineWidth', obj.SelectionLineWidth, ...
                    'FaceColor', 'none', ...
                    'HitTest', 'off', ...
                    'PickableParts', 'none', ...
                    'Clipping', 'on', ...
                    'Tag', 'CaseSelectionOverlay');
            else
                if obj.SelectionRect.Parent ~= axesHandle
                    set(obj.SelectionRect, 'Parent', axesHandle);
                end
                set(obj.SelectionRect, 'Position', selPos, 'Visible', 'on');
            end

            % Create/update resize grip when case is selectable
            % Only show resize grip when case is editable (not locked, not time control)
            canResize = ~isLocked && ~timeControlActive;
            if ~canResize
                if ~isempty(obj.SelectionGrip) && isgraphics(obj.SelectionGrip)
                    set(obj.SelectionGrip, 'Visible', 'off');
                end
                obj.SelectionAxes = axesHandle;
                obj.SelectionLastPosition = selPos;
                try
                    uistack(obj.SelectionRect, 'top');
                catch
                    % ignore stacking issues
                end
                success = true;
                return;
            end

            gripWidth = selPos(3) * 0.6;
            gripX = selPos(1) + (selPos(3) - gripWidth)/2;
            [~, gripHeightHours] = obj.pointsToDataOffsets(axesHandle, 6);
            if ~isfinite(gripHeightHours) || gripHeightHours <= 0
                gripHeightHours = selPos(4) * 0.06;
            end
            gripHeightHours = min(gripHeightHours, selPos(4)/2);
            gripY = selPos(2) + selPos(4) - gripHeightHours;

            if isempty(obj.SelectionGrip) || ~isgraphics(obj.SelectionGrip)
                obj.SelectionGrip = rectangle(axesHandle, ...
                    'Position', [gripX, gripY, gripWidth, gripHeightHours], ...
                    'FaceColor', [1 1 1], 'FaceAlpha', 0.6, ...
                    'EdgeColor', [1 1 1], 'LineWidth', 1.5, ...
                    'HitTest', 'on', 'PickableParts', 'all', ...
                    'Clipping', 'on', 'Tag', 'CaseResizeHandle');
            else
                if obj.SelectionGrip.Parent ~= axesHandle
                    set(obj.SelectionGrip, 'Parent', axesHandle);
                end
                set(obj.SelectionGrip, 'Position', [gripX, gripY, gripWidth, gripHeightHours], 'Visible', 'on');
            end

            if ~isempty(obj.AppHandle) && isprop(obj.AppHandle, 'ScheduleRenderer')
                set(obj.SelectionGrip, 'ButtonDownFcn', @(src, ~) obj.AppHandle.ScheduleRenderer.onCaseResizeMouseDown(obj.AppHandle, src));
            end

            postDuration = obj.safeDifference(obj.extractFieldFromStruct(entry.userData, 'postEnd'), obj.extractFieldFromStruct(entry.userData, 'procEnd'));
            if isnan(postDuration), postDuration = 0; end
            turnoverDuration = obj.safeDifference(obj.extractFieldFromStruct(entry.userData, 'turnoverEnd'), obj.extractFieldFromStruct(entry.userData, 'postEnd'));
            if isnan(turnoverDuration), turnoverDuration = 0; end

            gripData = struct( ...
                'caseId', caseId, ...
                'labIndex', obj.extractFieldFromStruct(entry.userData, 'labIndex'), ...
                'snapMinutes', 5, ...
                'handleHeightHours', gripHeightHours, ...
                'procStart', obj.extractFieldFromStruct(entry.userData, 'procStart'), ...
                'procEnd', obj.extractFieldFromStruct(entry.userData, 'procEnd'), ...
                'setupStart', obj.extractFieldFromStruct(entry.userData, 'setupStart'), ...
                'postDuration', postDuration, ...
                'turnoverDuration', turnoverDuration, ...
                'caseRect', rectHandle);
            obj.SelectionGrip.UserData = gripData;

            obj.SelectionAxes = axesHandle;
            obj.SelectionLastPosition = selPos;
            try
                uistack(obj.SelectionRect, 'top'); uistack(obj.SelectionGrip, 'top');
            catch
                % ignore stacking issues
            end
            try
                drawnow limitrate nocallbacks;
            catch
                % ignore draw timing errors
            end
            success = true;
        end

        function hideSoftHighlight(obj)
            %HIDESOFTHIGHLIGHT Remove temporary overlay when interaction ends.
            if ~isempty(obj.SoftHighlightRect) && isgraphics(obj.SoftHighlightRect)
                delete(obj.SoftHighlightRect);
            end
            obj.SoftHighlightRect = gobjects(0, 1);
            obj.SoftHighlightAxes = gobjects(0, 1);
            obj.SoftHighlightLastPosition = [NaN NaN NaN NaN];
        end

        function tf = hasCase(obj, caseId)
            %HASCASE True when the specified caseId exists in the registry.
            if isempty(obj.CaseIds)
                tf = false;
                return;
            end
            tf = any(obj.CaseIds == string(caseId));
        end

        function [entry, idx] = findCaseById(obj, caseId)
            %FINDCASEBYID Retrieve metadata for a specific case ID.
            entry = struct();
            idx = NaN;

            if isempty(obj.CaseIds) || nargin < 2
                return;
            end

            caseId = string(caseId);
            match = (obj.CaseIds == caseId);
            if ~any(match)
                return;
            end

            idx = find(match, 1, 'first');
            entry = obj.buildEntry(idx);
        end

        function [entry, idx] = findCaseByHandle(obj, rectHandle)
            %FINDCASEBYHANDLE Return metadata for a specific interaction rect.
            entry = struct();
            idx = NaN;

            if isempty(obj.RectHandles) || ~isgraphics(rectHandle)
                return;
            end

            key = obj.handleKey(rectHandle);
            if ~isKey(obj.HandleIndex, key)
                return;
            end

            idx = obj.HandleIndex(key);
            entry = obj.buildEntry(idx);
        end

        function markMotionUpdate(obj)
            %MARKMOTIONUPDATE Record the timestamp of the last motion update.
            obj.LastMotionTimer = tic;
        end

        function tf = shouldThrottleMotion(obj)
            %SHOULDTHROTTLEMOTION Determine if motion handling should skip updates.
            if obj.LastMotionTimer == uint64(0)
                tf = false;
                return;
            end
            elapsed = toc(obj.LastMotionTimer);
            tf = elapsed < obj.MotionThrottleSeconds;
        end

        function seconds = getMotionThrottleSeconds(obj)
            seconds = obj.MotionThrottleSeconds;
        end

        function setMotionThrottleSeconds(obj, seconds)
            arguments
                obj
                seconds (1,1) double {mustBeFinite, mustBeNonnegative}
            end
            obj.MotionThrottleSeconds = seconds;
        end

        function app = getApp(obj)
            %GETAPP Return the app handle associated with the registry.
            app = obj.AppHandle;
        end

        function info = getRegistrySnapshot(obj)
            %GETREGISTRYSNAPSHOT Provide a struct array describing current blocks.
            if isempty(obj.CaseIds)
                info = struct('caseId', string.empty, 'rectHandle', gobjects(0, 1), 'userData', cell(0, 1));
                return;
            end

            info = repmat(struct('caseId', "", 'rectHandle', gobjects(1), 'userData', struct()), numel(obj.CaseIds), 1);
            for idx = 1:numel(obj.CaseIds)
                info(idx).caseId = obj.CaseIds(idx);
                info(idx).rectHandle = obj.RectHandles(idx);
                info(idx).userData = obj.UserDataCells{idx};
            end
        end

        function ts = lastRegistryUpdate(obj)
            ts = obj.LastRegistryUpdate;
        end

        function drag = getActiveDrag(obj)
            %GETACTIVEDRAG Return the currently tracked drag state (if any).
            drag = obj.ActiveDrag;
        end

        function setActiveDrag(obj, dragState)
            %SETACTIVEDRAG Store the current drag state.
            if nargin < 2
                dragState = struct();
            end
            obj.ActiveDrag = dragState;
        end

        function clearActiveDrag(obj)
            %CLEARACTIVEDRAG Reset drag state metadata.
            obj.ActiveDrag = struct();
            obj.LastMotionTimer = uint64(0);
        end

        function tf = hasActiveDrag(obj)
            %HASACTIVEDRAG True when a drag state is currently tracked.
            tf = ~isempty(fieldnames(obj.ActiveDrag));
        end

        function setActiveResize(obj, resizeState)
            if nargin < 2
                resizeState = struct();
            end
            obj.ActiveResize = resizeState;
        end

        function resize = getActiveResize(obj)
            resize = obj.ActiveResize;
        end

        function clearActiveResize(obj)
            obj.ActiveResize = struct();
            obj.LastMotionTimer = uint64(0);
        end

        function tf = hasActiveResize(obj)
            tf = ~isempty(fieldnames(obj.ActiveResize));
        end

        function enableTimingDebug(obj, tf)
            if nargin < 2
                tf = true;
            end
            obj.DebugTiming = logical(tf);
        end
    end

    methods (Access = private)
        function [dxLabs, dyHours] = pointsToDataOffsets(~, ax, points)
            if nargin < 3 || isempty(points)
                points = 1;
            end
            % Points to pixels
            dpi = 96;
            try
                dpi = get(0, 'ScreenPixelsPerInch');
            catch
            end
            px = (points / 72) * dpi;

            % Axes pixel size
            origUnits = ax.Units;
            ax.Units = 'pixels';
            pos = ax.Position;
            ax.Units = origUnits;
            axPixW = max(1, pos(3));
            axPixH = max(1, pos(4));

            xLim = xlim(ax); yLim = ylim(ax);
            xRange = abs(diff(xLim)); yRange = abs(diff(yLim));

            dxLabs = (px / axPixW) * xRange;
            dyHours = (px / axPixH) * yRange;
        end

        function value = extractFieldFromStruct(~, s, fieldName)
            value = NaN;
            if isstruct(s) && isfield(s, fieldName)
                value = s.(fieldName);
            end
        end

        function diffValue = safeDifference(~, a, b)
            if isnan(a) || isnan(b)
                diffValue = NaN;
            else
                diffValue = a - b;
            end
        end

        function tf = isCaseLocked(obj, caseId)
            tf = false;
            if isempty(obj.AppHandle)
                return;
            end
            if isprop(obj.AppHandle, 'LockedCaseIds')
                tf = ismember(caseId, obj.AppHandle.LockedCaseIds);
            end
        end

        function tf = isTimeControlActive(obj)
            tf = false;
            if isempty(obj.AppHandle)
                return;
            end
            if isprop(obj.AppHandle, 'IsTimeControlActive')
                tf = obj.AppHandle.IsTimeControlActive;
            end
        end
        function entry = buildEntry(obj, idx)
            entry = struct( ...
                'caseId', obj.CaseIds(idx), ...
                'rectHandle', obj.RectHandles(idx), ...
                'userData', obj.UserDataCells{idx} ...
            );
        end

        function map = buildHandleIndex(obj, handles)
            map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for idx = 1:numel(handles)
                h = handles(idx);
                if ~isgraphics(h)
                    continue;
                end
                map(obj.handleKey(h)) = idx;
            end
        end

        function key = handleKey(~, handle)
            try
                handleId = uint64(handle);
            catch
                handleId = uint64(randi(intmax('uint32'))); %#ok<RANDI>
            end
            key = sprintf('h%016x', handleId);
        end

        function tf = debugTimingEnabled(obj)
            tf = obj.DebugTiming;
            persistent envFlag
            if tf
                return;
            end
            if isempty(envFlag)
                envFlag = ~isempty(getenv('SOFTHIGHLIGHT_DEBUG'));
            end
            tf = envFlag;
        end

    end
end
