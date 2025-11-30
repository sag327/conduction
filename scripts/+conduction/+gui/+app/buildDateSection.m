function buildDateSection(app, leftGrid)
%BUILDDATESECTION Create the date picker controls in the Add/Edit tab.

    app.DateLabel = uilabel(leftGrid);
    app.DateLabel.Text = 'Date:';
    app.DateLabel.Layout.Row = 1;
    app.DateLabel.Layout.Column = 1;
    app.DateLabel.FontColor = conduction.gui.utils.Theme.primaryText();

    app.DatePicker = uidatepicker(leftGrid);
    app.DatePicker.Layout.Row = 1;
    app.DatePicker.Layout.Column = [2 4];
    app.DatePicker.DisplayFormat = 'dd-MMM-yyyy';
    app.DatePicker.ValueChangedFcn = @(src, event) app.DatePickerValueChanged(event);
    app.DatePicker.BackgroundColor = conduction.gui.utils.Theme.inputBackground();
    app.DatePicker.FontColor = conduction.gui.utils.Theme.primaryText();
    if ~isempty(app.TargetDate)
        app.DatePicker.Value = app.TargetDate;
    end
end
