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
                        continue;
                    end

                    position = get(rectHandle, 'Position');
                    if numel(position) ~= 4 || position(3) <= 0 || position(4) <= 0
                        continue;
                    end

                    resources = conduction.gui.renderers.ResourceOverlayRenderer.extractResourceIds(caseStruct);
                    conduction.gui.renderers.ResourceOverlayRenderer.attachResourceMetadata(rectHandle, resources);

                    if ~isempty(resources)
                        conduction.gui.renderers.ResourceOverlayRenderer.drawBadges(ax, caseId, position, resources, resourceMap);
                    end

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

            if isstruct(appOrAxes) || isobject(appOrAxes)
                if isfield(appOrAxes, 'ScheduleAxes')
                    candidate = appOrAxes.ScheduleAxes;
                    if ~isempty(candidate)
                        ax = candidate;
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

        function resources = extractResourceIds(caseStruct)
            resources = string.empty(0, 1);
            candidates = {"requiredResources", "requiredResourceIds", "RequiredResourceIds"};
            for idx = 1:numel(candidates)
                fieldName = candidates{idx};
                if isfield(caseStruct, fieldName) && ~isempty(caseStruct.(fieldName))
                    raw = caseStruct.(fieldName);
                    if isstring(raw)
                        resources = raw(:);
                    elseif iscellstr(raw) || ischar(raw)
                        resources = string(raw);
                        resources = resources(:);
                    elseif isnumeric(raw)
                        resources = string(raw(:));
                    end
                    break;
                end
            end

            mask = strlength(resources) > 0;
            resources = unique(resources(mask), 'stable');
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

        function drawBadges(ax, caseId, position, resources, resourceMap)
            if isempty(resources)
                return;
            end

            numResources = numel(resources);
            badgeHeight = position(4) * 0.3;
            badgeHeight = min(badgeHeight, 0.35);
            badgeHeight = max(badgeHeight, min(position(4), 0.06));
            badgeHeight = min(badgeHeight, position(4));
            badgeY = position(2) + position(4) - badgeHeight;

            for rIdx = 1:numResources
                resourceId = resources(rIdx);
                color = [0.45 0.45 0.45];
                if isKey(resourceMap, char(resourceId))
                    color = resourceMap(char(resourceId)).Color;
                end

                badgeWidth = position(3) / numResources;
                badgeX = position(1) + (rIdx - 1) * badgeWidth;

                badge = rectangle(ax, 'Position', [badgeX, badgeY, badgeWidth, badgeHeight], ...
                    'FaceColor', color, 'FaceAlpha', 0.85, 'EdgeColor', 'none', ...
                    'Tag', 'ResourceBadge', 'HitTest', 'off');
                if isprop(badge, 'PickableParts')
                    badge.PickableParts = 'none';
                end
                badge.UserData = struct('caseId', caseId, 'resourceId', resourceId);
                uistack(badge, 'top');
            end
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
                'FaceColor', [0 0 0], 'FaceAlpha', 0.55, 'EdgeColor', 'none', ...
                'Tag', 'ResourceHighlightMask', 'HitTest', 'off');
            if isprop(mask, 'PickableParts')
                mask.PickableParts = 'none';
            end
            mask.UserData = struct('caseId', caseId);
            uistack(mask, 'top');
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
