classdef TestTimeControlBuckets < matlab.unittest.TestCase
    %TESTTIMECONTROLBUCKETS Ensure Time Control simulation keeps cases in active buckets.

    properties
        App conduction.gui.ProspectiveSchedulerApp
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function createApp(testCase)
            testCase.App = conduction.gui.ProspectiveSchedulerApp(datetime(2025, 1, 1));
        end
    end

    methods (TestMethodTeardown)
        function destroyApp(testCase)
            if ~isempty(testCase.App) && isvalid(testCase.App)
                delete(testCase.App);
            end
        end
    end

    methods (Test)
        function simulatedCompletionStaysInScheduledBucket(testCase)
            app = testCase.App;
            cm = app.CaseManager;

            % Create two cases with scheduled times
            cm.addCase("Dr. A", "Procedure A", 60);
            cm.addCase("Dr. B", "Procedure B", 75);
            case1 = cm.getCase(1);
            case2 = cm.getCase(2);

            case1.ScheduledProcStartTime = 480;
            case1.ScheduledEndTime = 540;
            case2.ScheduledProcStartTime = 600;
            case2.ScheduledEndTime = 660;

            caseIds = [string(case1.CaseId), string(case2.CaseId)];

            % Build a simple schedule that mirrors these cases
            labCases(1) = struct( ...
                'caseID', char(caseIds(1)), ...
                'procStartTime', 480, ...
                'procEndTime', 540, ...
                'caseStatus', 'pending');
            labCases(2) = struct( ...
                'caseID', char(caseIds(2)), ...
                'procStartTime', 600, ...
                'procEndTime', 660, ...
                'caseStatus', 'pending');

            labs = conduction.Lab("Lab 1", "Main");
            app.OptimizedSchedule = conduction.DailySchedule(app.TargetDate, labs, {labCases}, struct());

            % Simulate Time Control advancing past the first case
            currentTime = 600; % 10:00 AM
            app.ScheduleRenderer.updateCaseStatusesByTime(app, currentTime);

            % Case statuses update for visualization and archive tracking
            testCase.verifyEqual(cm.CaseCount, 2, 'Active case collection should remain intact.');
            testCase.verifyEqual(numel(cm.getCompletedCases()), 1, ...
                'Completed archive should include the finished case.');
            testCase.verifyEqual(string(cm.getCase(1).CaseStatus), "completed");
            testCase.verifyEqual(string(cm.getCase(2).CaseStatus), "in_progress", ...
                'Second case should transition to in-progress at the current time mark.');

            % Bucket classification must remain purely schedule-based
            caseArray = conduction.gui.models.ProspectiveCase.empty;
            for idx = 1:cm.CaseCount
                caseArray(idx) = cm.getCase(idx); %#ok<AGROW>
            end

            parts = conduction.gui.status.partitionActiveCases(caseArray);
            testCase.verifyEmpty(parts.UnscheduledIdx, 'Both cases have scheduled start times.');
            testCase.verifyEqual(sort(parts.ScheduledIdx), [1 2]);
        end
    end
end
