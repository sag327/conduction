function buildCaseManagementSection(app, casesGrid)
%BUILDCASEMANAGEMENTSECTION Populate the Cases tab with shared header and host panel.

    arguments
        app conduction.gui.ProspectiveSchedulerApp
        casesGrid matlab.ui.container.GridLayout
    end

    casesGrid.ColumnWidth = {'1x', 'fit'};
    casesGrid.RowHeight = {24, '1x'};
    casesGrid.Padding = [10 10 10 10];
    casesGrid.RowSpacing = 6;
    casesGrid.ColumnSpacing = 10;

    header = uigridlayout(casesGrid);
    header.Layout.Row = 1;
    header.Layout.Column = [1 2];
    header.RowHeight = {'fit'};
    header.ColumnWidth = {'1x', 'fit'};
    header.RowSpacing = 0;
    header.ColumnSpacing = 8;
    header.Padding = [0 0 0 0];

    app.CasesLabel = uilabel(header);
    app.CasesLabel.Text = 'Added Cases';
    app.CasesLabel.FontWeight = 'bold';
    app.CasesLabel.Layout.Row = 1;
    app.CasesLabel.Layout.Column = 1;

    app.CasesUndockButton = uibutton(header, 'push');
    app.CasesUndockButton.Layout.Row = 1;
    app.CasesUndockButton.Layout.Column = 2;
    app.CasesUndockButton.Text = 'Open Window';
    app.CasesUndockButton.Tooltip = 'Open cases in a separate window (Ctrl/Cmd+Shift+U)';
    iconPath = conduction.gui.utils.Icons.undockIcon();
    if ~isempty(iconPath)
        app.CasesUndockButton.Icon = iconPath;
        app.CasesUndockButton.IconAlignment = 'left';
    end
    app.CasesUndockButton.ButtonPushedFcn = @(src, evt) app.handleCasesUndockRequest();

    container = uipanel(casesGrid);
    container.Layout.Row = 2;
    container.Layout.Column = [1 2];
    container.BorderType = 'none';
    container.BackgroundColor = casesGrid.BackgroundColor;
    app.CasesEmbeddedContainer = container;
end
