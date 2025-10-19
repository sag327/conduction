classdef TestResourceManager < matlab.unittest.TestCase
    %TESTRESOURCEMANAGER Exercises the ResourceManager window logic programmatically.

    properties
        Store conduction.gui.stores.ResourceStore
        Manager conduction.gui.windows.ResourceManager
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupManager(testCase)
            testCase.Store = conduction.gui.stores.ResourceStore();
            testCase.Manager = conduction.gui.windows.ResourceManager(testCase.Store, 'Visible', 'off');
        end
    end

    methods (TestMethodTeardown)
        function teardownManager(testCase)
            if ~isempty(testCase.Manager) && isvalid(testCase.Manager)
                delete(testCase.Manager);
            end
        end
    end

    methods (Test)
        function testCreateResource(testCase)
            type = testCase.Manager.createResourceForTest("Affera", 3, [0.1 0.2 0.3]);
            testCase.verifyTrue(testCase.Store.has(type.Id));
            ids = testCase.Manager.listedResourceIds();
            testCase.verifyEqual(numel(ids), 1);
        end

        function testUpdateResource(testCase)
            type = testCase.Manager.createResourceForTest("Affera", 3, [0.1 0.2 0.3]);
            updated = testCase.Manager.updateResourceForTest(type.Id, 'Name', "Affera X", 'Capacity', 5);
            testCase.verifyEqual(updated.Name, "Affera X");
            testCase.verifyEqual(updated.Capacity, 5);
            ids = testCase.Manager.listedResourceIds();
            testCase.verifyEqual(numel(ids), 1);
        end

        function testDeleteResource(testCase)
            type = testCase.Manager.createResourceForTest("Affera", 3, [0.1 0.2 0.3]);
            testCase.Manager.deleteResourceForTest(type.Id);
            testCase.verifyFalse(testCase.Store.has(type.Id));
            testCase.verifyEmpty(testCase.Manager.listedResourceIds());
        end
    end
end

