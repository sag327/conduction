classdef AcceptanceUndockFlow < matlab.unittest.TestCase
    %ACCEPTANCEUNDOCKFLOW End-to-end regression covering undock/redock loop.

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
            testCase.App = conduction.gui.ProspectiveSchedulerApp();
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
        function testUndockRemoveRedockFlow(testCase)
            app = testCase.App;

            % Seed a case and ensure store reflects it
            app.CaseManager.addCase("Dr. Alpha", "Ablation");
            app.CaseStore.refresh();
            testCase.verifyEqual(app.CaseStore.caseCount(), 1);

            % Undock cases table
            app.handleCasesUndockRequest();
            testCase.verifyTrue(app.IsCasesUndocked);
            testCase.verifyNotEmpty(app.CasesPopout);
            testCase.verifyTrue(app.CasesPopout.isOpen());
            testCase.verifyEqual(string(app.CasesUndockButton.Enable), "off");

            % Remove the first case via shared store callbacks while undocked
            app.CaseStore.setSelection(1);
            app.RemoveSelectedButtonPushed([]);
            testCase.verifyEqual(app.CaseStore.caseCount(), 0);

            % Add another case while still undocked to confirm sync
            app.CaseManager.addCase("Dr. Beta", "Device");
            app.CaseStore.refresh();
            testCase.verifyEqual(app.CaseStore.caseCount(), 1);
            testCase.verifyGreaterThan(size(app.CasesPopout.TableView.Table.Data, 1), 0);

            % Redock and ensure embedded view is restored
            if ~isempty(app.CasesPopout) && isvalid(app.CasesPopout)
                app.CasesPopout.close();
            end
            testCase.verifyFalse(app.IsCasesUndocked);
            testCase.verifyTrue(isempty(app.CasesPopout) || ~isvalid(app.CasesPopout));
            testCase.verifyEqual(string(app.CasesUndockButton.Enable), "on");
            testCase.verifyGreaterThan(size(app.CasesView.Table.Data, 1), 0);

            % Final cleanup: clear all via store and ensure empty state
            app.CaseStore.clearAll();
            app.CaseStore.refresh();
            testCase.verifyEqual(app.CaseStore.caseCount(), 0);
        end
    end
end
