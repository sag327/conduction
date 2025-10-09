function app = createTestApp(targetDate)
    %CREATETESTAPP Create a test ProspectiveSchedulerApp instance
    %   app = createTestApp() creates app with default date (tomorrow)
    %   app = createTestApp(targetDate) creates app with specified date

    if nargin < 1
        targetDate = datetime('tomorrow');
    end

    app = conduction.gui.ProspectiveSchedulerApp(targetDate);
end
