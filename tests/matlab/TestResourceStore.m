classdef TestResourceStore < matlab.unittest.TestCase
    %TESTRESOURCESTORE Validate ResourceStore CRUD and events.

    properties
        Store conduction.gui.stores.ResourceStore
        LastEventCount double
    end

    methods (TestClassSetup)
        function addScriptPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function createStore(testCase)
            testCase.Store = conduction.gui.stores.ResourceStore();
            testCase.LastEventCount = 0;
            addlistener(testCase.Store, 'TypesChanged', @(~,~) testCase.incrementEvent());
        end
    end

    methods (Test)
        function testCreateResource(testCase)
            type = testCase.Store.create("Affera", 3);

            testCase.verifyEqual(type.Name, "Affera");
            testCase.verifyEqual(type.Capacity, 3);
            testCase.verifyTrue(testCase.Store.has(type.Id));
            testCase.verifyEqual(testCase.LastEventCount, 1);
        end

        function testUpdateResource(testCase)
            type = testCase.Store.create("RF Console", 2);
            testCase.Store.update(type.Id, 'Capacity', 4, 'Name', "RF Console X");

            updated = testCase.Store.get(type.Id);
            testCase.verifyEqual(updated.Name, "RF Console X");
            testCase.verifyEqual(updated.Capacity, 4);
            testCase.verifyGreaterThanOrEqual(testCase.LastEventCount, 2);
        end

        function testDuplicateNameRejected(testCase)
            testCase.Store.create("Device", 1);
            testCase.verifyError(@() testCase.Store.create("Device", 2), 'ResourceStore:DuplicateName');
        end

        function testRemoveResource(testCase)
            type = testCase.Store.create("Scope", 1);
            testCase.Store.remove(type.Id);

            testCase.verifyFalse(testCase.Store.has(type.Id));
            testCase.verifyGreaterThan(testCase.LastEventCount, 1);
        end

        function testIdsAndNames(testCase)
            a = testCase.Store.create("A", 1);
            b = testCase.Store.create("B", 2);

            names = testCase.Store.names();
            ids = testCase.Store.ids();

            testCase.verifyEqual(sort(names), sort(["A","B"]));
            testCase.verifyEqual(numel(ids), 2);
            testCase.verifyTrue(all(ids ~= ""));
            testCase.verifyEqual(testCase.LastEventCount, 2);
        end
    end

    methods (Access = private)
        function incrementEvent(testCase)
            testCase.LastEventCount = testCase.LastEventCount + 1;
        end
    end
end

