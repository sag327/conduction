classdef TestCaseStatusStores < matlab.unittest.TestCase
    %TESTCASESTATUSSTORES Validate filtered and completed case stores.

    properties
        CaseManager conduction.gui.controllers.CaseManager
        CaseIds string
    end

    methods (TestMethodSetup)
        function setupCaseManager(testCase)
            cm = conduction.gui.controllers.CaseManager(datetime(2025, 1, 1));
            ids = strings(4, 1);
            for idx = 1:4
                operator = sprintf("Operator %d", idx);
                procedure = sprintf("Procedure %d", idx);
                cm.addCase(operator, procedure, NaN, "", false, "outpatient");
                ids(idx) = string(cm.getCase(idx).CaseId);
            end

            % Configure scheduled times
            cm.getCase(2).ScheduledProcStartTime = 480;
            cm.getCase(3).ScheduledProcStartTime = 540;

            % Move third case to completed archive
            cm.setCaseStatus(3, "completed");

            testCase.CaseManager = cm;
            testCase.CaseIds = ids;
        end
    end

    methods (Test)
        function filteredStoresPartition(testCase)
            cm = testCase.CaseManager;
            unschedStore = conduction.gui.stores.FilteredCaseStore(cm, "unscheduled");
            schedStore = conduction.gui.stores.FilteredCaseStore(cm, "scheduled");
            completedStore = conduction.gui.stores.CompletedCaseStore(cm);

            testCase.verifyEqual(unschedStore.caseCount(), 2);
            testCase.verifyEqual(schedStore.caseCount(), 1);
            testCase.verifyEqual(completedStore.caseCount(), 1);

            % Select by IDs
            unschedStore.setSelectedByIds(testCase.CaseIds(1));
            testCase.verifyEqual(unschedStore.getSelectedCaseIds(), string(testCase.CaseIds(1)));

            % Remove selected unscheduled case
            unschedStore.removeSelected();
            testCase.verifyEqual(cm.CaseCount, 2);
            testCase.verifyEqual(unschedStore.caseCount(), 1);

            % Clear all scheduled cases
            schedStore.clearAll();
            testCase.verifyEqual(cm.CaseCount, 1);
            testCase.verifyEqual(schedStore.caseCount(), 0);

            % Completed archive remove by selection
            completedIds = completedStore.getSelectedCaseIds();
            testCase.verifyTrue(isempty(completedIds)); % none selected yet
            completedStore.setSelectedByIds(testCase.CaseIds(3));
            testCase.verifyEqual(completedStore.getSelectedCaseIds(), string(testCase.CaseIds(3)));
            completedStore.removeSelected();
            testCase.verifyEqual(completedStore.caseCount(), 0);
        end

        function manualArchiveAndRestore(testCase)
            cm = testCase.CaseManager;
            cm.addCase("OpX", "ProcX", NaN, "", false, "outpatient");
            newCaseId = string(cm.getCase(cm.CaseCount).CaseId);

            cm.setCaseStatus(cm.CaseCount, "completed");
            testCase.verifyEqual(cm.CaseCount, 3);
            testCase.verifyEqual(numel(cm.getCompletedCases()), 2);

            completed = cm.getCompletedCases();
            restored = cm.restoreCompletedCases(completed(end));
            testCase.verifyEqual(restored(end), newCaseId);
            testCase.verifyEqual(cm.CaseCount, 4);
        end
    end
end
