classdef ResourceManager < handle
    %RESOURCEMANAGER Modal window to manage shared resource types.

    properties (SetAccess = private)
        Store conduction.gui.stores.ResourceStore
        OnClose function_handle = function_handle.empty
        UIFigure matlab.ui.Figure = matlab.ui.Figure.empty
        Table matlab.ui.control.Table = matlab.ui.control.Table.empty
        NewButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        DeleteButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        SaveButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        CloseButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        NameField matlab.ui.control.EditField = matlab.ui.control.EditField.empty
        CapacitySpinner matlab.ui.control.Spinner = matlab.ui.control.Spinner.empty
        PatternDropDown matlab.ui.control.DropDown = matlab.ui.control.DropDown.empty
        NotesArea matlab.ui.control.TextArea = matlab.ui.control.TextArea.empty
        TrackedCheckBox matlab.ui.control.CheckBox = matlab.ui.control.CheckBox.empty
        ColorButton matlab.ui.control.Button = matlab.ui.control.Button.empty
        ColorPreview matlab.ui.container.Panel = matlab.ui.container.Panel.empty
        SelectedResourceId string = ""
        CurrentColor double = [0.2 0.6 0.9]
        RootGrid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        FormGrid matlab.ui.container.GridLayout = matlab.ui.container.GridLayout.empty
        TableData struct = struct('Ids', string.empty(0,1), 'Names', string.empty(0,1))
        StoreListener event.listener = event.listener.empty
        InitialVisibility char {mustBeMember(InitialVisibility,{'on','off'})} = 'off'
    end

    methods
        function obj = ResourceManager(store, varargin)
            if nargin < 1 || ~isa(store, 'conduction.gui.stores.ResourceStore')
                error('ResourceManager:InvalidStore', 'First argument must be a ResourceStore.');
            end

            parser = inputParser;
            addParameter(parser, 'OnClose', [], @(v) isempty(v) || isa(v, 'function_handle'));
            addParameter(parser, 'Visible', 'off', @(v) any(validatestring(v, {'on','off'})));
            parse(parser, varargin{:});
            opts = parser.Results;

            obj.Store = store;
            if isempty(opts.OnClose)
                obj.OnClose = function_handle.empty;
            else
                obj.OnClose = opts.OnClose;
            end
            obj.InitialVisibility = opts.Visible;

            obj.buildUI();
            obj.attachStoreListener();
            obj.refreshTable();
            obj.clearForm();
            obj.UIFigure.Visible = obj.InitialVisibility;
        end

        function delete(obj)
            if ~isempty(obj.StoreListener) && isvalid(obj.StoreListener)
                delete(obj.StoreListener);
            end
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
        end

        function show(obj)
            if isempty(obj.UIFigure) || ~isvalid(obj.UIFigure)
                obj.buildUI();
                obj.attachStoreListener();
                obj.refreshTable();
                obj.clearForm();
            end
            obj.UIFigure.Visible = 'on';
            figure(obj.UIFigure);
        end

        function focus(obj)
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                figure(obj.UIFigure);
            end
        end

        function close(obj)
            if isempty(obj.UIFigure) || ~isvalid(obj.UIFigure)
                return;
            end
            delete(obj.UIFigure);
            obj.UIFigure = matlab.ui.Figure.empty;
            if ~isempty(obj.OnClose)
                obj.OnClose(obj);
            end
        end

        % Public helpers for automated tests
        function type = createResourceForTest(obj, name, capacity, color, pattern, notes, isTracked)
            if nargin < 4 || isempty(color)
                color = obj.CurrentColor;
            end
            if nargin < 5 || isempty(pattern)
                pattern = "solid";
            end
            if nargin < 6
                notes = "";
            end
            if nargin < 7
                isTracked = true;
            end
            obj.clearForm();
            obj.NameField.Value = char(name);
            obj.CapacitySpinner.Value = capacity;
            obj.PatternDropDown.Value = char(pattern);
            obj.NotesArea.Value = obj.formatNotesForTextarea(notes);
            obj.TrackedCheckBox.Value = isTracked;
            obj.setCurrentColor(color);
            type = obj.commitForm();
        end

        function type = updateResourceForTest(obj, resourceId, varargin)
            obj.selectResource(resourceId);
            parser = inputParser;
            addParameter(parser, 'Name', [], @(v) isempty(v) || ischar(v) || isstring(v));
            addParameter(parser, 'Capacity', [], @(v) isempty(v) || (isscalar(v) && v >= 0));
            addParameter(parser, 'Color', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 3));
            addParameter(parser, 'Pattern', [], @(v) isempty(v) || ischar(v) || isstring(v));
            addParameter(parser, 'Notes', [], @(v) isempty(v) || ischar(v) || isstring(v));
            addParameter(parser, 'IsTracked', [], @(v) isempty(v) || islogical(v));
            parse(parser, varargin{:});
            opts = parser.Results;

            if ~isempty(opts.Name)
                obj.NameField.Value = char(opts.Name);
            end
            if ~isempty(opts.Capacity)
                obj.CapacitySpinner.Value = opts.Capacity;
            end
            if ~isempty(opts.Pattern)
                obj.PatternDropDown.Value = char(opts.Pattern);
            end
            if ~isempty(opts.Notes)
                obj.NotesArea.Value = obj.formatNotesForTextarea(opts.Notes);
            end
            if ~isempty(opts.IsTracked)
                obj.TrackedCheckBox.Value = logical(opts.IsTracked);
            end
            if ~isempty(opts.Color)
                obj.setCurrentColor(double(opts.Color(:)'));
            end

            type = obj.commitForm();
        end

        function deleteResourceForTest(obj, resourceId)
            obj.selectResource(resourceId);
            obj.performDelete(false);
        end

        function ids = listedResourceIds(obj)
            ids = obj.TableData.Ids;
        end
    end

    methods (Access = private)
        function buildUI(obj)
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                return;
            end

            obj.UIFigure = uifigure('Name', 'Resource Manager', ...
                'Position', [100 100 760 420], ...
                'Visible', 'off');
            obj.UIFigure.CloseRequestFcn = @(src, evt) obj.close();

            obj.RootGrid = uigridlayout(obj.UIFigure);
            obj.RootGrid.ColumnWidth = {280, '1x'};
            obj.RootGrid.RowHeight = {'1x', 40};
            obj.RootGrid.ColumnSpacing = 12;
            obj.RootGrid.RowSpacing = 8;
            obj.RootGrid.Padding = [12 12 12 12];

            obj.buildTablePanel();
            obj.buildFormPanel();
        end

        function buildTablePanel(obj)
            tablePanel = uipanel(obj.RootGrid);
            tablePanel.Layout.Row = 1;
            tablePanel.Layout.Column = 1;
            tablePanel.Title = 'Resource Types';

            tableGrid = uigridlayout(tablePanel);
            tableGrid.RowHeight = {'1x', 40};
            tableGrid.ColumnWidth = {'1x'};
            tableGrid.RowSpacing = 6;
            tableGrid.ColumnSpacing = 0;
            tableGrid.Padding = [4 4 4 4];

            obj.Table = uitable(tableGrid);
            obj.Table.Layout.Row = 1;
            obj.Table.Layout.Column = 1;
            obj.Table.ColumnName = {'Name', 'Capacity', 'Color', 'Notes'};
            obj.Table.ColumnEditable = [false false false false];
            obj.Table.SelectionChangedFcn = @(src, evt) obj.onTableSelectionChanged(evt);

            btnGrid = uigridlayout(tableGrid);
            btnGrid.Layout.Row = 2;
            btnGrid.Layout.Column = 1;
            btnGrid.ColumnWidth = {'1x', '1x', '1x'};
            btnGrid.RowHeight = {'fit'};
            btnGrid.ColumnSpacing = 8;
            btnGrid.Padding = [0 0 0 0];

            obj.NewButton = uibutton(btnGrid, 'push', 'Text', 'New');
            obj.NewButton.Layout.Column = 1;
            obj.NewButton.ButtonPushedFcn = @(src, evt) obj.onNewPressed();

            obj.DeleteButton = uibutton(btnGrid, 'push', 'Text', 'Delete');
            obj.DeleteButton.Layout.Column = 2;
            obj.DeleteButton.ButtonPushedFcn = @(src, evt) obj.performDelete();
            obj.DeleteButton.Enable = 'off';

            obj.CloseButton = uibutton(btnGrid, 'push', 'Text', 'Close');
            obj.CloseButton.Layout.Column = 3;
            obj.CloseButton.ButtonPushedFcn = @(src, evt) obj.close();
        end

        function buildFormPanel(obj)
            formPanel = uipanel(obj.RootGrid);
            formPanel.Layout.Row = 1;
            formPanel.Layout.Column = 2;
            formPanel.Title = 'Details';

            obj.FormGrid = uigridlayout(formPanel);
            obj.FormGrid.RowHeight = {'fit','fit','fit','fit',80,'fit','fit'};
            obj.FormGrid.ColumnWidth = {120, '1x'};
            obj.FormGrid.RowSpacing = 6;
            obj.FormGrid.ColumnSpacing = 8;
            obj.FormGrid.Padding = [6 6 6 6];

            nameLabel = uilabel(obj.FormGrid, 'Text', 'Name');
            nameLabel.Layout.Row = 1;
            nameLabel.Layout.Column = 1;
            obj.NameField = uieditfield(obj.FormGrid, 'text');
            obj.NameField.Layout.Row = 1;
            obj.NameField.Layout.Column = 2;

            capacityLabel = uilabel(obj.FormGrid, 'Text', 'Capacity');
            capacityLabel.Layout.Row = 2;
            capacityLabel.Layout.Column = 1;
            obj.CapacitySpinner = uispinner(obj.FormGrid, 'Limits', [0 inf], 'Step', 1);
            obj.CapacitySpinner.Layout.Row = 2;
            obj.CapacitySpinner.Layout.Column = 2;

            colorLabel = uilabel(obj.FormGrid, 'Text', 'Color');
            colorLabel.Layout.Row = 3;
            colorLabel.Layout.Column = 1;
            colorGrid = uigridlayout(obj.FormGrid);
            colorGrid.Layout.Row = 3;
            colorGrid.Layout.Column = 2;
            colorGrid.ColumnWidth = {'fit','1x'};
            colorGrid.RowHeight = {'fit'};
            colorGrid.ColumnSpacing = 8;
            colorGrid.Padding = [0 0 0 0];

            obj.ColorButton = uibutton(colorGrid, 'push', 'Text', 'Select…');
            obj.ColorButton.Layout.Column = 1;
            obj.ColorButton.ButtonPushedFcn = @(src, evt) obj.onColorButtonPressed();

            obj.ColorPreview = uipanel(colorGrid, 'BackgroundColor', obj.CurrentColor);
            obj.ColorPreview.Layout.Column = 2;
            obj.ColorPreview.BorderType = 'line';
            obj.ColorPreview.BorderWidth = 1;

            patternLabel = uilabel(obj.FormGrid, 'Text', 'Pattern');
            patternLabel.Layout.Row = 4;
            patternLabel.Layout.Column = 1;
            obj.PatternDropDown = uidropdown(obj.FormGrid, ...
                'Items', {'solid','diagonal','cross','dots'}, 'Value', 'solid');
            obj.PatternDropDown.Layout.Row = 4;
            obj.PatternDropDown.Layout.Column = 2;

            notesLabel = uilabel(obj.FormGrid, 'Text', 'Notes');
            notesLabel.VerticalAlignment = 'top';
            notesLabel.Layout.Row = 5;
            notesLabel.Layout.Column = 1;
            obj.NotesArea = uitextarea(obj.FormGrid);
            obj.NotesArea.Layout.Row = 5;
            obj.NotesArea.Layout.Column = 2;
            obj.NotesArea.WordWrap = 'on';

            obj.TrackedCheckBox = uicheckbox(obj.FormGrid, 'Text', 'Track in visualization');
            obj.TrackedCheckBox.Layout.Row = 6;
            obj.TrackedCheckBox.Layout.Column = [1 2];
            obj.TrackedCheckBox.Value = true;

            buttonGrid = uigridlayout(obj.FormGrid);
            buttonGrid.Layout.Row = 7;
            buttonGrid.Layout.Column = [1 2];
            buttonGrid.ColumnWidth = {'1x','1x'};
            buttonGrid.RowHeight = {'fit'};
            buttonGrid.ColumnSpacing = 8;
            buttonGrid.Padding = [0 0 0 0];

            obj.SaveButton = uibutton(buttonGrid, 'push', 'Text', 'Save');
            obj.SaveButton.Layout.Column = 1;
            obj.SaveButton.ButtonPushedFcn = @(src, evt) obj.onSavePressed();

            resetButton = uibutton(buttonGrid, 'push', 'Text', 'Reset');
            resetButton.Layout.Column = 2;
            resetButton.ButtonPushedFcn = @(src, evt) obj.clearForm();
        end

        function attachStoreListener(obj)
            if isempty(obj.Store) || ~isvalid(obj.Store)
                return;
            end
            if ~isempty(obj.StoreListener) && isvalid(obj.StoreListener)
                delete(obj.StoreListener);
            end
            obj.StoreListener = addlistener(obj.Store, 'TypesChanged', @(~,~) obj.onStoreChanged());
        end

        function onStoreChanged(obj)
            obj.refreshTable();
        end

        function refreshTable(obj)
            types = obj.Store.list();
            if isempty(types)
                obj.Table.Data = {};
                obj.TableData = struct('Ids', string.empty(0,1), 'Names', string.empty(0,1));
                obj.Table.Selection = [];
                obj.SelectedResourceId = "";
                obj.DeleteButton.Enable = 'off';
                return;
            end

            data = cell(numel(types), 4);
            ids = strings(numel(types),1);
            for k = 1:numel(types)
                t = types(k);
                ids(k) = t.Id;
                data{k,1} = char(t.Name);
                data{k,2} = t.Capacity;
                data{k,3} = obj.colorToHex(t.Color);
                data{k,4} = char(t.Notes);
            end
            obj.Table.Data = data;
            obj.TableData = struct('Ids', ids, 'Names', string(data(:,1)));

            if ~isempty(obj.SelectedResourceId) && any(ids == obj.SelectedResourceId)
                idx = find(ids == obj.SelectedResourceId, 1);
                try
                    obj.Table.Selection = [idx 1];
                catch
                    obj.Table.Selection = idx;
                end
            else
                obj.Table.Selection = [];
                obj.SelectedResourceId = "";
                obj.DeleteButton.Enable = 'off';
            end
        end

        function onTableSelectionChanged(obj, event)
            if isempty(event.Selection)
                obj.SelectedResourceId = "";
                obj.DeleteButton.Enable = 'off';
                obj.clearForm();
                return;
            end
            index = event.Selection(1);
            if index > numel(obj.TableData.Ids)
                return;
            end
            obj.SelectedResourceId = obj.TableData.Ids(index);
            obj.populateForm(obj.SelectedResourceId);
            obj.DeleteButton.Enable = 'on';
        end

        function populateForm(obj, resourceId)
            type = obj.Store.get(resourceId);
            if isempty(type)
                return;
            end
            obj.NameField.Value = char(type.Name);
            obj.CapacitySpinner.Value = type.Capacity;
            obj.PatternDropDown.Value = char(type.Pattern);
            obj.NotesArea.Value = obj.formatNotesForTextarea(type.Notes);
            obj.TrackedCheckBox.Value = type.IsTracked;
            obj.setCurrentColor(type.Color);
        end

        function onNewPressed(obj)
            obj.SelectedResourceId = "";
            obj.clearForm();
            obj.Table.Selection = [];
            obj.DeleteButton.Enable = 'off';
        end

        function onSavePressed(obj)
            try
                obj.commitForm();
                obj.refreshTable();
            catch ME
                uialert(obj.UIFigure, ME.message, 'Save Failed');
            end
        end

        function resource = commitForm(obj)
            name = string(strtrim(obj.NameField.Value));
            capacity = obj.CapacitySpinner.Value;
            pattern = string(obj.PatternDropDown.Value);
            notes = strjoin(string(obj.NotesArea.Value), newline);
            isTracked = obj.TrackedCheckBox.Value;
            color = obj.CurrentColor;

            if strlength(name) == 0
                error('ResourceManager:InvalidName', 'Resource name cannot be empty.');
            end

            if strlength(obj.SelectedResourceId) == 0
                resource = obj.Store.create(name, capacity, ...
                    'Color', color, 'Pattern', pattern, 'Notes', notes, 'IsTracked', isTracked);
                obj.SelectedResourceId = resource.Id;
            else
                obj.Store.update(obj.SelectedResourceId, ...
                    'Name', name, 'Capacity', capacity, 'Color', color, ...
                    'Pattern', pattern, 'Notes', notes, 'IsTracked', isTracked);
                resource = obj.Store.get(obj.SelectedResourceId);
            end

            obj.refreshTable();
            obj.selectResource(obj.SelectedResourceId);
        end

        function selectResource(obj, resourceId)
            if isempty(resourceId)
                return;
            end
            ids = obj.TableData.Ids;
            idx = find(ids == resourceId, 1);
            if isempty(idx)
                return;
            end
            try
                obj.Table.Selection = [idx 1];
            catch
                obj.Table.Selection = idx;
            end
            obj.populateForm(resourceId);
            obj.SelectedResourceId = resourceId;
            obj.DeleteButton.Enable = 'on';
        end

        function performDelete(obj, prompt)
            if nargin < 2
                prompt = true;
            end
            if isempty(obj.SelectedResourceId)
                return;
            end
            type = obj.Store.get(obj.SelectedResourceId);
            if prompt
                choice = uiconfirm(obj.UIFigure, ...
                    sprintf('Delete resource "%s"? This will unassign it from all cases.', type.Name), ...
                    'Confirm Delete', 'Options', {'Delete','Cancel'}, 'DefaultOption', 'Cancel');
                if strcmp(choice, 'Cancel')
                    return;
                end
            end
            obj.Store.remove(obj.SelectedResourceId);
            obj.SelectedResourceId = "";
            obj.clearForm();
            obj.refreshTable();
        end

        function clearForm(obj)
            obj.SelectedResourceId = "";
            obj.NameField.Value = '';
            obj.CapacitySpinner.Value = 1;
            obj.PatternDropDown.Value = 'solid';
            obj.NotesArea.Value = {''};
            obj.TrackedCheckBox.Value = true;
            obj.setCurrentColor([0.2 0.6 0.9]);
        end

        function onColorButtonPressed(obj)
            newColor = uisetcolor(obj.CurrentColor, 'Select Resource Color');
            if numel(newColor) == 3
                obj.setCurrentColor(newColor);
            end
        end

        function setCurrentColor(obj, color)
            obj.CurrentColor = double(color(:)');
            if ~isempty(obj.ColorPreview) && isvalid(obj.ColorPreview)
                obj.ColorPreview.BackgroundColor = obj.CurrentColor;
            end
        end

        function hex = colorToHex(~, color)
            rgb = max(0, min(1, color(:)'));
            hex = sprintf('#%02X%02X%02X', round(rgb * 255));
        end

        function values = formatNotesForTextarea(~, notesValue)
            notesStr = string(notesValue);
            if numel(notesStr) <= 1
                values = cellstr(split(notesStr, newline));
            else
                values = cellstr(notesStr(:));
            end
            if isempty(values)
                values = {''};
            end
        end
    end
end
