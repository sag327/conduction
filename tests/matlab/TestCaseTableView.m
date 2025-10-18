classdef TestCaseTableView < matlab.unittest.TestCase
    %TESTCASETABLEVIEW Validate CaseTableView behaviour.

    properties
        UIFigure matlab.ui.Figure
        Store conduction.gui.stores.CaseStore
        CaseManager conduction.gui.controllers.CaseManager
        View conduction.gui.components.CaseTableView
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupUI(testCase)
            targetDate = datetime('2025-01-01');
            testCase.CaseManager = conduction.gui.controllers.CaseManager(targetDate);
            testCase.Store = conduction.gui.stores.CaseStore(testCase.CaseManager);

            testCase.UIFigure = uifigure('Visible', 'off');
            testCase.View = conduction.gui.components.CaseTableView(testCase.UIFigure, testCase.Store);
        end
    end

    methods (TestMethodTeardown)
        function teardownUI(testCase)
            if ~isempty(testCase.View) && isvalid(testCase.View)
                delete(testCase.View);
            end
            if ~isempty(testCase.UIFigure) && isvalid(testCase.UIFigure)
                close(testCase.UIFigure);
            end
        end
    end

    methods (Test)
        function testInitialButtonsDisabled(testCase)
            testCase.verifyEqual(string(testCase.View.RemoveButton.Enable), "off");
            testCase.verifyEqual(string(testCase.View.ClearButton.Enable), "off");
            testCase.verifyEmpty(testCase.View.Table.Data);
        end

        function testDataRefreshOnStoreChange(testCase)
            testCase.CaseManager.addCase("Dr. Chen", "Ablation");
            drawnow;

            data = testCase.View.Table.Data;
            testCase.verifySize(data, [1, 8]);
            testCase.verifyEqual(data{1, 3}, 'Dr. Chen');
            testCase.verifyEqual(string(testCase.View.ClearButton.Enable), "on");
        end

        function testSelectionSync(testCase)
            testCase.CaseManager.addCase("Dr. Kim", "PCI");
            drawnow;

            % Simulate user selection
            evt = struct('Source', testCase.View.Table); %#ok<NASGU>
            testCase.View.Table.Selection = 1;
            testCase.View.Table.SelectionChangedFcn(testCase.View.Table, struct('Source', testCase.View.Table));

            testCase.verifyEqual(testCase.Store.Selection, 1);
            testCase.verifyEqual(string(testCase.View.RemoveButton.Enable), "on");
        end

        function testRemoveButtonHandlerInvoked(testCase)
            testCase.CaseManager.addCase("Dr. Lee", "Device");
            drawnow;

            removed = false;
            delete(testCase.View);

            handlerView = conduction.gui.components.CaseTableView(testCase.UIFigure, testCase.Store, ...
                struct('RemoveHandler', @(view) flagRemove(view)));
            testCase.View = handlerView;

            handlerView.Store.setSelection(1);
            drawnow;

            handlerView.RemoveButton.ButtonPushedFcn(handlerView.RemoveButton, []);

            testCase.verifyTrue(removed, 'Custom remove handler should execute');

            function flagRemove(view)
                removed = true;
                view.Store.clearSelection();
            end
        end

        function testClearButtonHandlerInvoked(testCase)
            testCase.CaseManager.addCase("Dr. Gomez", "Diagnostic");
            drawnow;

            cleared = false;
            delete(testCase.View);

            handlerView = conduction.gui.components.CaseTableView(testCase.UIFigure, testCase.Store, ...
                struct('ClearHandler', @(view) flagClear(view)));
            testCase.View = handlerView;

            handlerView.ClearButton.ButtonPushedFcn(handlerView.ClearButton, []);

            testCase.verifyTrue(cleared, 'Custom clear handler should execute');

            function flagClear(view)
                cleared = true;
                view.Store.clearSelection();
            end
        end
    end
end
