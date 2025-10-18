classdef CaseTableView < handle
    %CASETABLEVIEW Render the cases table and controls bound to a CaseStore.

    properties (SetAccess = private)
        Parent = []
        Grid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        TitleLabel matlab.ui.control.Label = matlab.ui.control.Label.empty
        Table matlab.ui.control.Table = matlab.ui.control.Table.empty
        RemoveButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        ClearButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        Store conduction.gui.stores.CaseStore = conduction.gui.stores.CaseStore.empty
        Options struct = struct()
    end

    properties (Access = private)
        StoreListeners event.listener = event.listener.empty
        RemoveHandler = []
        ClearHandler = []
        IsSyncingSelection logical = false
    end

    methods
        function obj = CaseTableView(parent, store, opts)
            if nargin < 3 || isempty(opts)
                opts = struct();
            end

            if nargin < 2 || ~isa(store, 'conduction.gui.stores.CaseStore')
                error('CaseTableView:InvalidStore', ...
                    'Second argument must be a conduction.gui.stores.CaseStore instance.');
            end

            obj.Parent = parent;
            obj.Store = store;
            obj.Options = obj.normalizeOptions(opts);

            if isempty(obj.Options.RemoveHandler)
                obj.RemoveHandler = @(view) view.Store.removeSelected();
            else
                obj.RemoveHandler = obj.Options.RemoveHandler;
            end

            if isempty(obj.Options.ClearHandler)
                obj.ClearHandler = @(view) view.Store.clearAll();
            else
                obj.ClearHandler = obj.Options.ClearHandler;
            end

            obj.buildUI();
            obj.attachStoreListeners();
            obj.refresh();
        end

        function delete(obj)
            obj.teardown();
        end

        function refresh(obj)
            obj.Table.Data = obj.Store.Data;
            obj.syncSelectionFromStore();
            obj.updateButtons();
        end

        function setSelection(obj, selection)
            obj.Store.setSelection(selection);
        end

        function selection = getSelection(obj)
            selection = obj.Store.Selection;
        end

        function focus(obj)
            if isempty(obj.Table) || ~isvalid(obj.Table)
                return;
            end
            fig = ancestor(obj.Table, 'figure');
            if ~isempty(fig) && isvalid(fig)
                fig.Visible = 'on';
                drawnow limitrate;
            end
        end

        function destroy(obj)
            obj.teardown();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            parent = obj.Parent;
            if isa(parent, 'matlab.ui.container.GridLayout') || isa(parent, 'matlab.ui.container.Panel') || isa(parent, 'matlab.ui.Figure')
                % ok
            else
                error('CaseTableView:InvalidParent', 'Parent must be a UI container.');
            end

            obj.Grid = uigridlayout(parent);
            obj.Grid.RowHeight = {24, '1x', 34};
            obj.Grid.ColumnWidth = {'1x', 'fit'};
            obj.Grid.Padding = [10 10 10 10];
            obj.Grid.RowSpacing = 6;
            obj.Grid.ColumnSpacing = 10;

            if isfield(obj.Options.Layout, 'RowHeight')
                obj.Grid.RowHeight = obj.Options.Layout.RowHeight;
            end
            if isfield(obj.Options.Layout, 'ColumnWidth')
                obj.Grid.ColumnWidth = obj.Options.Layout.ColumnWidth;
            end
            if isfield(obj.Options.Layout, 'Padding')
                obj.Grid.Padding = obj.Options.Layout.Padding;
            end
            if isfield(obj.Options.Layout, 'RowSpacing')
                obj.Grid.RowSpacing = obj.Options.Layout.RowSpacing;
            end
            if isfield(obj.Options.Layout, 'ColumnSpacing')
                obj.Grid.ColumnSpacing = obj.Options.Layout.ColumnSpacing;
            end

            obj.TitleLabel = uilabel(obj.Grid);
            obj.TitleLabel.Text = char(obj.Options.Title);
            obj.TitleLabel.FontWeight = 'bold';
            obj.TitleLabel.Layout.Row = 1;
            obj.TitleLabel.Layout.Column = [1 2];

            obj.Table = uitable(obj.Grid);
            obj.Table.Layout.Row = 2;
            obj.Table.Layout.Column = [1 2];
            obj.Table.ColumnName = {'', 'ID', 'Operator', 'Procedure', 'Duration', 'Admission', 'Lab', 'First Case'};
            obj.Table.ColumnWidth = {45, 50, 110, 150, 80, 110, 90, 90};
            obj.Table.RowName = {};
            obj.Table.SelectionType = 'row';
            obj.Table.SelectionChangedFcn = @(src, event) obj.onTableSelectionChanged(event);

            rowStyle = uistyle('HorizontalAlignment', 'left');
            addStyle(obj.Table, rowStyle);

            % Buttons row layout: remove button expands, clear button sized to text.
            buttonGrid = uigridlayout(obj.Grid);
            buttonGrid.Layout.Row = 3;
            buttonGrid.Layout.Column = [1 2];
            buttonGrid.RowHeight = {'fit'};
            buttonGrid.ColumnWidth = {'1x', 'fit'};
            buttonGrid.RowSpacing = 0;
            buttonGrid.ColumnSpacing = 10;
            buttonGrid.Padding = [0 0 0 0];

            obj.RemoveButton = uibutton(buttonGrid, 'push');
            obj.RemoveButton.Text = 'Remove Selected';
            obj.RemoveButton.Layout.Row = 1;
            obj.RemoveButton.Layout.Column = 1;
            obj.RemoveButton.Enable = 'off';
            obj.RemoveButton.ButtonPushedFcn = @(src, event) obj.onRemoveButtonPushed();

            obj.ClearButton = uibutton(buttonGrid, 'push');
            obj.ClearButton.Text = 'Clear All';
            obj.ClearButton.Layout.Row = 1;
            obj.ClearButton.Layout.Column = 2;
            obj.ClearButton.Enable = 'off';
            obj.ClearButton.ButtonPushedFcn = @(src, event) obj.onClearButtonPushed();
        end

        function attachStoreListeners(obj)
            if isempty(obj.Store)
                return;
            end

            obj.StoreListeners(end+1) = addlistener(obj.Store, 'DataChanged', @(src, evt) obj.onStoreDataChanged());
            obj.StoreListeners(end+1) = addlistener(obj.Store, 'SelectionChanged', @(src, evt) obj.onStoreSelectionChanged());
        end

        function onStoreDataChanged(obj)
            if ~isvalid(obj)
                return;
            end
            obj.Table.Data = obj.Store.Data;
            obj.updateButtons();
        end

        function onStoreSelectionChanged(obj)
            if ~isvalid(obj)
                return;
            end
            obj.syncSelectionFromStore();
            obj.updateButtons();
        end

        function syncSelectionFromStore(obj)
            if isempty(obj.Table) || ~isvalid(obj.Table)
                return;
            end

            obj.IsSyncingSelection = true;
            cleanup = onCleanup(@() obj.clearSyncFlag()); %#ok<NASGU>
            obj.Table.Selection = obj.Store.Selection;
        end

        function clearSyncFlag(obj)
            obj.IsSyncingSelection = false;
        end

        function onTableSelectionChanged(obj, event)
            if obj.IsSyncingSelection
                return;
            end

            selection = event.Source.Selection;
            obj.Store.setSelection(selection);
        end

        function updateButtons(obj)
            hasData = obj.Store.hasCases();
            hasSelection = ~isempty(obj.Store.Selection);

            obj.RemoveButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            obj.ClearButton.Enable = matlab.lang.OnOffSwitchState(hasData);
        end

        function onRemoveButtonPushed(obj)
            obj.RemoveHandler(obj);
        end

        function onClearButtonPushed(obj)
            obj.ClearHandler(obj);
        end

        function teardown(obj)
            if ~isempty(obj.StoreListeners)
                delete(obj.StoreListeners);
                obj.StoreListeners = event.listener.empty;
            end

            if ~isempty(obj.Grid) && isvalid(obj.Grid)
                delete(obj.Grid);
            end
        end

        function opts = normalizeOptions(~, opts)
            defaults = struct( ...
                'Title', "Added Cases", ...
                'RemoveHandler', [], ...
                'ClearHandler', [], ...
                'Layout', struct());

            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                name = fields{i};
                if ~isfield(opts, name) || isempty(opts.(name))
                    opts.(name) = defaults.(name);
                end
            end

            opts.Title = string(opts.Title);

            if ~isempty(opts.RemoveHandler) && ~isa(opts.RemoveHandler, 'function_handle')
                error('CaseTableView:InvalidRemoveHandler', ...
                    'RemoveHandler must be a function handle.');
            end

            if ~isempty(opts.ClearHandler) && ~isa(opts.ClearHandler, 'function_handle')
                error('CaseTableView:InvalidClearHandler', ...
                    'ClearHandler must be a function handle.');
            end

            if ~isstruct(opts.Layout)
                error('CaseTableView:InvalidLayout', 'Layout must be a struct of layout overrides.');
            end
        end
    end
end
