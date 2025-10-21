classdef TestResourceLegend < matlab.unittest.TestCase
    %TESTRESOURCELEGEND Verify resource legend display and highlight handling.

    properties
        UIFigure matlab.ui.Figure
        Legend conduction.gui.components.ResourceLegend
        LastHighlight string = string.empty(0, 1)
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function createLegend(testCase)
            testCase.UIFigure = uifigure('Visible', 'off');
            testCase.Legend = conduction.gui.components.ResourceLegend(testCase.UIFigure, ...
                'HighlightChangedFcn', @(ids) testCase.recordHighlight(ids));
        end
    end

    methods (TestMethodTeardown)
        function destroyLegend(testCase)
            if ~isempty(testCase.Legend) && isvalid(testCase.Legend)
                delete(testCase.Legend);
            end
            if ~isempty(testCase.UIFigure) && isvalid(testCase.UIFigure)
                close(testCase.UIFigure);
            end
            testCase.LastHighlight = string.empty(0, 1);
        end
    end

    methods (Test)
        function testDataBindingAndToggle(testCase)
            resourceTypes = repmat(struct('Id', "", 'Name', "", 'Capacity', 0, 'Color', [0 0 0], 'Pattern', "", 'IsTracked', true), 1, 2);
            resourceTypes(1).Id = "res1";
            resourceTypes(1).Name = "Affera";
            resourceTypes(1).Capacity = 2;
            resourceTypes(1).Color = [0.1 0.6 0.9];
            resourceTypes(2).Id = "res2";
            resourceTypes(2).Name = "Console";
            resourceTypes(2).Capacity = 0;
            resourceTypes(2).Color = [0.7 0.2 0.2];

            summary = repmat(struct('ResourceId', "", 'CaseIds', string.empty(0, 1)), 1, 2);
            summary(1).ResourceId = "res1";
            summary(1).CaseIds = ["c1", "c2", "c3"];
            summary(2).ResourceId = "res2";
            summary(2).CaseIds = string.empty(0, 1);

            testCase.Legend.setData(resourceTypes, summary);
            testCase.verifyEmpty(testCase.Legend.getHighlights());

            changed = testCase.Legend.setHighlights(["res1", "res2"]);
            testCase.verifyTrue(changed);
            highlights = testCase.Legend.getHighlights();
            testCase.verifyEqual(highlights, "res1");
            testCase.verifyEqual(testCase.LastHighlight, "res1");

            toggleRes1 = findobj(testCase.UIFigure, 'Type', 'uicheckbox', 'Tag', 'res1');
            toggleRes2 = findobj(testCase.UIFigure, 'Type', 'uicheckbox', 'Tag', 'res2');
            testCase.assertNotEmpty(toggleRes1);
            testCase.assertNotEmpty(toggleRes2);
            testCase.verifyEqual(toggleRes2.Enable, matlab.lang.OnOffSwitchState.off);

            % Toggle res1 off -> highlight cleared
            toggleRes1.Value = true; % ensure initial state
            toggleRes1.Value = false;
            toggleRes1.ValueChangedFcn(toggleRes1, []);
            testCase.verifyEmpty(testCase.Legend.getHighlights());

            % Manually set data to only resource 2 (capacity 0) ensures highlight trimmed silently
            testCase.LastHighlight = string.empty(0, 1);
            testCase.Legend.setData(resourceTypes(2), summary(2));
            testCase.verifyEmpty(testCase.Legend.getHighlights());
            testCase.verifyEmpty(testCase.LastHighlight, 'Callback should not fire when trimmed silently');
        end
    end

    methods (Access = private)
        function recordHighlight(testCase, ids)
            testCase.LastHighlight = string(ids(:));
        end
    end
end
