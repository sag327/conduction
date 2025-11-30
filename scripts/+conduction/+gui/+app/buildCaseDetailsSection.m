function buildCaseDetailsSection(app, leftGrid)
%BUILDCASEDETAILSSECTION Add operator/procedure controls to the Add/Edit tab.

    app.CaseDetailsLabel = uilabel(leftGrid);
    app.CaseDetailsLabel.Text = 'Case Details';
    app.CaseDetailsLabel.FontWeight = 'bold';
    app.CaseDetailsLabel.Layout.Row = 10;
    app.CaseDetailsLabel.Layout.Column = [1 4];
    app.CaseDetailsLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.OperatorLabel = uilabel(leftGrid);
    app.OperatorLabel.Text = 'Operator:';
    app.OperatorLabel.Layout.Row = 11;
    app.OperatorLabel.Layout.Column = 1;
    app.OperatorLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.OperatorDropDown = uidropdown(leftGrid);
    app.OperatorDropDown.Items = {'Loading...'};
    app.OperatorDropDown.Layout.Row = 11;
    app.OperatorDropDown.Layout.Column = [2 4];
    app.OperatorDropDown.ValueChangedFcn = @(src, event) app.OperatorDropDownValueChanged(event);
    app.OperatorDropDown.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.OperatorDropDown.FontColor = conduction.gui.utils.Theme.primaryText();

    app.ProcedureLabel = uilabel(leftGrid);
    app.ProcedureLabel.Text = 'Procedure:';
    app.ProcedureLabel.Layout.Row = 12;
    app.ProcedureLabel.Layout.Column = 1;
    app.ProcedureLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.ProcedureDropDown = uidropdown(leftGrid);
    app.ProcedureDropDown.Items = {'Loading...'};
    app.ProcedureDropDown.Layout.Row = 12;
    app.ProcedureDropDown.Layout.Column = [2 4];
    app.ProcedureDropDown.ValueChangedFcn = @(src, event) app.ProcedureDropDownValueChanged(event);
    app.ProcedureDropDown.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.ProcedureDropDown.FontColor = conduction.gui.utils.Theme.primaryText();

    resourcesPanel = uipanel(leftGrid);
    resourcesPanel.Layout.Row = 13;
    resourcesPanel.Layout.Column = [1 4];
    resourcesPanel.BorderType = 'none';
    conduction.gui.utils.Theme.applyAppBackground(resourcesPanel);

    app.AddResourcesPanel = resourcesPanel;
end
