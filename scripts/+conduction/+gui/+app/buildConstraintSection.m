function buildConstraintSection(app, leftGrid)
%BUILDCONSTRAINTSECTION Construct constraint controls in the Add/Edit tab.

    app.AdmissionStatusLabel = uilabel(leftGrid);
    app.AdmissionStatusLabel.Text = 'Status:';
    app.AdmissionStatusLabel.Layout.Row = 18;
    app.AdmissionStatusLabel.Layout.Column = 1;
    app.AdmissionStatusLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.AdmissionStatusDropDown = uidropdown(leftGrid);
    app.AdmissionStatusDropDown.Items = {'outpatient', 'inpatient'};
    app.AdmissionStatusDropDown.Value = 'outpatient';
    app.AdmissionStatusDropDown.Layout.Row = 18;
    app.AdmissionStatusDropDown.Layout.Column = 2;
    app.AdmissionStatusDropDown.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.AdmissionStatusDropDown.FontColor = conduction.gui.utils.Theme.primaryText();

    app.AddConstraintButton = uibutton(leftGrid, 'push');
    app.AddConstraintButton.Text = '+ Add constraint';
    app.AddConstraintButton.Layout.Row = 20;
    app.AddConstraintButton.Layout.Column = [1 2];
    app.AddConstraintButton.ButtonPushedFcn = @(src, event) app.AddConstraintButtonPushed(event);

    app.ConstraintPanel = uipanel(leftGrid);
    app.ConstraintPanel.Layout.Row = 21;
    app.ConstraintPanel.Layout.Column = [1 4];
    app.ConstraintPanel.BorderType = 'none';
    app.ConstraintPanel.Visible = 'off';
    conduction.gui.utils.Theme.applyAppBackground(app.ConstraintPanel);

    app.ConstraintPanelGrid = uigridlayout(app.ConstraintPanel);
    app.ConstraintPanelGrid.ColumnWidth = {100, 140, 80, '1x'};
    app.ConstraintPanelGrid.RowHeight = {24, 24};
    app.ConstraintPanelGrid.Padding = [0 5 0 5];
    app.ConstraintPanelGrid.RowSpacing = 3;
    app.ConstraintPanelGrid.ColumnSpacing = 6;
    conduction.gui.utils.Theme.applyAppBackground(app.ConstraintPanelGrid);

    app.FirstCaseCheckBox = uicheckbox(app.ConstraintPanelGrid);
    app.FirstCaseCheckBox.Text = 'First case only';
    app.FirstCaseCheckBox.Value = false;
    app.FirstCaseCheckBox.Layout.Row = 1;
    app.FirstCaseCheckBox.Layout.Column = [1 4];
    app.FirstCaseCheckBox.FontColor = conduction.gui.utils.Theme.primaryText();

    app.SpecificLabLabel = uilabel(app.ConstraintPanelGrid);
    app.SpecificLabLabel.Text = 'Specific Lab:';
    app.SpecificLabLabel.Layout.Row = 2;
    app.SpecificLabLabel.Layout.Column = 1;
    app.SpecificLabLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.SpecificLabDropDown = uidropdown(app.ConstraintPanelGrid);
    app.SpecificLabDropDown.Items = {'Any Lab'};
    app.SpecificLabDropDown.Value = 'Any Lab';
    app.SpecificLabDropDown.Layout.Row = 2;
    app.SpecificLabDropDown.Layout.Column = 2;
    app.SpecificLabDropDown.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.SpecificLabDropDown.FontColor = conduction.gui.utils.Theme.primaryText();

    app.AddCaseButton = uibutton(leftGrid, 'push');
    app.AddCaseButton.Text = 'Add Case';
    app.AddCaseButton.Layout.Row = 23;
    app.AddCaseButton.Layout.Column = [1 4];
    app.AddCaseButton.ButtonPushedFcn = @(src, event) app.AddCaseButtonPushed(event);
    app.AddCaseButton.FontSize = 16;
    app.AddCaseButton.BackgroundColor = [0.2 0.5 0.8];
    app.AddCaseButton.FontColor = [1 1 1];
end
