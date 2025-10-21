classdef TestResourcePersistence < matlab.unittest.TestCase
    %TESTRESOURCEPERSISTENCE Ensure resources persist through export/import cycle.

    methods (Test)
        function testSaveLoadRoundTrip(testCase)
            import matlab.unittest.fixtures.PathFixture

            % Ensure scripts are on path
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));

            app = conduction.gui.ProspectiveSchedulerApp(datetime(2025, 1, 1));
            cleanupApp = onCleanup(@() delete(app)); %#ok<NASGU>
            drawnow limitrate;

            store = app.CaseManager.getResourceStore();
            resourceType = store.create("Affera", 2, 'Color', [0.2 0.4 0.8]);

            app.CaseManager.addCase("Dr. Adams", "Ablation");
            caseObj = app.CaseManager.getCase(1);
            caseObj.assignResource(resourceType.Id);

            if ~isempty(app.ResourceLegend) && isvalid(app.ResourceLegend)
                app.ResourceLegend.setHighlights(resourceType.Id);
            end
            app.ResourceHighlightIds = string(resourceType.Id);

            sessionData = app.exportAppState();

            delete(app);

            app2 = conduction.gui.ProspectiveSchedulerApp(datetime(2025, 1, 2));
            cleanupApp2 = onCleanup(@() delete(app2)); %#ok<NASGU>
            drawnow limitrate;

            app2.importAppState(sessionData);

            store2 = app2.CaseManager.getResourceStore();
            testCase.verifyTrue(store2.has(resourceType.Id));

            restoredCase = app2.CaseManager.getCase(1);
            testCase.verifyTrue(any(restoredCase.listRequiredResources() == resourceType.Id));

            testCase.verifyTrue(any(app2.ResourceHighlightIds == resourceType.Id));
            if ~isempty(app2.ResourceLegend) && isvalid(app2.ResourceLegend)
                highlights = app2.ResourceLegend.getHighlights();
                testCase.verifyTrue(any(highlights == resourceType.Id));
            end
        end
    end
end
