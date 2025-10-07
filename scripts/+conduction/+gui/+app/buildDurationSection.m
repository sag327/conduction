function buildDurationSection(app, leftGrid)
%BUILDDURATIONSECTION Render the duration selector controls in the Add tab.

    app.DurationStatsLabel = uilabel(leftGrid);
    app.DurationStatsLabel.Text = 'Duration';
    app.DurationStatsLabel.FontWeight = 'bold';
    app.DurationStatsLabel.Layout.Row = 14;
    app.DurationStatsLabel.Layout.Column = [1 4];

    app.DurationButtonGroup = uibuttongroup(leftGrid);
    app.DurationButtonGroup.BorderType = 'none';
    app.DurationButtonGroup.Layout.Row = 16;
    app.DurationButtonGroup.Layout.Column = [1 2];
    app.DurationButtonGroup.SelectionChangedFcn = @(src, event) app.DurationSelector.DurationOptionChanged(app, event);
    app.DurationButtonGroup.AutoResizeChildren = 'off';

    % Mini histogram axes to the right of button group
    app.DurationMiniHistogramAxes = uiaxes(leftGrid);
    app.DurationMiniHistogramAxes.Layout.Row = 16;
    app.DurationMiniHistogramAxes.Layout.Column = [3 4];
    app.DurationMiniHistogramAxes.Toolbar.Visible = 'off';
    app.DurationMiniHistogramAxes.Interactions = [];
    app.DurationMiniHistogramAxes.Visible = 'off';
    disableDefaultInteractivity(app.DurationMiniHistogramAxes);

    % Use EXACT original positioning from main branch
    startY = 68;
    rowSpacing = 22;
    labelX = 85;

    app.MedianRadioButton = uiradiobutton(app.DurationButtonGroup);
    app.MedianRadioButton.Interpreter = 'html';
    app.MedianRadioButton.Text = 'Median';
    app.MedianRadioButton.Tag = 'median';
    app.MedianRadioButton.Position = [5 startY 75 22];

    app.P70RadioButton = uiradiobutton(app.DurationButtonGroup);
    app.P70RadioButton.Interpreter = 'html';
    app.P70RadioButton.Text = 'P70';
    app.P70RadioButton.Tag = 'p70';
    app.P70RadioButton.Position = [5 startY - rowSpacing 75 22];

    app.P90RadioButton = uiradiobutton(app.DurationButtonGroup);
    app.P90RadioButton.Interpreter = 'html';
    app.P90RadioButton.Text = 'P90';
    app.P90RadioButton.Tag = 'p90';
    app.P90RadioButton.Position = [5 startY - 2 * rowSpacing 75 22];

    app.CustomRadioButton = uiradiobutton(app.DurationButtonGroup);
    app.CustomRadioButton.Interpreter = 'html';
    app.CustomRadioButton.Text = 'Custom';
    app.CustomRadioButton.Tag = 'custom';
    app.CustomRadioButton.Position = [5 startY - 3 * rowSpacing 75 22];

    app.MedianValueLabel = uilabel(app.DurationButtonGroup);
    app.MedianValueLabel.Text = '-';
    app.MedianValueLabel.Position = [labelX startY 110 22];
    app.MedianValueLabel.HorizontalAlignment = 'left';

    app.P70ValueLabel = uilabel(app.DurationButtonGroup);
    app.P70ValueLabel.Text = '-';
    app.P70ValueLabel.Position = [labelX startY - rowSpacing 110 22];
    app.P70ValueLabel.HorizontalAlignment = 'left';

    app.P90ValueLabel = uilabel(app.DurationButtonGroup);
    app.P90ValueLabel.Text = '-';
    app.P90ValueLabel.Position = [labelX startY - 2 * rowSpacing 110 22];
    app.P90ValueLabel.HorizontalAlignment = 'left';

    app.CustomDurationSpinner = uispinner(app.DurationButtonGroup);
    app.CustomDurationSpinner.Limits = [15 480];
    app.CustomDurationSpinner.Value = 60;
    app.CustomDurationSpinner.Step = 15;
    app.CustomDurationSpinner.Enable = 'off';
    app.CustomDurationSpinner.Position = [labelX startY - 3 * rowSpacing 70 22];

    % Apply theme colors
    app.DurationSelector.applyDurationThemeColors(app);
end
