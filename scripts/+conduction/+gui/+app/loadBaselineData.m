function loadBaselineData(app)
%LOADBASELINEDATA Handle the interactive baseline data load workflow.
%   Extracted from ProspectiveSchedulerApp to keep the callback small while
%   preserving existing behavior.

    if isempty(app) || isempty(app.CaseManager)
        return;
    end

    app.LoadDataButton.Enable = 'off';
    drawnow;

    success = app.CaseManager.loadClinicalDataInteractive();

    if success
        app.updateDropdowns();
        app.DurationSelector.refreshDurationOptions(app); % Refresh duration options with new data
    end

    app.TestingModeController.refreshTestingAvailability(app);

    app.LoadDataButton.Enable = 'on';
end
