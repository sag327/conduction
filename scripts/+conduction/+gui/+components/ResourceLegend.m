classdef ResourceLegend < handle
    %RESOURCELEGEND Legend and highlight controller for shared resources.

    events
        HighlightChanged
    end

    properties (SetAccess = private)
        Parent
        Highlights string = string.empty(0, 1)
    end

    properties (Access = private)
        HighlightCallback function_handle = function_handle.empty
        Grid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        HeaderLabel matlab.ui.control.Label = matlab.ui.control.Label.empty
        ListGrid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        EmptyLabel matlab.ui.control.Label = matlab.ui.control.Label.empty
        CheckboxMap containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'any')
        ResourceTypes struct = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {})
        ResourceSummary struct = struct('ResourceId', {}, 'CaseIds', {})
        IsSyncing logical = false
    end

    methods
        function obj = ResourceLegend(parent, varargin)
            if nargin < 1
                error('ResourceLegend:InvalidInputs', 'A parent container is required.');
            end

            if ~(isa(parent, 'matlab.ui.Figure') || isa(parent, 'matlab.ui.container.Panel') || isa(parent, 'matlab.ui.container.GridLayout'))
                error('ResourceLegend:InvalidParent', 'Parent must be a valid UI container.');
            end

            parser = inputParser;
            addParameter(parser, 'HighlightChangedFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));
            parse(parser, varargin{:});
            opts = parser.Results;

            obj.Parent = parent;
            obj.HighlightCallback = opts.HighlightChangedFcn;
            obj.CheckboxMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

            obj.buildUI();
        end

        function delete(obj)
            if ~isempty(obj.Grid) && isvalid(obj.Grid)
                delete(obj.Grid);
            end
        end

        function setData(obj, resourceTypes, summary)
            if nargin < 2 || isempty(resourceTypes)
                resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            end
            if nargin < 3 || isempty(summary)
                summary = struct('ResourceId', {}, 'CaseIds', {});
            end

            obj.ResourceTypes = resourceTypes;
            obj.ResourceSummary = summary;
            obj.rebuildList();
            obj.setHighlights(obj.Highlights, true);
        end

        function changed = setHighlights(obj, resourceIds, suppressEvent)
            if nargin < 2
                resourceIds = string.empty(0, 1);
            end
            if nargin < 3
                suppressEvent = false;
            end

            resourceIds = unique(string(resourceIds(:)), 'stable');
            keys = string(obj.CheckboxMap.keys);
            if isempty(keys)
                resourceIds = string.empty(0, 1);
            else
                resourceIds = resourceIds(ismember(resourceIds, keys));
            end

            if numel(resourceIds) > 1
                resourceIds = resourceIds(1);
            end

            changed = ~isequal(resourceIds, obj.Highlights);
            obj.Highlights = resourceIds;

            obj.IsSyncing = true;
            cleaner = onCleanup(@() obj.resetSyncFlag()); %#ok<NASGU>
            for idx = 1:numel(keys)
                checkbox = obj.CheckboxMap(char(keys(idx)));
                if ~isvalid(checkbox)
                    continue;
                end
                checkbox.Value = any(obj.Highlights == string(checkbox.Tag));
            end

            if changed && ~suppressEvent
                obj.fireHighlightChanged();
            end
        end

        function ids = getHighlights(obj)
            ids = obj.Highlights;
        end
    end

    methods (Access = private)
        function buildUI(obj)
            obj.Grid = uigridlayout(obj.Parent);
            obj.Grid.RowHeight = {'fit', '1x'};
            obj.Grid.ColumnWidth = {'1x'};
            obj.Grid.RowSpacing = 6;
            obj.Grid.ColumnSpacing = 0;
            obj.Grid.Padding = [6 6 6 6];

            obj.HeaderLabel = uilabel(obj.Grid);
            obj.HeaderLabel.Text = 'Resources';
            obj.HeaderLabel.FontWeight = 'bold';
            obj.HeaderLabel.Layout.Row = 1;
            obj.HeaderLabel.Layout.Column = 1;

            obj.ListGrid = uigridlayout(obj.Grid);
            obj.ListGrid.Layout.Row = 2;
            obj.ListGrid.Layout.Column = 1;
            obj.ListGrid.RowSpacing = 4;
            obj.ListGrid.ColumnSpacing = 0;
            obj.ListGrid.Padding = [0 0 0 0];
            obj.ListGrid.ColumnWidth = {'1x'};

            obj.rebuildList();
        end

        function rebuildList(obj)
            delete(allchild(obj.ListGrid));
            obj.CheckboxMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.EmptyLabel = matlab.ui.control.Label.empty;

            if isempty(obj.ResourceTypes)
                obj.ListGrid.RowHeight = {'fit'};
                obj.EmptyLabel = uilabel(obj.ListGrid);
                obj.EmptyLabel.Text = 'No resources defined';
                obj.EmptyLabel.FontColor = [0.6 0.6 0.6];
                obj.EmptyLabel.HorizontalAlignment = 'center';
                obj.EmptyLabel.Layout.Row = 1;
                obj.EmptyLabel.Layout.Column = 1;
                return;
            end

            obj.ListGrid.RowHeight = repmat({'fit'}, 1, numel(obj.ResourceTypes));
            counts = conduction.gui.components.ResourceLegend.buildCountMap(obj.ResourceSummary);

            for idx = 1:numel(obj.ResourceTypes)
                entry = obj.ResourceTypes(idx);
                row = uigridlayout(obj.ListGrid);
                row.ColumnWidth = {16, '1x', 'fit'};
                row.RowHeight = {'fit'};
                row.ColumnSpacing = 6;
                row.RowSpacing = 0;
                row.Padding = [0 0 0 0];
                row.BackgroundColor = obj.Grid.BackgroundColor;
                row.Layout.Row = idx;
                row.Layout.Column = 1;

                colorPatch = uipanel(row);
                colorPatch.Layout.Row = 1;
                colorPatch.Layout.Column = 1;
                colorPatch.BorderType = 'line';
                colorPatch.BorderWidth = 1;
                colorPatch.BackgroundColor = conduction.gui.components.ResourceLegend.safeColor(entry.Color);

                toggle = uicheckbox(row);
                toggle.Text = char(entry.Name);
                toggle.Layout.Row = 1;
                toggle.Layout.Column = 2;
                toggle.Tag = char(entry.Id);
                toggle.ValueChangedFcn = @(src, ~) obj.onToggleChanged(src);

                infoLabel = uilabel(row);
                infoLabel.Layout.Row = 1;
                infoLabel.Layout.Column = 3;
                caseCount = conduction.gui.components.ResourceLegend.lookupCount(counts, entry.Id);
                infoLabel.Text = sprintf('Cap %g | Cases %d', entry.Capacity, caseCount);
                infoLabel.FontColor = [0.75 0.75 0.75];

                if entry.Capacity <= 0
                    toggle.Enable = 'off';
                    infoLabel.FontColor = [0.55 0.55 0.55];
                end

                obj.CheckboxMap(char(entry.Id)) = toggle;
            end
        end

        function onToggleChanged(obj, checkbox)
            if obj.IsSyncing || isempty(checkbox) || ~isvalid(checkbox)
                return;
            end

            resourceId = string(checkbox.Tag);
            if strcmpi(checkbox.Enable, 'off')
                checkbox.Value = false;
                return;
            end

            if checkbox.Value
                obj.setHighlights(resourceId, true);
            else
                obj.setHighlights(string.empty(0, 1), true);
            end

            obj.fireHighlightChanged();
        end

        function fireHighlightChanged(obj)
            if ~isempty(obj.HighlightCallback)
                obj.HighlightCallback(obj.Highlights);
            end
            notify(obj, 'HighlightChanged');
        end

        function resetSyncFlag(obj)
            obj.IsSyncing = false;
        end
    end

    methods (Static, Access = private)
        function counts = buildCountMap(summary)
            counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if isempty(summary)
                return;
            end
            for idx = 1:numel(summary)
                item = summary(idx);
                if ~isfield(item, 'ResourceId')
                    continue;
                end
                caseIds = string(conduction.gui.components.ResourceLegend.safeField(item, 'CaseIds', string.empty(0, 1)));
                caseIds = caseIds(strlength(caseIds) > 0);
                counts(char(item.ResourceId)) = numel(caseIds);
            end
        end

        function count = lookupCount(counts, resourceId)
            if counts.isKey(char(resourceId))
                count = counts(char(resourceId));
            else
                count = 0;
            end
        end

        function color = safeColor(candidate)
            color = [0.45 0.45 0.45];
            if isempty(candidate)
                return;
            end
            candidate = double(candidate);
            if numel(candidate) ~= 3 || any(~isfinite(candidate))
                return;
            end
            color = max(0, min(1, candidate(:)'));
        end

        function value = safeField(source, fieldName, defaultValue)
            if isstruct(source) && isfield(source, fieldName)
                value = source.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
