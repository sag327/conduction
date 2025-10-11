function buildDateSection(app, leftGrid)
%BUILDDATESECTION Create the date picker controls in the Add/Edit tab.

    app.DateLabel = uilabel(leftGrid);
    app.DateLabel.Text = 'Date:';
    app.DateLabel.Layout.Row = 1;
    app.DateLabel.Layout.Column = 1;

    app.DatePicker = uidatepicker(leftGrid);
    app.DatePicker.Layout.Row = 1;
    app.DatePicker.Layout.Column = [2 4];
    app.DatePicker.DisplayFormat = 'dd-MMM-yyyy';
    app.DatePicker.ValueChangedFcn = @(src, event) app.DatePickerValueChanged(event);
    if ~isempty(app.TargetDate)
        app.DatePicker.Value = app.TargetDate;
    end
end
