classdef TestResourceChecklist < matlab.unittest.TestCase
    %TESTRESOURCECHECKLIST Ensure checklist reflects store changes and selection updates.

    properties
        UIFigure matlab.ui.Figure
        Store conduction.gui.stores.ResourceStore
        Checklist conduction.gui.components.ResourceChecklist
        LastSelection string = string.empty(0,1)
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupChecklist(testCase)
            testCase.Store = conduction.gui.stores.ResourceStore();
            testCase.Store.create("Affera", 3, 'Color', [0.1 0.6 0.9]);
            testCase.Store.create("ICE", 2, 'Color', [0.4 0.8 0.4]);

            testCase.UIFigure = uifigure('Visible', 'off');
            testCase.Checklist = conduction.gui.components.ResourceChecklist(testCase.UIFigure, testCase.Store, ...
                'Title', "Resources", 'SelectionChangedFcn', @(ids) testCase.captureSelection(ids), 'ShowCreateButton', false);
        end
    end

    methods (TestMethodTeardown)
        function teardownChecklist(testCase)
            if ~isempty(testCase.Checklist) && isvalid(testCase.Checklist)
                delete(testCase.Checklist);
            end
            if ~isempty(testCase.UIFigure) && isvalid(testCase.UIFigure)
                close(testCase.UIFigure);
            end
        end
    end

    methods (Test)
        function testInitialSelectionEmpty(testCase)
            testCase.verifyEmpty(testCase.Checklist.getSelection());
        end

        function testSelectionFlow(testCase)
            drawnow limitrate;
            ids = testCase.Store.ids();
            testCase.Checklist.setSelection(ids(1));

            selection = testCase.Checklist.getSelection();
            testCase.verifyEqual(selection, ids(1));
            testCase.verifyEqual(testCase.LastSelection, ids(1));

            testCase.Checklist.setSelection(ids);
            testCase.verifyEqual(sort(testCase.Checklist.getSelection()), sort(ids(:)));
        end

        function testStoreChangesRefreshChecklist(testCase)
            testCase.Store.create("Console", 1, 'Color', [0.9 0.5 0.1]);
            drawnow limitrate;

            ids = testCase.Store.ids();
            testCase.verifyEqual(numel(ids), 3);
            testCase.Checklist.setSelection(ids(3));
            testCase.verifyEqual(testCase.Checklist.getSelection(), ids(3));
        end
    end

    methods (Access = private)
        function captureSelection(testCase, ids)
            testCase.LastSelection = string(ids(:));
        end
    end
end
