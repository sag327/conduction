function buildTestingPanel(app)
%BUILDTESTINGPANEL Construct the testing controls panel.

    if isempty(app.TestPanel) || ~isvalid(app.TestPanel)
        return;
    end

    app.TestPanelLayout = uigridlayout(app.TestPanel);
    app.TestPanelLayout.ColumnWidth = {110, '1x'};
    app.TestPanelLayout.RowHeight = {22, 32, 32, 'fit'};
    app.TestPanelLayout.Padding = [10 10 10 10];
    app.TestPanelLayout.RowSpacing = 6;
    app.TestPanelLayout.ColumnSpacing = 8;

    app.TestingSectionLabel = uilabel(app.TestPanelLayout);
    app.TestingSectionLabel.Text = 'Dataset';
    app.TestingSectionLabel.Layout.Row = 1;
    app.TestingSectionLabel.Layout.Column = 1;
    app.TestingSectionLabel.HorizontalAlignment = 'left';

    app.TestingDatasetLabel = uilabel(app.TestPanelLayout);
    app.TestingDatasetLabel.Text = '(none)';
    app.TestingDatasetLabel.Layout.Row = 1;
    app.TestingDatasetLabel.Layout.Column = 2;
    app.TestingDatasetLabel.HorizontalAlignment = 'left';

    app.TestingDateLabel = uilabel(app.TestPanelLayout);
    app.TestingDateLabel.Text = 'Historical day:';
    app.TestingDateLabel.Layout.Row = 2;
    app.TestingDateLabel.Layout.Column = 1;

    app.TestingDateDropDown = uidropdown(app.TestPanelLayout);
    app.TestingDateDropDown.Items = {'Select a date'};
    app.TestingDateDropDown.Value = 'Select a date';
    app.TestingDateDropDown.UserData = datetime.empty;
    app.TestingDateDropDown.Enable = 'off';
    app.TestingDateDropDown.Layout.Row = 2;
    app.TestingDateDropDown.Layout.Column = 2;
    app.TestingDateDropDown.ValueChangedFcn = @(src, event) app.TestingDateDropDownValueChanged(event);

    app.TestingRunButton = uibutton(app.TestPanelLayout, 'push');
    app.TestingRunButton.Text = 'Run Test Day';
    app.TestingRunButton.Enable = 'off';
    app.TestingRunButton.Layout.Row = 3;
    app.TestingRunButton.Layout.Column = 1;
    app.TestingRunButton.ButtonPushedFcn = @(src, event) app.TestingRunButtonPushed(event);

    app.TestingExitButton = uibutton(app.TestPanelLayout, 'push');
    app.TestingExitButton.Text = 'Exit Testing Mode';
    app.TestingExitButton.Enable = 'off';
    app.TestingExitButton.Layout.Row = 3;
    app.TestingExitButton.Layout.Column = 2;
    app.TestingExitButton.ButtonPushedFcn = @(src, event) app.TestingExitButtonPushed(event);

    app.TestingInfoLabel = uilabel(app.TestPanelLayout);
    app.TestingInfoLabel.Text = 'Testing mode disabled.';
    app.TestingInfoLabel.FontColor = [0.4 0.4 0.4];
    app.TestingInfoLabel.Layout.Row = 4;
    app.TestingInfoLabel.Layout.Column = [1 2];
    app.TestingInfoLabel.WordWrap = 'on';
end
