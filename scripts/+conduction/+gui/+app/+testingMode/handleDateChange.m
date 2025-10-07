function handleDateChange(app)
%HANDLEDATECHANGE Update testing panel UI when the historical date changes.

    app.TestingModeController.updateTestingActionStates(app);
    selectedDate = app.TestingModeController.getSelectedTestingDate(app);
    if app.IsTestingModeActive && isa(selectedDate, 'datetime') && ~isnat(selectedDate)
        app.TestingInfoLabel.FontColor = [0.3 0.3 0.3];
        app.TestingInfoLabel.Text = 'Press "Run Test Day" to load the selected historical cases.';
    end
end
