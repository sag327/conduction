classdef CasesPopout < handle
    %CASEsPOPOUT Pop-out window hosting the cases table view.

    properties (SetAccess = private)
        Store conduction.gui.stores.CaseStore = conduction.gui.stores.CaseStore.empty
        OnRedock function_handle = function_handle.empty
        UIFigure matlab.ui.Figure = matlab.ui.Figure.empty
        RootGrid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        HeaderGrid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        RedockButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        TableView conduction.gui.components.CaseTableView = conduction.gui.components.CaseTableView.empty
        TitleLabel matlab.ui.control.Label = matlab.ui.control.Label.empty
        Options struct = struct()
    end

    properties (Access = private)
        IsRedocking logical = false
        DefaultTitle string = "Cases"
    end

    methods
        function obj = CasesPopout(store, onRedock, opts)
            if nargin < 3 || isempty(opts)
                opts = struct();
            end

            if nargin < 2
                onRedock = [];
            end

            if nargin < 1 || ~isa(store, 'conduction.gui.stores.CaseStore')
                error('CasesPopout:InvalidStore', ...
                    'First argument must be a conduction.gui.stores.CaseStore instance.');
            end

            obj.Store = store;
            if ~isempty(onRedock)
                if ~isa(onRedock, 'function_handle')
                    error('CasesPopout:InvalidCallback', 'onRedock must be a function handle.');
                end
                obj.OnRedock = onRedock;
            else
                obj.OnRedock = [];
            end

            obj.Options = obj.normalizeOptions(opts);
        end

        function delete(obj)
            obj.destroy();
        end

        function show(obj)
            if ~obj.isOpen()
                obj.buildWindow();
            end

            obj.UIFigure.Visible = 'on';
            drawnow limitrate;
        end

        function focus(obj)
            if obj.isOpen()
                figure(obj.UIFigure);
                obj.UIFigure.Visible = 'on';
                drawnow limitrate;
            end
        end

        function tf = isOpen(obj)
            tf = ~isempty(obj.UIFigure) && isvalid(obj.UIFigure);
        end

        function close(obj)
            if ~obj.isOpen()
                return;
            end
            obj.handleCloseRequest();
        end

        function destroy(obj)
            if ~isempty(obj.TableView) && isvalid(obj.TableView)
                delete(obj.TableView);
            end
            obj.TableView = conduction.gui.components.CaseTableView.empty;

            if obj.isOpen()
                delete(obj.UIFigure);
            end
            obj.UIFigure = matlab.ui.Figure.empty;
            obj.RootGrid = matlab.ui.container.GridLayout.empty;
            obj.HeaderGrid = matlab.ui.container.GridLayout.empty;
            obj.RedockButton = matlab.ui.control.Button.empty;
            obj.TitleLabel = matlab.ui.control.Label.empty;
            obj.IsRedocking = false;
        end
    end

    methods (Access = private)
        function buildWindow(obj)
            fig = uifigure('Visible', 'off');
            fig.Name = char(obj.Options.Title);
            fig.CloseRequestFcn = @(src, event) obj.handleCloseRequest();
            fig.Position = obj.Options.Position;
            fig.AutoResizeChildren = 'off';

            obj.UIFigure = fig;

            root = uigridlayout(fig);
            root.RowHeight = {40, '1x'};
            root.ColumnWidth = {'1x'};
            root.Padding = [10 10 10 10];
            root.RowSpacing = 8;
            obj.RootGrid = root;

            header = uigridlayout(root);
            header.Layout.Row = 1;
            header.Layout.Column = 1;
            header.RowHeight = {'fit'};
            header.ColumnWidth = {'1x', 'fit'};
            header.RowSpacing = 0;
            header.ColumnSpacing = 10;
            header.Padding = [0 0 0 0];
            obj.HeaderGrid = header;

            titleLabel = uilabel(header);
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = 1;
            titleLabel.Text = char(obj.Options.Title);
            titleLabel.FontWeight = 'bold';
            titleLabel.FontSize = 16;
            obj.TitleLabel = titleLabel;

            redockBtn = uibutton(header, 'push');
            redockBtn.Layout.Row = 1;
            redockBtn.Layout.Column = 2;
            redockBtn.Text = 'Dock';
            if ~isempty(obj.Options.RedockIcon)
                redockBtn.Icon = obj.Options.RedockIcon;
                redockBtn.IconAlignment = 'left';
            end
            redockBtn.Tooltip = obj.Options.RedockTooltip;
            redockBtn.ButtonPushedFcn = @(src, event) obj.handleCloseRequest();
            obj.RedockButton = redockBtn;

            tableParent = uipanel(root);
            tableParent.Layout.Row = 2;
            tableParent.Layout.Column = 1;
            tableParent.BorderType = 'none';
            tableParent.BackgroundColor = fig.Color;

            tableGrid = uigridlayout(tableParent);
            tableGrid.RowHeight = {'1x'};
            tableGrid.ColumnWidth = {'1x'};
            tableGrid.Padding = [0 0 0 0];
            tableGrid.RowSpacing = 0;
            tableGrid.ColumnSpacing = 0;

            layoutOverrides = struct('Padding', [0 0 0 0]);
            obj.TableView = conduction.gui.components.CaseTableView(tableGrid, obj.Store, ...
                struct('Title', "", 'Layout', layoutOverrides));

            fig.KeyPressFcn = @(src, event) obj.onKeyPress(event);

            obj.UIFigure.Visible = 'on';
        end

        function handleCloseRequest(obj)
            if obj.IsRedocking
                return;
            end

            obj.IsRedocking = true;

            try
                if ~isempty(obj.OnRedock)
                    obj.OnRedock(obj);
                end
            catch ME
                obj.IsRedocking = false;
                rethrow(ME);
            end

            obj.destroy();
        end

        function onKeyPress(obj, event)
            if isempty(event) || ~isprop(event, 'Key')
                return;
            end

            key = lower(string(event.Key));
            if key == "escape"
                obj.handleCloseRequest();
            end
        end

        function opts = normalizeOptions(obj, opts)
            defaults = struct( ...
                'Title', obj.DefaultTitle, ...
                'Position', [100 100 640 520], ...
                'RedockIcon', conduction.gui.utils.Icons.redockIcon(), ...
                'RedockTooltip', 'Return cases to main window (Esc)');

            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                name = fields{i};
                if ~isfield(opts, name) || isempty(opts.(name))
                    opts.(name) = defaults.(name);
                end
            end

            opts.Title = string(opts.Title);
            opts.Position = double(opts.Position);
            if numel(opts.Position) ~= 4
                error('CasesPopout:InvalidPosition', 'Position must be a 1x4 numeric array.');
            end
        end
    end
end
