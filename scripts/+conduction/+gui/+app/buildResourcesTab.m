function buildResourcesTab(app, resourcesGrid)
%BUILDRESOURCESTAB Populate the Resources tab controls.

    % Form panel (Details)
    formPanel = uipanel(resourcesGrid);
    formPanel.Layout.Row = 1;
    formPanel.Layout.Column = 1;
    formPanel.Title = 'Details';

    formGrid = uigridlayout(formPanel);
    formGrid.RowHeight = {'fit', 'fit', 'fit'};
    formGrid.ColumnWidth = {100, '1x'};
    formGrid.RowSpacing = 8;
    formGrid.ColumnSpacing = 8;
    formGrid.Padding = [8 8 8 8];

    % Name field
    nameLabel = uilabel(formGrid);
    nameLabel.Text = 'Name:';
    nameLabel.Layout.Row = 1;
    nameLabel.Layout.Column = 1;

    app.ResourceNameField = uieditfield(formGrid, 'text');
    app.ResourceNameField.Layout.Row = 1;
    app.ResourceNameField.Layout.Column = 2;
    app.ResourceNameField.Placeholder = 'Enter resource name';

    % Capacity spinner
    capacityLabel = uilabel(formGrid);
    capacityLabel.Text = 'Capacity:';
    capacityLabel.Layout.Row = 2;
    capacityLabel.Layout.Column = 1;

    app.ResourceCapacitySpinner = uispinner(formGrid);
    app.ResourceCapacitySpinner.Limits = [0 Inf];
    app.ResourceCapacitySpinner.Step = 1;
    app.ResourceCapacitySpinner.Value = 1;
    app.ResourceCapacitySpinner.ValueDisplayFormat = '%.0f';
    app.ResourceCapacitySpinner.Layout.Row = 2;
    app.ResourceCapacitySpinner.Layout.Column = 2;

    % Save and Reset buttons
    buttonGrid = uigridlayout(formGrid);
    buttonGrid.Layout.Row = 3;
    buttonGrid.Layout.Column = [1 2];
    buttonGrid.ColumnWidth = {'1x', '1x'};
    buttonGrid.RowHeight = {'fit'};
    buttonGrid.ColumnSpacing = 8;
    buttonGrid.Padding = [0 0 0 0];

    app.SaveResourceButton = uibutton(buttonGrid, 'push');
    app.SaveResourceButton.Text = 'Save';
    app.SaveResourceButton.Layout.Column = 1;
    app.SaveResourceButton.ButtonPushedFcn = @(~, ~) app.onSaveResourcePressed();

    app.ResetResourceButton = uibutton(buttonGrid, 'push');
    app.ResetResourceButton.Text = 'Reset';
    app.ResetResourceButton.Layout.Column = 2;
    app.ResetResourceButton.ButtonPushedFcn = @(~, ~) app.onResetResourcePressed();

    % Table panel
    tablePanel = uipanel(resourcesGrid);
    tablePanel.Layout.Row = 2;
    tablePanel.Layout.Column = 1;
    tablePanel.Title = 'Resource Types';

    tableGrid = uigridlayout(tablePanel);
    tableGrid.RowHeight = {'1x'};
    tableGrid.ColumnWidth = {'1x'};
    tableGrid.Padding = [4 4 4 4];
    tableGrid.RowSpacing = 0;

    app.ResourcesTable = uitable(tableGrid);
    app.ResourcesTable.Layout.Row = 1;
    app.ResourcesTable.Layout.Column = 1;
    app.ResourcesTable.ColumnName = {'Name', 'Capacity'};
    app.ResourcesTable.ColumnEditable = [false false];
    app.ResourcesTable.ColumnWidth = {'1x', 80};
    app.ResourcesTable.ColumnFormat = {'char', 'numeric'};
    app.ResourcesTable.SelectionChangedFcn = @(~, evt) app.onResourceTableSelectionChanged(evt);

    % Button row (Delete only)
    btnGrid = uigridlayout(resourcesGrid);
    btnGrid.Layout.Row = 3;
    btnGrid.Layout.Column = 1;
    btnGrid.ColumnWidth = {'1x', 100};  % Spacer + fixed-width Delete button
    btnGrid.RowHeight = {'fit'};
    btnGrid.ColumnSpacing = 8;
    btnGrid.Padding = [0 0 0 0];

    % Spacer
    spacer = uilabel(btnGrid);
    spacer.Text = '';
    spacer.Layout.Column = 1;

    app.DeleteResourceButton = uibutton(btnGrid, 'push');
    app.DeleteResourceButton.Text = 'Delete';
    app.DeleteResourceButton.Layout.Column = 2;
    app.DeleteResourceButton.Enable = 'off';
    app.DeleteResourceButton.ButtonPushedFcn = @(~, ~) app.onDeleteResourcePressed();
end
