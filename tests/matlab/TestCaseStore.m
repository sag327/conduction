classdef TestCaseStore < matlab.unittest.TestCase
    %TESTCASESTORE Unit tests for the CaseStore view-model.

    properties
        CaseManager conduction.gui.controllers.CaseManager
        Store conduction.gui.stores.CaseStore
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture

            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            scriptsPath = fullfile(rootDir, 'scripts');
            testCase.applyFixture(PathFixture(scriptsPath));
        end
    end

    methods (TestMethodSetup)
        function createFixtures(testCase)
            targetDate = datetime('2025-01-01');
            testCase.CaseManager = conduction.gui.controllers.CaseManager(targetDate);
            testCase.Store = conduction.gui.stores.CaseStore(testCase.CaseManager);
        end
    end

    methods (TestMethodTeardown)
        function teardownFixtures(testCase)
            if ~isempty(testCase.Store) && isvalid(testCase.Store)
                delete(testCase.Store);
            end
        end
    end

    methods (Test)
        function testInitialStateIsEmpty(testCase)
            testCase.verifyEqual(testCase.Store.Data, {});
            testCase.verifyEmpty(testCase.Store.Selection);
            testCase.verifyFalse(testCase.Store.hasCases());
            testCase.verifyEqual(testCase.Store.caseCount(), 0);
        end

        function testDataUpdatesWhenCaseAdded(testCase)
            wasNotified = false;
            listener = addlistener(testCase.Store, 'DataChanged', @(~, ~) flagDataChanged());
            c = onCleanup(@() delete(listener)); %#ok<NASGU>

            testCase.CaseManager.addCase("Dr. Adams", "Ablation");

            testCase.verifyTrue(wasNotified, 'DataChanged event should fire after CaseManager mutation');
            testCase.verifyEqual(testCase.Store.caseCount(), 1);

            data = testCase.Store.Data;
            testCase.verifySize(data, [1, 9]);
            testCase.verifyEqual(data{1, 3}, 'Dr. Adams');
            testCase.verifyEqual(data{1, 4}, 'Ablation');
            testCase.verifyEqual(data{1, 7}, 'Any');
            testCase.verifyEqual(data{1, 8}, '--');
            testCase.verifyEqual(data{1, 9}, 'No');

            function flagDataChanged()
                wasNotified = true;
            end
        end

        function testSelectionChangeEvent(testCase)
            selectionNotified = false;
            listener = addlistener(testCase.Store, 'SelectionChanged', @(~, ~) flagSelection());
            c = onCleanup(@() delete(listener)); %#ok<NASGU>

            testCase.CaseManager.addCase("Dr. Evans", "PCI");
            testCase.Store.setSelection(1);

            testCase.verifyTrue(selectionNotified, 'SelectionChanged should fire when selection set');
            testCase.verifyEqual(testCase.Store.Selection, 1);

            function flagSelection()
                selectionNotified = true;
            end
        end

        function testSelectionTrimmedAfterRemoval(testCase)
            testCase.CaseManager.addCase("Dr. Lin", "Device");
            testCase.CaseManager.addCase("Dr. Patel", "Ablation");
            testCase.verifyEqual(testCase.Store.caseCount(), 2);

            changeCount = 0;
            listener = addlistener(testCase.Store, 'SelectionChanged', @(~, ~) increment());
            c = onCleanup(@() delete(listener)); %#ok<NASGU>

            testCase.Store.setSelection([1, 2]);
            testCase.verifyEqual(testCase.Store.Selection, [1, 2]);

            % Remove the second case directly via manager to simulate external mutation
            testCase.CaseManager.removeCase(2);

            testCase.verifyEqual(testCase.Store.caseCount(), 1);
            testCase.verifyEqual(testCase.Store.Selection, 1, 'Selection should trim invalid indices');
            testCase.verifyGreaterThan(changeCount, 0, 'SelectionChanged should fire when selection is trimmed');

            function increment()
                changeCount = changeCount + 1;
            end
        end

        function testRemoveSelectedRemovesCase(testCase)
            testCase.CaseManager.addCase("Dr. Gray", "Ablation");
            testCase.CaseManager.addCase("Dr. Gray", "Diagnostic");

            testCase.Store.setSelection(1);
            testCase.Store.removeSelected();

            testCase.verifyEqual(testCase.CaseManager.CaseCount, 1);
            testCase.verifyEqual(testCase.Store.caseCount(), 1);
            testCase.verifyEmpty(testCase.Store.Selection, 'Selection should clear after removal');

            data = testCase.Store.Data;
            testCase.verifyEqual(data{1, 4}, 'Diagnostic');
        end

        function testClearAllClearsManager(testCase)
            testCase.CaseManager.addCase("Dr. Gray", "Ablation");
            testCase.CaseManager.addCase("Dr. Gray", "Diagnostic");

            testCase.Store.clearAll();

            testCase.verifyEqual(testCase.CaseManager.CaseCount, 0);
            testCase.verifyFalse(testCase.Store.hasCases());
            testCase.verifyEqual(testCase.Store.Data, {});
            testCase.verifyEmpty(testCase.Store.Selection);
        end

        function testSetSortStateNotifies(testCase)
            notified = false;
            listener = addlistener(testCase.Store, 'SortChanged', @(~, ~) flag());
            c = onCleanup(@() delete(listener)); %#ok<NASGU>

            state = struct('Column', 3, 'Direction', 'ascend');
            testCase.Store.setSortState(state);
            testCase.verifyTrue(notified);
            testCase.verifyEqual(testCase.Store.SortState, state);

            % Setting the same state again should not trigger notification
            notified = false;
            testCase.Store.setSortState(state);
            testCase.verifyFalse(notified);

            % Resetting with empty should notify
            testCase.Store.setSortState(struct());
            testCase.verifyEqual(testCase.Store.SortState, struct());

            function flag()
                notified = true;
            end
        end
    end
end
