function buildDrawerUI(app)
%BUILDDRAWERUI Construct the inspector drawer layout and controls.

    if isempty(app.Drawer) || ~isvalid(app.Drawer)
        return;
    end

    app.DrawerLayout = uigridlayout(app.Drawer);
    app.DrawerLayout.RowHeight = {'1x', 60, '1x'};
    app.DrawerLayout.ColumnWidth = {conduction.gui.app.Constants.DrawerHandleWidth, conduction.gui.app.Constants.DrawerContentWidth};
    app.DrawerLayout.Padding = [0 0 0 0];
    app.DrawerLayout.RowSpacing = 0;
    app.DrawerLayout.ColumnSpacing = 0;
    app.DrawerLayout.BackgroundColor = app.Drawer.BackgroundColor;

    leftPanel = uipanel(app.DrawerLayout);
    leftPanel.Layout.Row = [1 3];
    leftPanel.Layout.Column = 1;
    leftPanel.BackgroundColor = app.UIFigure.Color;
    leftPanel.BorderType = 'none';

    leftGrid = uigridlayout(leftPanel);
    leftGrid.RowHeight = {'1x', 60, '1x'};
    leftGrid.ColumnWidth = {conduction.gui.app.Constants.DrawerHandleWidth};
    leftGrid.Padding = [0 0 0 0];
    leftGrid.RowSpacing = 0;
    leftGrid.ColumnSpacing = 0;
    leftGrid.BackgroundColor = app.UIFigure.Color;

    app.DrawerHandleButton = uibutton(leftGrid, 'push');
    app.DrawerHandleButton.Layout.Row = 2;
    app.DrawerHandleButton.Layout.Column = 1;
    app.DrawerHandleButton.Text = '◀';
    app.DrawerHandleButton.FontSize = 14;
    app.DrawerHandleButton.FontWeight = 'normal';
    app.DrawerHandleButton.BackgroundColor = [0.2 0.2 0.2];
    app.DrawerHandleButton.FontColor = [0.6 0.6 0.6];
    app.DrawerHandleButton.ButtonPushedFcn = @(src, event) app.DrawerHandleButtonPushed(event);
    app.DrawerHandleButton.Tooltip = {'Show Inspector'};

    contentPanel = uipanel(app.DrawerLayout);
    contentPanel.Layout.Row = [1 3];
    contentPanel.Layout.Column = 2;
    contentPanel.BackgroundColor = app.Drawer.BackgroundColor;
    contentPanel.BorderType = 'line';

    contentGrid = uigridlayout(contentPanel);
    contentGrid.RowHeight = {36, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 230};
    contentGrid.ColumnWidth = {'1x'};
    contentGrid.Padding = [16 18 16 18];
    contentGrid.RowSpacing = 12;
    contentGrid.ColumnSpacing = 0;
    contentGrid.BackgroundColor = app.Drawer.BackgroundColor;

    app.DrawerHeaderLabel = uilabel(contentGrid);
    app.DrawerHeaderLabel.Text = 'Inspector';
    app.DrawerHeaderLabel.FontSize = 16;
    app.DrawerHeaderLabel.FontWeight = 'bold';
    app.DrawerHeaderLabel.FontColor = [1 1 1];
    app.DrawerHeaderLabel.Layout.Row = 1;
    app.DrawerHeaderLabel.Layout.Column = 1;

    app.DrawerInspectorTitle = uilabel(contentGrid);
    app.DrawerInspectorTitle.Text = 'Case Details';
    app.DrawerInspectorTitle.FontWeight = 'bold';
    app.DrawerInspectorTitle.FontColor = [0.9 0.9 0.9];
    app.DrawerInspectorTitle.Layout.Row = 2;
    app.DrawerInspectorTitle.Layout.Column = 1;

    app.DrawerLockToggle = uicheckbox(contentGrid);
    app.DrawerLockToggle.Text = 'Lock case time';
    app.DrawerLockToggle.FontColor = [1 0 0];
    app.DrawerLockToggle.Layout.Row = 3;
    app.DrawerLockToggle.Layout.Column = 1;
    app.DrawerLockToggle.ValueChangedFcn = @(src, event) app.DrawerLockToggleChanged(event);

    app.DrawerInspectorGrid = uigridlayout(contentGrid);
    app.DrawerInspectorGrid.Layout.Row = 4;
    app.DrawerInspectorGrid.Layout.Column = 1;
    app.DrawerInspectorGrid.RowHeight = repmat({'fit'}, 1, 6);
    app.DrawerInspectorGrid.ColumnWidth = {90, '1x'};
    app.DrawerInspectorGrid.RowSpacing = 4;
    app.DrawerInspectorGrid.ColumnSpacing = 12;
    app.DrawerInspectorGrid.Padding = [0 0 0 0];
    app.DrawerInspectorGrid.BackgroundColor = app.Drawer.BackgroundColor;

    createInspectorRow(app, 1, 'Case', 'DrawerCaseValueLabel');
    createInspectorRow(app, 2, 'Procedure', 'DrawerProcedureValueLabel');
    createInspectorRow(app, 3, 'Operator', 'DrawerOperatorValueLabel');
    createInspectorRow(app, 4, 'Lab', 'DrawerLabValueLabel');
    createInspectorRow(app, 5, 'Start', 'DrawerStartValueLabel');
    createInspectorRow(app, 6, 'End', 'DrawerEndValueLabel');

    % DURATION-EDITING: Add durations section
    app.DrawerDurationsTitle = uilabel(contentGrid);
    app.DrawerDurationsTitle.Text = 'Case Durations (minutes)';
    app.DrawerDurationsTitle.FontWeight = 'bold';
    app.DrawerDurationsTitle.FontColor = [0.9 0.9 0.9];
    app.DrawerDurationsTitle.Layout.Row = 5;
    app.DrawerDurationsTitle.Layout.Column = 1;

    app.DrawerDurationsGrid = uigridlayout(contentGrid);
    app.DrawerDurationsGrid.Layout.Row = 6;
    app.DrawerDurationsGrid.Layout.Column = 1;
    app.DrawerDurationsGrid.RowHeight = repmat({'fit'}, 1, 3);
    app.DrawerDurationsGrid.ColumnWidth = {90, '1x'};
    app.DrawerDurationsGrid.RowSpacing = 4;
    app.DrawerDurationsGrid.ColumnSpacing = 12;
    app.DrawerDurationsGrid.Padding = [0 0 0 0];
    app.DrawerDurationsGrid.BackgroundColor = app.Drawer.BackgroundColor;

    createDurationRow(app, 1, 'Setup', 'DrawerSetupSpinner');
    createDurationRow(app, 2, 'Procedure', 'DrawerProcSpinner');
    createDurationRow(app, 3, 'Post', 'DrawerPostSpinner');

    app.DrawerOptimizationTitle = uilabel(contentGrid);
    app.DrawerOptimizationTitle.Text = 'Optimization Details';
    app.DrawerOptimizationTitle.FontWeight = 'bold';
    app.DrawerOptimizationTitle.FontColor = [0.9 0.9 0.9];
    app.DrawerOptimizationTitle.Layout.Row = 7;
    app.DrawerOptimizationTitle.Layout.Column = 1;

    app.DrawerOptimizationGrid = uigridlayout(contentGrid);
    app.DrawerOptimizationGrid.Layout.Row = 8;
    app.DrawerOptimizationGrid.Layout.Column = 1;
    app.DrawerOptimizationGrid.RowHeight = repmat({'fit'}, 1, 3);
    app.DrawerOptimizationGrid.ColumnWidth = {90, '1x'};
    app.DrawerOptimizationGrid.RowSpacing = 4;
    app.DrawerOptimizationGrid.ColumnSpacing = 12;
    app.DrawerOptimizationGrid.Padding = [0 8 0 0];
    app.DrawerOptimizationGrid.BackgroundColor = app.Drawer.BackgroundColor;

    createOptimizationRow(app, 1, 'Metric', 'DrawerMetricValueLabel');
    createOptimizationRow(app, 2, 'Labs', 'DrawerLabsValueLabel');
    createOptimizationRow(app, 3, 'Timings', 'DrawerTimingsValueLabel');

    app.DrawerHistogramTitle = uilabel(contentGrid);
    app.DrawerHistogramTitle.Text = 'Historical Durations';
    app.DrawerHistogramTitle.FontWeight = 'bold';
    app.DrawerHistogramTitle.FontColor = [0.9 0.9 0.9];
    app.DrawerHistogramTitle.Layout.Row = 9;
    app.DrawerHistogramTitle.Layout.Column = 1;

    app.DrawerHistogramPanel = uipanel(contentGrid);
    app.DrawerHistogramPanel.Layout.Row = 10;
    app.DrawerHistogramPanel.Layout.Column = 1;
    app.DrawerHistogramPanel.BackgroundColor = app.Drawer.BackgroundColor;
    app.DrawerHistogramPanel.BorderType = 'none';

    app.DrawerHistogramAxes = uiaxes(app.DrawerHistogramPanel);
    app.DrawerHistogramAxes.Units = 'normalized';
    app.DrawerHistogramAxes.Position = [0, 0, 1, 1];
    app.DrawerHistogramAxes.Toolbar.Visible = 'off';
    app.DrawerHistogramAxes.Interactions = [];
    disableDefaultInteractivity(app.DrawerHistogramAxes);

    app.DrawerHistogramPanel.SizeChangedFcn = [];

    app.DrawerController.setDrawerWidth(app, conduction.gui.app.Constants.DrawerHandleWidth);
end

function createInspectorRow(app, rowIndex, labelText, valuePropName)
    staticLabel = uilabel(app.DrawerInspectorGrid);
    staticLabel.Text = labelText;
    staticLabel.FontColor = [0.7 0.7 0.7];
    staticLabel.Layout.Row = rowIndex;
    staticLabel.Layout.Column = 1;

    valueLabel = uilabel(app.DrawerInspectorGrid);
    valueLabel.Text = '--';
    valueLabel.FontColor = [0.95 0.95 0.95];
    valueLabel.Layout.Row = rowIndex;
    valueLabel.Layout.Column = 2;
    valueLabel.WordWrap = 'on';

    app.(valuePropName) = valueLabel;
end

function createOptimizationRow(app, rowIndex, labelText, valuePropName)
    staticLabel = uilabel(app.DrawerOptimizationGrid);
    staticLabel.Text = labelText;
    staticLabel.FontColor = [0.7 0.7 0.7];
    staticLabel.Layout.Row = rowIndex;
    staticLabel.Layout.Column = 1;

    valueLabel = uilabel(app.DrawerOptimizationGrid);
    valueLabel.Text = '--';
    valueLabel.FontColor = [0.95 0.95 0.95];
    valueLabel.Layout.Row = rowIndex;
    valueLabel.Layout.Column = 2;
    valueLabel.WordWrap = 'on';

    app.(valuePropName) = valueLabel;
end

function createDurationRow(app, rowIndex, labelText, spinnerPropName)
    % DURATION-EDITING: Create a row with a label and spinner for duration input
    staticLabel = uilabel(app.DrawerDurationsGrid);
    staticLabel.Text = labelText;
    staticLabel.FontColor = [0.7 0.7 0.7];
    staticLabel.Layout.Row = rowIndex;
    staticLabel.Layout.Column = 1;

    spinner = uispinner(app.DrawerDurationsGrid);
    spinner.Limits = [0 Inf];
    spinner.Value = 0;
    spinner.ValueDisplayFormat = '%.0f';
    spinner.FontColor = [0.95 0.95 0.95];
    spinner.BackgroundColor = [0.15 0.15 0.15];
    spinner.Layout.Row = rowIndex;
    spinner.Layout.Column = 2;
    spinner.Enable = 'on';

    % Wire up callback based on spinner type
    callbackName = [spinnerPropName 'Changed'];
    spinner.ValueChangedFcn = @(src, event) app.(callbackName)(event);

    app.(spinnerPropName) = spinner;
end
