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

        % Prepared for future throttling logic (Phase 3)
        LastMotionTimer uint64 = uint64(0)
        MotionThrottleSeconds double = 0.016  % ~60 Hz default
        ActiveDrag struct = struct()
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
        end

        function clearRegistry(obj)
            %CLEARREGISTRY Remove all tracked case block metadata.
            obj.CaseIds = string.empty(0, 1);
            obj.RectHandles = gobjects(0, 1);
            obj.UserDataCells = cell(0, 1);
            obj.HandleIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.LastRegistryUpdate = NaT;
            obj.LastMotionTimer = uint64(0);
            obj.AppHandle = conduction.gui.ProspectiveSchedulerApp.empty;
            obj.ActiveDrag = struct();
        end

        function ids = listCaseIds(obj)
            %LISTCASEIDS Return all registered case IDs.
            ids = obj.CaseIds;
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
            obj.LastMotionTimer = NaN;
        end

        function tf = hasActiveDrag(obj)
            %HASACTIVEDRAG True when a drag state is currently tracked.
            tf = ~isempty(fieldnames(obj.ActiveDrag));
        end
    end

    methods (Access = private)
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

    end
end
