function buildCaseDetailsSection(app, leftGrid)
%BUILDCASEDETAILSSECTION Add operator/procedure controls to the Add/Edit tab.

    app.CaseDetailsLabel = uilabel(leftGrid);
    app.CaseDetailsLabel.Text = 'Case Details';
    app.CaseDetailsLabel.FontWeight = 'bold';
    app.CaseDetailsLabel.Layout.Row = 10;
    app.CaseDetailsLabel.Layout.Column = [1 4];

    app.OperatorLabel = uilabel(leftGrid);
    app.OperatorLabel.Text = 'Operator:';
    app.OperatorLabel.Layout.Row = 11;
    app.OperatorLabel.Layout.Column = 1;

    app.OperatorDropDown = uidropdown(leftGrid);
    app.OperatorDropDown.Items = {'Loading...'};
    app.OperatorDropDown.Layout.Row = 11;
    app.OperatorDropDown.Layout.Column = [2 4];
    app.OperatorDropDown.ValueChangedFcn = @(src, event) app.OperatorDropDownValueChanged(event);

    app.ProcedureLabel = uilabel(leftGrid);
    app.ProcedureLabel.Text = 'Procedure:';
    app.ProcedureLabel.Layout.Row = 12;
    app.ProcedureLabel.Layout.Column = 1;

    app.ProcedureDropDown = uidropdown(leftGrid);
    app.ProcedureDropDown.Items = {'Loading...'};
    app.ProcedureDropDown.Layout.Row = 12;
    app.ProcedureDropDown.Layout.Column = [2 4];
    app.ProcedureDropDown.ValueChangedFcn = @(src, event) app.ProcedureDropDownValueChanged(event);

    resourcesPanel = uipanel(leftGrid);
    resourcesPanel.Layout.Row = 13;
    resourcesPanel.Layout.Column = [1 4];
    resourcesPanel.BorderType = 'none';
    resourcesPanel.BackgroundColor = app.TabAdd.BackgroundColor;

    app.AddResourcesPanel = resourcesPanel;
end
