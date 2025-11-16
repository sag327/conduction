classdef ResourceOverlayRenderer
    %RESOURCEOVERLAYRENDERER Draw shared resource visuals on the schedule canvas.
    %   Static helpers used by ScheduleRenderer to add per-case resource badges and
    %   highlight masks based on the current resource selection.

    methods (Static)
        function draw(app, dailySchedule, resourceTypes, highlightIds)
            arguments
                app
                dailySchedule
                resourceTypes struct = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {})
                highlightIds string = string.empty(0, 1)
            end

            ax = conduction.gui.renderers.ResourceOverlayRenderer.resolveAxes(app);
            conduction.gui.renderers.ResourceOverlayRenderer.clear(ax);

            if isempty(ax) || ~isvalid(ax)
                return;
            end

            if isempty(dailySchedule)
                return;
            end

            isSchedule = isa(dailySchedule, 'conduction.DailySchedule');
            if ~isSchedule
                return;
            end

            assignments = dailySchedule.labAssignments();
            if isempty(assignments)
                return;
            end

            resourceMap = conduction.gui.renderers.ResourceOverlayRenderer.buildResourceMap(resourceTypes);
            highlightIds = unique(string(highlightIds(:)), 'stable');
            highlightActive = ~isempty(highlightIds);

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                labCases = labCases(:);

                for caseIdx = 1:numel(labCases)
                    caseStruct = labCases(caseIdx);
                    caseId = conduction.gui.renderers.ResourceOverlayRenderer.extractCaseId(caseStruct);
                    if strlength(caseId) == 0
                        continue;
                    end

                    rectHandle = conduction.gui.renderers.ResourceOverlayRenderer.locateCaseBlockHandle(ax, caseId);
                    if isempty(rectHandle) || ~isgraphics(rectHandle)
                        % Fallback: compute approximate rectangle from schedule data
                        position = conduction.gui.renderers.ResourceOverlayRenderer.computeCaseRectPosition(ax, caseStruct);
                        if isempty(position)
                            continue;
                        end
                    else
                        position = get(rectHandle, 'Position');
                        if numel(position) ~= 4 || position(3) <= 0 || position(4) <= 0
                            % Use fallback if existing rectangle invalid
                            position = conduction.gui.renderers.ResourceOverlayRenderer.computeCaseRectPosition(ax, caseStruct);
                            if isempty(position)
                                continue;
                            end
                        end
                    end

                    resources = conduction.gui.renderers.ResourceOverlayRenderer.extractResourceIds(app, caseStruct, caseId);
                    conduction.gui.renderers.ResourceOverlayRenderer.attachResourceMetadata(rectHandle, resources);

                    caseHasHighlight = false;
                    outlineColor = [1 1 1];
                    if highlightActive
                        matchIds = intersect(resources, highlightIds, 'stable');
                        if ~isempty(matchIds)
                            caseHasHighlight = true;
                            key = char(matchIds(1));
                            if isKey(resourceMap, key)
                                outlineColor = resourceMap(key).Color;
                            end
                        end
                    end
                    conduction.gui.renderers.ResourceOverlayRenderer.drawHighlightMask(ax, caseId, position, highlightActive, caseHasHighlight, outlineColor);
                end
            end
        end

        function clear(appOrAxes)
            ax = conduction.gui.renderers.ResourceOverlayRenderer.resolveAxes(appOrAxes);
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            delete(findobj(ax, 'Tag', 'ResourceBadge'));
            delete(findobj(ax, 'Tag', 'ResourceHighlightMask'));
            delete(findobj(ax, 'Tag', 'ResourceHighlightOutline'));
        end

        function updateCaseBlockMetadata(ax, schedule, app)
            if isempty(ax) || ~isgraphics(ax)
                return;
            end
            if isempty(schedule) || ~isa(schedule, 'conduction.DailySchedule')
                return;
            end

            try
                assignments = schedule.labAssignments();
            catch
                assignments = {};
            end
            if isempty(assignments)
                return;
            end

            blocks = findobj(ax, 'Tag', 'CaseBlock');
            if isempty(blocks)
                return;
            end

            blockMap = containers.Map('KeyType','char','ValueType','any');
            for idx = 1:numel(blocks)
                payload = get(blocks(idx), 'UserData');
                if isstruct(payload) && isfield(payload, 'caseId')
                    caseId = char(string(payload.caseId));
                    if strlength(caseId) > 0
                        blockMap(caseId) = blocks(idx);
                    end
                end
            end

            if blockMap.Count == 0
                return;
            end

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                labCases = labCases(:);
                for caseIdx = 1:numel(labCases)
                    caseStruct = labCases(caseIdx);
                    caseId = conduction.gui.renderers.ResourceOverlayRenderer.extractCaseId(caseStruct);
                    if strlength(caseId) == 0 || ~blockMap.isKey(char(caseId))
                        continue;
                    end
                    resources = conduction.gui.renderers.ResourceOverlayRenderer.extractResourceIds(app, caseStruct, caseId);
                    conduction.gui.renderers.ResourceOverlayRenderer.attachResourceMetadata(blockMap(char(caseId)), resources);
                end
            end
        end
    end

    methods (Static, Access = private)
        function ax = resolveAxes(appOrAxes)
            if isa(appOrAxes, 'matlab.ui.control.UIAxes')
                ax = appOrAxes;
                return;
            end

            ax = [];
            if isempty(appOrAxes)
                return;
            end

            if isstruct(appOrAxes)
                if isfield(appOrAxes, 'ScheduleAxes')
                    candidate = appOrAxes.ScheduleAxes;
                    if ~isempty(candidate)
                        ax = candidate;
                    end
                end
            elseif isobject(appOrAxes)
                if isprop(appOrAxes, 'ScheduleAxes')
                    try
                        candidate = appOrAxes.ScheduleAxes;
                        if ~isempty(candidate)
                            ax = candidate;
                        end
                    catch
                        % Ignore property access issues
                    end
                end
            end
        end

        function resourceMap = buildResourceMap(resourceTypes)
            resourceMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if isempty(resourceTypes)
                return;
            end

            for idx = 1:numel(resourceTypes)
                item = resourceTypes(idx);
                entry = struct();
                entry.Name = string(conduction.gui.renderers.ResourceOverlayRenderer.safeField(item, 'Name', ""));
                entry.Color = conduction.gui.renderers.ResourceOverlayRenderer.safeColor(item);
                resourceMap(char(item.Id)) = entry;
            end
        end

        function value = safeField(structValue, fieldName, defaultValue)
            if isstruct(structValue) && isfield(structValue, fieldName)
                value = structValue.(fieldName);
            else
                value = defaultValue;
            end
        end

        function color = safeColor(item)
            defaultColor = [0.45, 0.45, 0.45];
            if ~isstruct(item) || ~isfield(item, 'Color')
                color = defaultColor;
                return;
            end

            candidate = double(item.Color);
            if numel(candidate) ~= 3 || any(~isfinite(candidate))
                color = defaultColor;
                return;
            end

            color = max(0, min(1, candidate(:)'));
        end

        function caseId = extractCaseId(caseStruct)
            caseId = "";
            candidates = ["caseID", "caseId", "CaseId"];
            for idx = 1:numel(candidates)
                fieldName = candidates(idx);
                if isfield(caseStruct, fieldName)
                    value = caseStruct.(fieldName);
                    if ~(isstring(value) || ischar(value))
                        continue;
                    end
                    caseId = string(value);
                    if strlength(caseId) > 0
                        return;
                    end
                end
            end
        end

        function resources = extractResourceIds(app, caseStruct, caseId)
            scheduleResources = string.empty(0, 1);
            candidates = {"requiredResources", "requiredResourceIds", "RequiredResourceIds"};
            for idx = 1:numel(candidates)
                fieldName = candidates{idx};
                if isfield(caseStruct, fieldName) && ~isempty(caseStruct.(fieldName))
                    raw = caseStruct.(fieldName);
                    if isstring(raw)
                        scheduleResources = raw(:);
                    elseif iscellstr(raw) || ischar(raw)
                        scheduleResources = string(raw);
                        scheduleResources = scheduleResources(:);
                    elseif isnumeric(raw)
                        scheduleResources = string(raw(:));
                    end
                    break;
                end
            end

            caseManagerResources = string.empty(0, 1);
            if nargin >= 3 && ~isempty(app)
                try
                    if isprop(app, 'CaseManager') && ~isempty(app.CaseManager)
                        % Prefer persistent CaseId lookup
                        [caseObj, ~] = app.CaseManager.findCaseById(caseId);
                        % Fallback: locate by CaseNumber if CaseId doesn’t match schedule structures
                        if isempty(caseObj)
                            % Attempt to read caseNumber from the schedule case struct
                            caseNumber = NaN;
                            if isstruct(caseStruct)
                                if isfield(caseStruct, 'caseNumber') && ~isempty(caseStruct.caseNumber)
                                    caseNumber = double(caseStruct.caseNumber);
                                elseif isfield(caseStruct, 'CaseNumber') && ~isempty(caseStruct.CaseNumber)
                                    caseNumber = double(caseStruct.CaseNumber);
                                end
                            end
                            if ~isnan(caseNumber)
                                try
                                    for k = 1:app.CaseManager.CaseCount
                                        c = app.CaseManager.getCase(k);
                                        if ~isnan(c.CaseNumber) && double(c.CaseNumber) == caseNumber
                                            caseObj = c; %#ok<AGROW>
                                            break;
                                        end
                                    end
                                catch
                                end
                            end
                        end
                        if ~isempty(caseObj)
                            caseManagerResources = caseObj.listRequiredResources();
                        end
                    end
                catch
                    % ignore lookup failures
                end
            end

            combined = [scheduleResources(:); caseManagerResources(:)];
            mask = strlength(combined) > 0;
            resources = unique(combined(mask), 'stable');
        end

        function attachResourceMetadata(rectHandle, resources)
            if isempty(rectHandle) || ~isgraphics(rectHandle)
                return;
            end

            payload = get(rectHandle, 'UserData');
            if ~isstruct(payload)
                payload = struct();
            end
            payload.resourceIds = resources;
            set(rectHandle, 'UserData', payload);
        end

        function drawHighlightMask(ax, caseId, position, highlightActive, caseHasHighlight, outlineColor)
            if ~highlightActive
                return;
            end

            if caseHasHighlight
                if nargin < 6 || isempty(outlineColor)
                    outlineColor = [1 1 1];
                end
                outline = rectangle(ax, 'Position', position, ...
                    'FaceColor', 'none', 'EdgeColor', outlineColor, 'LineWidth', 2.2, ...
                    'Tag', 'ResourceHighlightOutline', 'HitTest', 'off');
                if isprop(outline, 'PickableParts')
                    outline.PickableParts = 'none';
                end
                outline.UserData = struct('caseId', caseId);
                uistack(outline, 'top');
                return;
            end

            mask = rectangle(ax, 'Position', position, ...
                'FaceColor', [0 0 0], 'FaceAlpha', 0.6875, 'EdgeColor', 'none', ...
                'Tag', 'ResourceHighlightMask', 'HitTest', 'off');
            if isprop(mask, 'PickableParts')
                mask.PickableParts = 'none';
            end
            mask.UserData = struct('caseId', caseId);
            uistack(mask, 'top');
        end

        

        function pos = computeCaseRectPosition(ax, caseStruct)
            pos = [];
            if isempty(ax) || ~isgraphics(ax)
                return;
            end
            % Determine lab index (x center)
            labIndex = NaN;
            if isfield(caseStruct, 'lab') && ~isempty(caseStruct.lab)
                labIndex = double(caseStruct.lab);
            elseif isfield(caseStruct, 'labIndex') && ~isempty(caseStruct.labIndex)
                labIndex = double(caseStruct.labIndex);
            end
            if ~isfinite(labIndex)
                return;
            end

            % Determine times (minutes), then convert to hours (y axis units)
            startMinutes = NaN;
            endMinutes = NaN;
            if isfield(caseStruct, 'startTime') && ~isempty(caseStruct.startTime)
                startMinutes = double(caseStruct.startTime);
            elseif isfield(caseStruct, 'setupStartTime') && ~isempty(caseStruct.setupStartTime)
                startMinutes = double(caseStruct.setupStartTime);
            end
            if isfield(caseStruct, 'endTime') && ~isempty(caseStruct.endTime)
                endMinutes = double(caseStruct.endTime);
            elseif isfield(caseStruct, 'turnoverEnd') && ~isempty(caseStruct.turnoverEnd)
                endMinutes = double(caseStruct.turnoverEnd);
            elseif isfield(caseStruct, 'procEndTime') && ~isempty(caseStruct.procEndTime)
                % Use procedure end if nothing else
                endMinutes = double(caseStruct.procEndTime);
            end
            if ~isfinite(startMinutes) || ~isfinite(endMinutes) || endMinutes <= startMinutes
                return;
            end

            startHour = startMinutes / 60;
            endHour = endMinutes / 60;
            height = max(endHour - startHour, eps);

            % Choose a reasonable bar width centered at lab index
            barWidth = 0.9;
            x = labIndex - barWidth/2;
            y = startHour;
            pos = [x, y, barWidth, height];
        end

        function rectHandle = locateCaseBlockHandle(ax, caseId)
            rectHandle = [];
            if isempty(ax) || ~isgraphics(ax)
                return;
            end

            blocks = findobj(ax, 'Tag', 'CaseBlock');
            for idx = 1:numel(blocks)
                candidate = blocks(idx);
                if ~isgraphics(candidate)
                    continue;
                end
                payload = get(candidate, 'UserData');
                if ~isstruct(payload) || ~isfield(payload, 'caseId')
                    continue;
                end
                if string(payload.caseId) == caseId
                    rectHandle = candidate;
                    return;
                end
            end
        end
    end
end
