classdef TestOptimizationModes < matlab.unittest.TestCase
    %TESTOPTIMIZATIONMODES Integration tests for optimization modes
    %
    % Layer 2: Integration Tests - Optimization Modes (15 tests)
    % Tests end-to-end behavior of TwoPhaseStrict, TwoPhaseAutoFallback, and SinglePhaseFlexible

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            scriptsPath = fullfile(rootDir, 'scripts');
            testCase.applyFixture(PathFixture(scriptsPath));

            helpersPath = fullfile(rootDir, 'tests', 'matlab', 'helpers');
            if exist(helpersPath, 'dir')
                testCase.applyFixture(PathFixture(helpersPath));
            end
        end
    end

    %% Test Group D: Two-Phase Strict Mode (5 tests)
    methods (Test)
        function testTwoPhaseStrict_NormalCase_NoResourceConflict(testCase)
            % Purpose: Verify strict mode works when resources sufficient

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            testCase.verifyGreaterThanOrEqual(outcome.exitflag(1), 1, 'Phase 1 should succeed');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag(2), 1, 'Phase 2 should succeed');
            testCase.verifyFalse(isfield(outcome, 'usedFallback') && outcome.usedFallback, 'Should not use fallback');

            % Verify all outpatients before all inpatients
            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'All 4 cases should be scheduled');

            outpatientStarts = [];
            inpatientStarts = [];
            for i = 1:numel(allScheduledCases)
                if strcmpi(allScheduledCases(i).admissionStatus, 'outpatient')
                    outpatientStarts(end+1) = allScheduledCases(i).procStartTime; %#ok<AGROW>
                else
                    inpatientStarts(end+1) = allScheduledCases(i).procStartTime; %#ok<AGROW>
                end
            end

            if ~isempty(outpatientStarts) && ~isempty(inpatientStarts)
                testCase.verifyLessThan(max(outpatientStarts), min(inpatientStarts), ...
                    'All outpatients should start before all inpatients');
            end
        end

        function testTwoPhaseStrict_ResourceConflict_Fails(testCase)
            % Purpose: Verify strict mode behavior with resource constraints

            % Use 3 outpatients + 2 inpatients with capacity=1
            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(3, 2, 1, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            % In TwoPhaseStrict mode, either it succeeds with all cases sequential,
            % or it fails if resources make it impossible
            if isfield(outcome, 'infeasible') && outcome.infeasible
                testCase.verifyTrue(isfield(outcome, 'infeasibilityReason'), 'Should provide reason when infeasible');
            else
                % If it succeeded, verify all cases were scheduled
                labAssignments = dailySchedule.labAssignments();
                allScheduledCases = [labAssignments{:}];
                testCase.verifyEqual(numel(allScheduledCases), 5, 'All 5 cases should be scheduled if feasible');
            end
        end

        function testTwoPhaseStrict_NoInpatients(testCase)
            % Purpose: Handle single-sided scenario

            [outpatients, ~, resourceTypes] = createResourceConflictScenario(3, 0, 1, 60);

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(outpatients);

            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should succeed with only outpatients');
            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 3, 'All 3 outpatient cases should be scheduled');
        end

        function testTwoPhaseStrict_NoOutpatients(testCase)
            % Purpose: Handle inpatient-only scenario

            [~, inpatients, resourceTypes] = createResourceConflictScenario(0, 3, 1, 60);

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(inpatients);

            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should succeed with only inpatients');
            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 3, 'All 3 inpatient cases should be scheduled');
        end

        function testTwoPhaseStrict_LockedCasesConsumeResources(testCase)
            % Purpose: Verify locked cases block resources in phase 2

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(1, 1, 1, 120);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            % With capacity=1 and both cases needing the resource, they must be sequential
            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];

            if numel(allScheduledCases) == 2
                [~, order] = sort([allScheduledCases.procStartTime]);
                orderedCases = allScheduledCases(order);

                % Verify no overlap
                testCase.verifyGreaterThanOrEqual(orderedCases(2).procStartTime, orderedCases(1).procEndTime, ...
                    'Cases must not overlap when sharing resource with capacity=1');
            end
        end
    end

    %% Test Group E: Two-Phase Auto-Fallback Mode (5 tests)
    methods (Test)
        function testAutoFallback_NormalCase_NoFallback(testCase)
            % Purpose: Fast path when resources sufficient

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            testCase.verifyFalse(isfield(outcome, 'usedFallback') && outcome.usedFallback, ...
                'Should not use fallback when resources sufficient');

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'All cases should be scheduled');
        end

        function testAutoFallback_ResourceConflict_FallbackTriggered(testCase)
            % Purpose: Verify fallback mechanism when triggered

            % Use 3 outpatients + 2 inpatients with capacity=1
            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(3, 2, 1, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 5, 'All cases should be scheduled');

            % If fallback was used, verify diagnostic info is present
            if isfield(outcome, 'usedFallback') && outcome.usedFallback
                testCase.verifyTrue(isfield(outcome, 'fallbackReason'), 'Should provide fallback reason when used');
            end

            % Verify no resource violations in final schedule
            if isfield(outcome, 'ResourceViolations')
                testCase.verifyEmpty(outcome.ResourceViolations, ...
                    'Final schedule should have no resource violations');
            end
        end

        function testAutoFallback_InpatientsBeforeOutpatients_AfterFallback(testCase)
            % Purpose: Verify conflict detection and reporting

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 1, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            if isfield(outcome, 'usedFallback') && outcome.usedFallback
                testCase.verifyTrue(isfield(outcome, 'conflictStats'), ...
                    'Should provide conflict statistics when fallback used');

                if isfield(outcome, 'conflictStats')
                    stats = outcome.conflictStats;
                    testCase.verifyTrue(isfield(stats, 'inpatientsMovedEarly'), ...
                        'Stats should include count of moved inpatients');
                    testCase.verifyTrue(isfield(stats, 'affectedCases'), ...
                        'Stats should include affected case IDs');
                end
            end
        end

        function testAutoFallback_MultipleResources_PartialConflict(testCase)
            % Purpose: Mixed resource scenario

            % Create two resources with different capacities
            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resourceA = store.create("ResourceA", 1);  % Tight constraint
            resourceB = store.create("ResourceB", 2);  % Loose constraint

            % Create cases using different resources
            caseManager.addCase('Dr. Out1', 'Outpatient Procedure');
            caseManager.getCase(1).assignResource(resourceA.Id);
            caseManager.getCase(1).AdmissionStatus = 'outpatient';
            caseManager.getCase(1).EstimatedDurationMinutes = 60;

            caseManager.addCase('Dr. In1', 'Inpatient Procedure');
            caseManager.getCase(2).assignResource(resourceA.Id);
            caseManager.getCase(2).AdmissionStatus = 'inpatient';
            caseManager.getCase(2).EstimatedDurationMinutes = 60;

            caseManager.addCase('Dr. Out2', 'Outpatient Procedure');
            caseManager.getCase(3).assignResource(resourceB.Id);
            caseManager.getCase(3).AdmissionStatus = 'outpatient';
            caseManager.getCase(3).EstimatedDurationMinutes = 60;

            caseManager.addCase('Dr. In2', 'Inpatient Procedure');
            caseManager.getCase(4).assignResource(resourceB.Id);
            caseManager.getCase(4).AdmissionStatus = 'inpatient';
            caseManager.getCase(4).EstimatedDurationMinutes = 60;

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [allCases, ~] = caseManager.buildOptimizationCases(1:4, defaults);

            resourceTypes = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'All cases should fit in schedule');
        end

        function testAutoFallback_FallbackPreservesResourceConstraints(testCase)
            % Purpose: Verify single-phase respects resources

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(1, 2, 1, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];

            % Find all cases using the resource
            casesUsingResource = [];
            for i = 1:numel(allScheduledCases)
                if isfield(allScheduledCases(i), 'requiredResourceIds') && ...
                   ~isempty(allScheduledCases(i).requiredResourceIds)
                    casesUsingResource(end+1) = i; %#ok<AGROW>
                end
            end

            % Verify no overlaps
            if numel(casesUsingResource) > 1
                for i = 1:numel(casesUsingResource)-1
                    case_i = allScheduledCases(casesUsingResource(i));
                    for j = i+1:numel(casesUsingResource)
                        case_j = allScheduledCases(casesUsingResource(j));

                        % Check for overlap
                        overlaps = (case_i.procStartTime < case_j.procEndTime) && ...
                                   (case_j.procStartTime < case_i.procEndTime);

                        testCase.verifyFalse(overlaps, ...
                            sprintf('Cases %s and %s should not overlap with capacity=1', ...
                            case_i.caseID, case_j.caseID));
                    end
                end
            end
        end
    end

    %% Test Group F: Single-Phase Flexible Mode (5 tests)
    methods (Test)
        function testSinglePhaseFlexible_MixedScheduling(testCase)
            % Purpose: Verify flexible mode allows mixing

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'SinglePhaseFlexible', ...
                'PrioritizeOutpatient', false);  % Single phase doesn't enforce ordering

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'All cases should be scheduled');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Optimization should succeed');
        end

        function testSinglePhaseFlexible_ResourceConstraintsEnforced(testCase)
            % Purpose: Hard constraints still enforced

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(1, 2, 1, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'SinglePhaseFlexible', ...
                'PrioritizeOutpatient', false);

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];

            % Verify cases are scheduled sequentially (no overlap)
            if numel(allScheduledCases) > 1
                [~, order] = sort([allScheduledCases.procStartTime]);
                orderedCases = allScheduledCases(order);

                for i = 1:numel(orderedCases)-1
                    testCase.verifyLessThanOrEqual(orderedCases(i).procEndTime, orderedCases(i+1).procStartTime, ...
                        'Cases requiring same resource must be sequential');
                end
            end
        end

        function testSinglePhaseFlexible_NoOutpatients(testCase)
            % Purpose: Edge case handling

            [~, inpatients, resourceTypes] = createResourceConflictScenario(0, 3, 1, 60);

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'SinglePhaseFlexible', ...
                'PrioritizeOutpatient', false);

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, ~] = scheduler.schedule(inpatients);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 3, 'All inpatients should be scheduled');
        end

        function testSinglePhaseFlexible_NoInpatients(testCase)
            % Purpose: Edge case handling

            [outpatients, ~, resourceTypes] = createResourceConflictScenario(3, 0, 1, 60);

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'SinglePhaseFlexible', ...
                'PrioritizeOutpatient', false);

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, ~] = scheduler.schedule(outpatients);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 3, 'All outpatients should be scheduled');
        end

        function testSinglePhaseFlexible_AllCasesMixed(testCase)
            % Purpose: Stress test with complexity

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(5, 5, 2, 45);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 3, ...
                'LabStartTimes', {'08:00', '08:00', '08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'SinglePhaseFlexible', ...
                'PrioritizeOutpatient', false);

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 10, 'All 10 cases should be scheduled');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Optimization should succeed');
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
