function app = createTestAppWithCases(numCases, targetDate)
    %CREATETESTAPPWITHCASES Create test app with cases
    %   app = createTestAppWithCases() creates app with 3 test cases
    %   app = createTestAppWithCases(numCases) creates app with specified number of cases
    %   app = createTestAppWithCases(numCases, targetDate) creates app with date and cases

    if nargin < 1
        numCases = 3;
    end

    if nargin < 2
        targetDate = datetime('tomorrow');
    end

    app = conduction.gui.ProspectiveSchedulerApp(targetDate);

    for i = 1:numCases
        app.CaseManager.addCase(...
            sprintf('Dr. %d', i), ...
            sprintf('Procedure %d', i), ...
            60 + 10*i);
    end
end
