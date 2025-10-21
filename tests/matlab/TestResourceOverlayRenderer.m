classdef TestResourceOverlayRenderer < matlab.unittest.TestCase
    %TESTRESOURCEOVERLAYRENDERER Ensure resource overlays render badges and masks.

    properties
        UIFigure matlab.ui.Figure
        Axes matlab.ui.control.UIAxes
        ScheduleRenderer conduction.gui.controllers.ScheduleRenderer
        AppStub struct
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupAxes(testCase)
            testCase.UIFigure = uifigure('Visible', 'off');
            testCase.Axes = uiaxes(testCase.UIFigure);
            testCase.Axes.Position = [20 20 400 400];
            testCase.Axes.YDir = 'reverse';
            testCase.ScheduleRenderer = conduction.gui.controllers.ScheduleRenderer();
            testCase.AppStub = struct('ScheduleAxes', testCase.Axes, 'ScheduleRenderer', testCase.ScheduleRenderer);
        end
    end

    methods (TestMethodTeardown)
        function teardownAxes(testCase)
            if ~isempty(testCase.UIFigure) && isvalid(testCase.UIFigure)
                close(testCase.UIFigure);
            end
        end
    end

    methods (Test)
        function testBadgesAndHighlights(testCase)
            % Create case block rectangles matching expected case IDs
            hold(testCase.Axes, 'on');
            rectA = rectangle(testCase.Axes, 'Position', [0.5, 8, 1, 2], 'FaceColor', 'none', 'Tag', 'CaseBlock');
            rectA.UserData = struct('caseId', 'caseA');
            rectB = rectangle(testCase.Axes, 'Position', [1.8, 11, 1, 1.5], 'FaceColor', 'none', 'Tag', 'CaseBlock');
            rectB.UserData = struct('caseId', 'caseB');
            hold(testCase.Axes, 'off');

            % Build simple DailySchedule with matching case entries
            labs = conduction.Lab.empty;
            labs(1) = conduction.Lab("Lab 1", "Main");
            assignments = cell(1, 1);
            assignments{1} = struct('caseID', "caseA", 'requiredResources', ["res1", "res2"]);
            assignments{1}(2) = struct('caseID', "caseB", 'requiredResources', "res3");
            schedule = conduction.DailySchedule(datetime('today'), labs, assignments, struct());

            resourceTypes = repmat(struct('Id', "", 'Name', "", 'Capacity', 0, 'Color', [0 0 0], 'Pattern', "", 'IsTracked', true), 1, 3);
            resourceTypes(1).Id = "res1"; resourceTypes(1).Name = "Affera"; resourceTypes(1).Capacity = 1; resourceTypes(1).Color = [0.1 0.6 0.9];
            resourceTypes(2).Id = "res2"; resourceTypes(2).Name = "Console"; resourceTypes(2).Capacity = 1; resourceTypes(2).Color = [0.8 0.3 0.2];
            resourceTypes(3).Id = "res3"; resourceTypes(3).Name = "ICE"; resourceTypes(3).Capacity = 1; resourceTypes(3).Color = [0.3 0.8 0.5];

            conduction.gui.renderers.ResourceOverlayRenderer.draw(testCase.AppStub, schedule, resourceTypes, string.empty(0, 1));

            testCase.verifyEmpty(findobj(testCase.Axes, 'Tag', 'ResourceBadge'), 'Badges should not be rendered.');

            % Apply highlight filter and ensure non-matching case is dimmed
            conduction.gui.renderers.ResourceOverlayRenderer.draw(testCase.AppStub, schedule, resourceTypes, "res1");

            masks = findobj(testCase.Axes, 'Tag', 'ResourceHighlightMask');
            testCase.verifyEqual(numel(masks), 1, 'Only one case should be dimmed when highlighting res1.');
            maskHandle = masks(1);
            testCase.verifyEqual(string(maskHandle.UserData.caseId), "caseB");

            outlines = findobj(testCase.Axes, 'Tag', 'ResourceHighlightOutline');
            testCase.verifyEqual(numel(outlines), 1, 'Highlighted case should have an outline.');
            outlineColor = get(outlines(1), 'EdgeColor');
            testCase.verifyEqual(outlineColor, resourceTypes(1).Color, 'Outline color should match resource color.');
        end
    end
end
