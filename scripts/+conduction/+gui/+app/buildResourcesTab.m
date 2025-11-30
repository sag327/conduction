function buildResourcesTab(app, resourcesGrid)
%BUILDRESOURCESTAB Populate the Resources tab controls.

    % Form panel (Details)
    formPanel = uipanel(resourcesGrid);
    formPanel.Layout.Row = 1;
    formPanel.Layout.Column = 1;
    formPanel.Title = 'Details';
    conduction.gui.utils.Theme.applyAppBackground(formPanel);
    if isprop(formPanel, 'ForegroundColor')
        formPanel.ForegroundColor = conduction.gui.utils.Theme.primaryText();
    end

    formGrid = uigridlayout(formPanel);
    formGrid.RowHeight = {'fit', 'fit', 'fit'};
    formGrid.ColumnWidth = {100, '1x'};
    formGrid.RowSpacing = 8;
    formGrid.ColumnSpacing = 8;
    formGrid.Padding = [8 8 8 8];
    conduction.gui.utils.Theme.applyAppBackground(formGrid);

    % Name field
    nameLabel = uilabel(formGrid);
    nameLabel.Text = 'Name:';
    nameLabel.Layout.Row = 1;
    nameLabel.Layout.Column = 1;
    nameLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.ResourceNameField = uieditfield(formGrid, 'text');
    app.ResourceNameField.Layout.Row = 1;
    app.ResourceNameField.Layout.Column = 2;
    app.ResourceNameField.Placeholder = 'Enter resource name';
    app.ResourceNameField.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.ResourceNameField.FontColor = conduction.gui.utils.Theme.primaryText();

    % Capacity spinner
    capacityLabel = uilabel(formGrid);
    capacityLabel.Text = 'Capacity:';
    capacityLabel.Layout.Row = 2;
    capacityLabel.Layout.Column = 1;
    capacityLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.ResourceCapacitySpinner = uispinner(formGrid);
    app.ResourceCapacitySpinner.Limits = [0 Inf];
    app.ResourceCapacitySpinner.Step = 1;
    app.ResourceCapacitySpinner.Value = 1;
    app.ResourceCapacitySpinner.ValueDisplayFormat = '%.0f';
    app.ResourceCapacitySpinner.Layout.Row = 2;
    app.ResourceCapacitySpinner.Layout.Column = 2;
    app.ResourceCapacitySpinner.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.ResourceCapacitySpinner.FontColor = conduction.gui.utils.Theme.primaryText();

    % Save and Reset buttons
    buttonGrid = uigridlayout(formGrid);
    buttonGrid.Layout.Row = 3;
    buttonGrid.Layout.Column = [1 2];
    buttonGrid.ColumnWidth = {'1x', '1x'};
    buttonGrid.RowHeight = {'fit'};
    buttonGrid.ColumnSpacing = 8;
    buttonGrid.Padding = [0 0 0 0];
    conduction.gui.utils.Theme.applyPanelBackground(buttonGrid);

    app.SaveResourceButton = uibutton(buttonGrid, 'push');
    app.SaveResourceButton.Text = 'Save';
    app.SaveResourceButton.Layout.Column = 1;
    app.SaveResourceButton.Enable = 'off';  % Initially disabled (no changes)
    app.SaveResourceButton.ButtonPushedFcn = @(~, ~) app.onSaveResourcePressed();
    app.SaveResourceButton.BackgroundColor = [0.2 0.5 0.8];
    app.SaveResourceButton.FontColor = [1 1 1];

    app.ResetResourceButton = uibutton(buttonGrid, 'push');
    app.ResetResourceButton.Text = 'Reset';
    app.ResetResourceButton.Layout.Column = 2;
    app.ResetResourceButton.Enable = 'off';  % Initially disabled (no changes)
    app.ResetResourceButton.ButtonPushedFcn = @(~, ~) app.onResetResourcePressed();
    app.ResetResourceButton.BackgroundColor = [0.3 0.3 0.3];
    app.ResetResourceButton.FontColor = [1 1 1];

    % Table panel
    tablePanel = uipanel(resourcesGrid);
    tablePanel.Layout.Row = 2;
    tablePanel.Layout.Column = 1;
    tablePanel.Title = 'Resource Types';
    conduction.gui.utils.Theme.applyAppBackground(tablePanel);
    if isprop(tablePanel, 'ForegroundColor')
        tablePanel.ForegroundColor = conduction.gui.utils.Theme.primaryText();
    end

    tableGrid = uigridlayout(tablePanel);
    tableGrid.RowHeight = {'1x'};
    tableGrid.ColumnWidth = {'1x'};
    tableGrid.Padding = [4 4 4 4];
    tableGrid.RowSpacing = 0;
    conduction.gui.utils.Theme.applyAppBackground(tableGrid);

    app.ResourcesTable = uitable(tableGrid);
    app.ResourcesTable.Layout.Row = 1;
    app.ResourcesTable.Layout.Column = 1;
    app.ResourcesTable.ColumnName = {'Name', 'Capacity'};
    app.ResourcesTable.ColumnEditable = [false false];
    app.ResourcesTable.ColumnWidth = {'1x', 80};
    app.ResourcesTable.ColumnFormat = {'char', 'numeric'};
    app.ResourcesTable.SelectionChangedFcn = @(~, evt) app.onResourceTableSelectionChanged(evt);
    app.ResourcesTable.BackgroundColor = [0.1 0.1 0.1; 0.12 0.12 0.12];
    app.ResourcesTable.ForegroundColor = conduction.gui.utils.Theme.primaryText();

    % Button row (Delete only)
    btnGrid = uigridlayout(resourcesGrid);
    btnGrid.Layout.Row = 3;
    btnGrid.Layout.Column = 1;
    btnGrid.ColumnWidth = {'1x', 100};  % Spacer + fixed-width Delete button
    btnGrid.RowHeight = {'fit'};
    btnGrid.ColumnSpacing = 8;
    btnGrid.Padding = [0 0 0 0];
    btnGrid.BackgroundColor = conduction.gui.utils.Theme.appBackground();

    % Spacer
    spacer = uilabel(btnGrid);
    spacer.Text = '';
    spacer.Layout.Column = 1;

    app.DeleteResourceButton = uibutton(btnGrid, 'push');
    app.DeleteResourceButton.Text = 'Delete';
    app.DeleteResourceButton.Layout.Column = 2;
    app.DeleteResourceButton.Enable = 'off';
    app.DeleteResourceButton.ButtonPushedFcn = @(~, ~) app.onDeleteResourcePressed();
    app.DeleteResourceButton.BackgroundColor = [0.6 0.2 0.2];
    app.DeleteResourceButton.FontColor = [1 1 1];

    % Default Resources panel
    defaultPanel = uipanel(resourcesGrid);
    defaultPanel.Layout.Row = 4;
    defaultPanel.Layout.Column = 1;
    defaultPanel.Title = 'Default for New Cases';
    conduction.gui.utils.Theme.applyAppBackground(defaultPanel);
    if isprop(defaultPanel, 'ForegroundColor')
        defaultPanel.ForegroundColor = conduction.gui.utils.Theme.primaryText();
    end

    defaultGrid = uigridlayout(defaultPanel);
    defaultGrid.RowHeight = {'1x'};
    defaultGrid.ColumnWidth = {'1x'};
    defaultGrid.Padding = [4 4 4 4];
    defaultGrid.RowSpacing = 0;
    conduction.gui.utils.Theme.applyAppBackground(defaultGrid);

    app.DefaultResourcesPanel = uipanel(defaultGrid);
    app.DefaultResourcesPanel.Layout.Row = 1;
    app.DefaultResourcesPanel.Layout.Column = 1;
    app.DefaultResourcesPanel.BorderType = 'none';
    app.DefaultResourcesPanel.BackgroundColor = conduction.gui.utils.Theme.panelBackground();

    % Create FormStateManager to track form changes and manage Save/Reset button states
    fields = {app.ResourceNameField, app.ResourceCapacitySpinner};
    app.ResourceFormStateManager = conduction.gui.utils.FormStateManager(fields, ...
        app.SaveResourceButton, app.ResetResourceButton);
end
