function buildCaseManagementSection(app, casesGrid)
%BUILDCASEMANAGEMENTSECTION Populate the Cases tab with table and controls.

    app.CasesLabel = uilabel(casesGrid);
    app.CasesLabel.Text = 'Added Cases';
    app.CasesLabel.FontWeight = 'bold';
    app.CasesLabel.Layout.Row = 1;
    app.CasesLabel.Layout.Column = [1 2];

    app.CasesTable = uitable(casesGrid);
    caseTableStyle = uistyle('HorizontalAlignment', 'left');
    addStyle(app.CasesTable, caseTableStyle);
    app.CasesTable.ColumnName = {'', 'ID', 'Operator', 'Procedure', 'Duration', 'Admission', 'Lab', 'First Case'};
    app.CasesTable.ColumnWidth = {45, 50, 100, 140, 80, 100, 90, 80};
    app.CasesTable.RowName = {};
    app.CasesTable.Layout.Row = 2;
    app.CasesTable.Layout.Column = [1 2];
    app.CasesTable.SelectionType = 'row';
    app.CasesTable.SelectionChangedFcn = @(src, event) app.CasesTableSelectionChanged(event);

    app.RemoveSelectedButton = uibutton(casesGrid, 'push');
    app.RemoveSelectedButton.Text = 'Remove Selected';
    app.RemoveSelectedButton.Layout.Row = 3;
    app.RemoveSelectedButton.Layout.Column = 1;
    app.RemoveSelectedButton.Enable = 'off';
    app.RemoveSelectedButton.ButtonPushedFcn = @(src, event) app.RemoveSelectedButtonPushed(event);

    app.ClearAllButton = uibutton(casesGrid, 'push');
    app.ClearAllButton.Text = 'Clear All';
    app.ClearAllButton.Layout.Row = 3;
    app.ClearAllButton.Layout.Column = 2;
    app.ClearAllButton.Enable = 'off';
    app.ClearAllButton.ButtonPushedFcn = @(src, event) app.ClearAllButtonPushed(event);
end
