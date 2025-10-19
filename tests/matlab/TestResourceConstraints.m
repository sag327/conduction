classdef TestResourceConstraints < matlab.unittest.TestCase
    %TESTRESOURCECONSTRAINTS Validate resource-aware optimization behaviour.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            scriptsPath = fullfile(rootDir, 'scripts');
            testCase.applyFixture(PathFixture(scriptsPath));
        end
    end

    methods (Test)
        function testResourceCapacityEnforced(testCase)
            targetDate = datetime('2025-01-01');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanupManager = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resourceType = store.create("Affera", 1);

            caseManager.addCase("Dr. Allen", "Ablation");
            caseManager.addCase("Dr. Baker", "Ablation");

            firstCase = caseManager.getCase(1);
            firstCase.assignResource(resourceType.Id);
            secondCase = caseManager.getCase(2);
            secondCase.assignResource(resourceType.Id);

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [casesStruct, ~] = caseManager.buildOptimizationCases(1:2, defaults);

            resourceSnapshot = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs( ...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'CaseFilter', 'all', ...
                'MaxOperatorTime', 480, ...
                'TurnoverTime', 0, ...
                'EnforceMidnight', true, ...
                'PrioritizeOutpatient', false, ...
                'AvailableLabs', [1 2], ...
                'ResourceTypes', resourceSnapshot);

            [~, outcome] = conduction.optimizeDailySchedule(casesStruct, options);

            testCase.verifyTrue(isfield(outcome, 'ResourceViolations'));
            testCase.verifyEmpty(outcome.ResourceViolations, ...
                'Resource constraint should prevent overlap when capacity is 1.');

            labs = outcome.scheduleStruct.labs;
            scheduledCases = [labs{:}];
            testCase.verifyEqual(numel(scheduledCases), 2, 'Expected both cases to be scheduled.');

            [~, order] = sort([scheduledCases.procStartTime]);
            orderedCases = scheduledCases(order);
            testCase.verifyGreaterThanOrEqual(orderedCases(2).procStartTime, orderedCases(1).procEndTime, ...
                'Cases requiring the same resource must execute sequentially.');

            assignments = outcome.ResourceAssignments;
            testCase.verifyEqual(numel(assignments), 1);
            testCase.verifyEqual(assignments(1).ResourceId, resourceType.Id);

            expectedIds = sort(string({casesStruct.caseID})');
            actualIds = sort(assignments(1).CaseIds(:));
            testCase.verifyEqual(actualIds, expectedIds, 'Resource assignment list should include both cases.');
        end

        function testViolationDiagnosticsDetectsOverlap(testCase)
            targetDate = datetime('2025-01-02');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanupManager = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resourceType = store.create("Shared", 2);

            caseManager.addCase("Dr. Chen", "Device Implant");
            caseManager.addCase("Dr. Diaz", "Device Implant");

            caseManager.getCase(1).assignResource(resourceType.Id);
            caseManager.getCase(2).assignResource(resourceType.Id);

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [casesStruct, ~] = caseManager.buildOptimizationCases(1:2, defaults);

            resourceSnapshot = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs( ...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'CaseFilter', 'all', ...
                'MaxOperatorTime', 480, ...
                'TurnoverTime', 0, ...
                'EnforceMidnight', true, ...
                'PrioritizeOutpatient', false, ...
                'AvailableLabs', [1 2], ...
                'ResourceTypes', resourceSnapshot);

            prepared = conduction.scheduling.SchedulingPreprocessor.prepareDataset(casesStruct, options);
            model = conduction.scheduling.OptimizationModelBuilder.build(prepared, options);
            [solution, solverInfo] = conduction.scheduling.OptimizationSolver.solve(model, options);

            % Force diagnostics to treat capacity as 1 even though model allowed 2
            prepared.resourceCapacities(:) = 1;
            [~, outcome] = conduction.scheduling.ScheduleAssembler.assemble(prepared, model, solution, solverInfo, options);

            testCase.verifyNotEmpty(outcome.ResourceViolations, ...
                'Diagnostics should flag overlap when effective capacity is reduced.');
            violation = outcome.ResourceViolations(1);
            testCase.verifyEqual(violation.ResourceId, resourceType.Id);
            testCase.verifyLessThan(violation.StartTime, violation.EndTime);

            labs = outcome.scheduleStruct.labs;
            scheduledCases = [labs{:}];
            testCase.verifyEqual(numel(scheduledCases), 2);
            [~, order] = sort([scheduledCases.procStartTime]);
            orderedCases = scheduledCases(order);
            overlap = orderedCases(1).procStartTime < orderedCases(2).procEndTime && ...
                orderedCases(2).procStartTime < orderedCases(1).procEndTime;
            testCase.verifyTrue(overlap, 'Test precondition: cases should overlap when capacity=2.');
        end
    end
end

function deleteIfValid(handleObj)
%DELETEIFVALID Safely delete handle objects created in tests.
    if isempty(handleObj)
        return;
    end
    try
        if isvalid(handleObj)
            delete(handleObj);
        end
    catch
        % Ignore best-effort deletion errors.
    end
end
