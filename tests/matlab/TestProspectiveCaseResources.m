classdef TestProspectiveCaseResources < matlab.unittest.TestCase
    %TESTPROSPECTIVECASERESOURCES Validate per-case resource helpers and CaseManager aggregation.

    properties
        Store conduction.gui.stores.ResourceStore
        Manager conduction.gui.controllers.CaseManager
    end

    methods (TestClassSetup)
        function addScriptPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupFixtures(testCase)
            testCase.Store = conduction.gui.stores.ResourceStore();
            testCase.Manager = conduction.gui.controllers.CaseManager(datetime('today'));
            testCase.Manager.setResourceStore(testCase.Store);
        end
    end

    methods (Test)
        function testAssignAndRemoveResources(testCase)
            type = testCase.Store.create("Affera", 3);
            caseObj = conduction.gui.models.ProspectiveCase("Dr. A", "Ablation");

            testCase.verifyFalse(caseObj.requiresResource(type.Id));
            caseObj.assignResource(type.Id);
            testCase.verifyTrue(caseObj.requiresResource(type.Id));

            caseObj.assignResource(type.Id); % duplicate should be ignored
            testCase.verifyEqual(numel(caseObj.listRequiredResources()), 1);

            caseObj.removeResource(type.Id);
            testCase.verifyFalse(caseObj.requiresResource(type.Id));
        end

        function testCaseManagerSummary(testCase)
            affera = testCase.Store.create("Affera", 3);
            ice = testCase.Store.create("ICE", 2);

            testCase.Manager.addCase("Dr. A", "Procedure 1");
            testCase.Manager.addCase("Dr. B", "Procedure 2");
            first = testCase.Manager.getCase(1);
            second = testCase.Manager.getCase(2);

            first.assignResource(affera.Id);
            second.assignResource(affera.Id);
            second.assignResource(ice.Id);

            list = testCase.Manager.casesRequiringResource(affera.Id);
            testCase.verifyEqual(numel(list), 2);

            summary = testCase.Manager.caseResourceSummary();
            ids = string({summary.ResourceId});
            testCase.verifyTrue(any(ids == affera.Id));
            testCase.verifyTrue(any(ids == ice.Id));
            affSegment = summary(ids == affera.Id);
            testCase.verifyEqual(numel(affSegment.CaseIds), 2);
        end
    end
end

