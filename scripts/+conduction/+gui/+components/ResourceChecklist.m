classdef ResourceChecklist < handle
    %RESOURCECHECKLIST Display and edit resource selections with checkboxes.

    events
        SelectionChanged
    end

    properties (SetAccess = private)
        Parent
        Store conduction.gui.stores.ResourceStore
        Options struct
        Selection string = string.empty(0, 1)
    end

    properties (Access = private)
        Grid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        ScrollPanel matlab.ui.container.Panel = matlab.ui.container.Panel.empty
        ListGrid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        CreateButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        EmptyLabel matlab.ui.control.Label = matlab.ui.control.Label.empty
        CheckboxMap containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'any')
        StoreListener event.listener = event.listener.empty
        IsSyncing logical = false
    end

    methods
        function obj = ResourceChecklist(parent, store, opts)
            arguments
                parent
                store (1,1) conduction.gui.stores.ResourceStore
                opts.Title (1,1) string = "Resources"
                opts.SelectionChangedFcn = []
                opts.CreateCallback = []
                opts.ShowCreateButton (1,1) logical = true
            end

            obj.Parent = parent;
            obj.Store = store;
            obj.Options = opts;

            obj.buildUI();
            obj.rebuildCheckboxes();
            obj.attachStoreListener();
        end

        function delete(obj)
            if ~isempty(obj.StoreListener) && isvalid(obj.StoreListener)
                delete(obj.StoreListener);
            end
            if ~isempty(obj.Grid) && isvalid(obj.Grid)
                delete(obj.Grid);
            end
        end

        function setSelection(obj, resourceIds)
            resourceIds = unique(string(resourceIds(:)), 'stable');
            if isempty(obj.CheckboxMap)
                obj.Selection = resourceIds;
            else
                keys = string(obj.CheckboxMap.keys);
                obj.Selection = resourceIds(ismember(resourceIds, keys));
            end
            obj.syncCheckboxes();
            obj.fireSelectionChanged();
        end

        function ids = getSelection(obj)
            ids = obj.Selection;
        end

        function refresh(obj)
            obj.rebuildCheckboxes();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            parent = obj.Parent;
            if isa(parent, 'matlab.ui.container.GridLayout') || isa(parent, 'matlab.ui.container.Panel') || isa(parent, 'matlab.ui.Figure')
                % ok
            else
                error('ResourceChecklist:InvalidParent', 'Parent must be a UI container.');
            end

            obj.Grid = uigridlayout(parent);
            obj.Grid.RowHeight = {'fit', '1x', 'fit'};
            obj.Grid.ColumnWidth = {'1x'};
            obj.Grid.Padding = [0 0 0 0];
            obj.Grid.RowSpacing = 6;
            obj.Grid.ColumnSpacing = 0;

            titleLabel = uilabel(obj.Grid);
            titleLabel.Text = char(obj.Options.Title);
            titleLabel.FontWeight = 'bold';
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = 1;

            obj.ScrollPanel = uipanel(obj.Grid);
            obj.ScrollPanel.Layout.Row = 2;
            obj.ScrollPanel.Layout.Column = 1;
            obj.ScrollPanel.BorderType = 'none';
            obj.ScrollPanel.Scrollable = 'on';
            obj.ScrollPanel.BackgroundColor = obj.inferBackground();

            obj.ListGrid = uigridlayout(obj.ScrollPanel);
            obj.ListGrid.ColumnWidth = {'1x'};
            obj.ListGrid.RowHeight = {};
            obj.ListGrid.RowSpacing = 2;
            obj.ListGrid.ColumnSpacing = 0;
            obj.ListGrid.Padding = [0 0 0 0];
            obj.ListGrid.BackgroundColor = obj.ScrollPanel.BackgroundColor;

            obj.CreateButton = uibutton(obj.Grid, 'push');
            obj.CreateButton.Text = 'Create New Resource…';
            obj.CreateButton.Layout.Row = 3;
            obj.CreateButton.Layout.Column = 1;
            obj.CreateButton.ButtonPushedFcn = @(src, evt) obj.onCreatePressed();
            obj.CreateButton.Visible = matlab.lang.OnOffSwitchState(obj.Options.ShowCreateButton);
            if isempty(obj.Options.CreateCallback)
                obj.CreateButton.Enable = 'off';
            end
        end

        function attachStoreListener(obj)
            if isempty(obj.Store) || ~isvalid(obj.Store)
                return;
            end
            obj.StoreListener = addlistener(obj.Store, 'TypesChanged', @(~,~) obj.onStoreChanged());
        end

        function onStoreChanged(obj)
            if ~isvalid(obj)
                return;
            end
            obj.rebuildCheckboxes();
        end

        function rebuildCheckboxes(obj)
            % Preserve current selection
            currentSelection = obj.Selection;

            % Delete existing controls
            keys = obj.CheckboxMap.keys;
            for k = 1:numel(keys)
                cb = obj.CheckboxMap(keys{k});
                if isvalid(cb)
                    delete(cb);
                end
            end
            obj.CheckboxMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

            if ~isempty(obj.EmptyLabel) && isvalid(obj.EmptyLabel)
                delete(obj.EmptyLabel);
            end
            obj.EmptyLabel = matlab.ui.control.Label.empty;

            types = obj.Store.list();
            if isempty(types)
                obj.ListGrid.RowHeight = {'fit'};
                obj.EmptyLabel = uilabel(obj.ListGrid);
                obj.EmptyLabel.Text = 'No resources defined';
                obj.EmptyLabel.FontColor = [0.65 0.65 0.65];
                obj.EmptyLabel.HorizontalAlignment = 'center';
                obj.EmptyLabel.Layout.Row = 1;
                obj.EmptyLabel.Layout.Column = 1;
                obj.CreateButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.Options.CreateCallback));
                obj.Selection = string.empty(0, 1);
                return;
            end

            % Sort by name for stable display
            names = string({types.Name});
            [~, order] = sort(lower(names));
            types = types(order);

            obj.ListGrid.RowHeight = repmat({'fit'}, 1, numel(types));
            validSelection = string.empty(0, 1);
            for idx = 1:numel(types)
                type = types(idx);
                checkbox = uicheckbox(obj.ListGrid);
                checkbox.Text = char(type.Name);
                checkbox.Value = any(currentSelection == type.Id);
                checkbox.Layout.Row = idx;
                checkbox.Layout.Column = 1;
                checkbox.ValueChangedFcn = @(src, evt) obj.onCheckboxChanged(src);
                checkbox.Tag = char(type.Id);
                obj.CheckboxMap(char(type.Id)) = checkbox;
                if checkbox.Value
                    validSelection(end+1, 1) = type.Id; %#ok<AGROW>
                end
            end

            obj.Selection = validSelection;
            obj.CreateButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.Options.CreateCallback));
            obj.syncCheckboxes();
        end

        function syncCheckboxes(obj)
            obj.IsSyncing = true;
            cleanup = onCleanup(@() obj.resetSyncFlag()); %#ok<NASGU>

            keys = obj.CheckboxMap.keys;
            for k = 1:numel(keys)
                checkbox = obj.CheckboxMap(keys{k});
                if ~isvalid(checkbox)
                    continue;
                end
                checkbox.Value = any(obj.Selection == string(checkbox.Tag));
            end
        end

        function resetSyncFlag(obj)
            obj.IsSyncing = false;
        end

        function onCheckboxChanged(obj, checkbox)
            if obj.IsSyncing
                return;
            end

            resourceId = string(checkbox.Tag);
            if checkbox.Value
                if ~any(obj.Selection == resourceId)
                    obj.Selection(end+1, 1) = resourceId;
                end
            else
                mask = obj.Selection ~= resourceId;
                obj.Selection = obj.Selection(mask);
            end

            obj.fireSelectionChanged();
        end

        function fireSelectionChanged(obj)
            notify(obj, 'SelectionChanged');

            if ~isempty(obj.Options.SelectionChangedFcn)
                obj.Options.SelectionChangedFcn(obj.Selection);
            end
        end

        function onCreatePressed(obj)
            if ~isempty(obj.Options.CreateCallback)
                obj.Options.CreateCallback(obj);
            else
                uialert(ancestor(obj.Grid, 'figure'), ...
                    'Resource manager is not available yet.', 'Info');
            end
        end

        function color = inferBackground(obj)
            ancestorPanel = ancestor(obj.Parent, 'uifigure');
            if isempty(ancestorPanel)
                color = [0.12 0.12 0.12];
            else
                color = ancestorPanel.Color;
            end
        end
    end
end
