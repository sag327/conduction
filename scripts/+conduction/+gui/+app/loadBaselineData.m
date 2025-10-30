function loadBaselineData(app)
%LOADBASELINEDATA Handle the interactive baseline data load workflow.
%   Extracted from ProspectiveSchedulerApp to keep the callback small while
%   preserving existing behavior.

    if isempty(app) || isempty(app.CaseManager)
        return;
    end

    % Disable session dropdown while loading
    app.SessionMenuDropDown.Enable = 'off';
    drawnow;

    success = app.CaseManager.loadClinicalDataInteractive(app.UIFigure);

    if success
        app.updateDropdowns();
        app.DurationSelector.refreshDurationOptions(app); % Refresh duration options with new data
    end

    app.TestingModeController.refreshTestingAvailability(app);

    % Re-enable session dropdown
    app.SessionMenuDropDown.Enable = 'on';
end
