classdef TestSessionCompletedRestore < matlab.unittest.TestCase
    %TESTSESSIONCOMPLETEDRESTORE Verify completed-case archives persist through save/load.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (Test)
        function completedArchiveRoundTrips(testCase)
            app = conduction.gui.ProspectiveSchedulerApp(datetime(2025, 1, 1));
            c = onCleanup(@() delete(app));

            cm = app.CaseManager;
            cm.addCase("Dr. Adams", "Proc A", 60);
            cm.addCase("Dr. Baker", "Proc B", 50);
            cm.addCase("Dr. Carter", "Proc C", 40);

            % Capture IDs to remain stable after removals
            ids = strings(cm.CaseCount, 1);
            for idx = 1:cm.CaseCount
                ids(idx) = cm.getCase(idx).CaseId;
            end

            % Mark two cases as completed (archived) via CaseManager
            markCompleted(ids(2));
            markCompleted(ids(3));

            completedBefore = cm.getCompletedCases();
            completedIdsBefore = string({completedBefore.CaseId});
            testCase.verifyEqual(numel(completedBefore), 2);
            testCase.verifyEqual(cm.CaseCount, 1, 'Only one active case should remain.');

            sessionData = app.exportAppStateInternal();

            restoredApp = conduction.gui.ProspectiveSchedulerApp(datetime(2025, 2, 1));
            cr = onCleanup(@() delete(restoredApp));
            restoredApp.importAppStateInternal(sessionData);

            restoredCompleted = restoredApp.CaseManager.getCompletedCases();
            testCase.verifyEqual(string({restoredCompleted.CaseId})', completedIdsBefore');
            testCase.verifyEqual(restoredApp.CaseManager.CaseCount, 1, ...
                'Active case count should match pre-save state.');

            function markCompleted(caseId)
                [~, idx] = cm.findCaseById(caseId);
                cm.setCaseStatus(idx, "completed");
            end
        end
    end
end
