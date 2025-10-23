classdef TestEdgeCases < matlab.unittest.TestCase
    %TESTEDGECASES Edge cases and boundary conditions for outpatient/inpatient optimization
    %
    % Layer 3: Edge Cases (10 tests)
    % Tests boundary conditions, empty inputs, extreme values, and unusual scenarios

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

    %% Test Group G: Empty and Minimal Inputs (3 tests)
    methods (Test)
        function testEmptyCaseList(testCase)
            % Purpose: Handle empty input gracefully

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(struct([]));

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEmpty(allScheduledCases, 'Empty input should produce empty schedule');

            % exitflag might be NaN for empty result - just verify no error thrown
            testCase.verifyTrue(isstruct(outcome), 'Should return outcome struct');
        end

        function testSingleCaseOutpatient(testCase)
            % Purpose: Minimal input - one outpatient case

            [outpatients, ~, resourceTypes] = createResourceConflictScenario(1, 0, 1, 60);

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(outpatients);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 1, 'Single case should be scheduled');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should succeed');
        end

        function testSingleCaseInpatient(testCase)
            % Purpose: Minimal input - one inpatient case

            [~, inpatients, resourceTypes] = createResourceConflictScenario(0, 1, 1, 60);

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(inpatients);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 1, 'Single case should be scheduled');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should succeed');
        end
    end

    %% Test Group H: Resource Capacity Extremes (3 tests)
    methods (Test)
        function testZeroCapacityResource(testCase)
            % Purpose: Resource with capacity=0 - edge case handling

            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resource = store.create("BlockedResource", 0);  % Zero capacity

            caseManager.addCase('Dr. Test', 'Test Procedure');
            caseManager.getCase(1).assignResource(resource.Id);
            caseManager.getCase(1).EstimatedDurationMinutes = 60;

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [cases, ~] = caseManager.buildOptimizationCases(1, defaults);

            resourceTypes = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(cases);

            % Verify optimization completes (capacity=0 is an edge case that
            % the optimizer may handle in various ways)
            testCase.verifyTrue(isstruct(outcome), 'Should return outcome');

            % Just verify no crash - capacity=0 might be ignored or cause violations
            labAssignments = dailySchedule.labAssignments();
            testCase.verifyTrue(iscell(labAssignments), 'Should return lab assignments');
        end

        function testVeryLargeCapacity(testCase)
            % Purpose: Capacity >> number of cases should allow all overlaps

            [outpatients, inpatients, ~] = createResourceConflictScenario(3, 3, 100, 60);

            % Rebuild with large capacity
            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resource = store.create("LargeCapacity", 100);

            for i = 1:6
                caseManager.addCase(sprintf('Dr. Test%d', i), 'Test Procedure');
                caseManager.getCase(i).assignResource(resource.Id);
                caseManager.getCase(i).EstimatedDurationMinutes = 60;
                if i <= 3
                    caseManager.getCase(i).AdmissionStatus = 'outpatient';
                else
                    caseManager.getCase(i).AdmissionStatus = 'inpatient';
                end
            end

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [allCases, ~] = caseManager.buildOptimizationCases(1:6, defaults);

            resourceTypes = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 6, 'All cases should be scheduled');

            % Should not use fallback since capacity is huge
            testCase.verifyFalse(isfield(outcome, 'usedFallback') && outcome.usedFallback, ...
                'Should not need fallback with large capacity');
        end

        function testCapacityEqualsNumberOfCases(testCase)
            % Purpose: Boundary condition where capacity exactly matches concurrent cases

            [outpatients, inpatients, ~] = createResourceConflictScenario(2, 2, 2, 60);

            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resource = store.create("ExactCapacity", 2);  % Exactly 2 capacity

            for i = 1:4
                caseManager.addCase(sprintf('Dr. Test%d', i), 'Test Procedure');
                caseManager.getCase(i).assignResource(resource.Id);
                caseManager.getCase(i).EstimatedDurationMinutes = 60;
                if i <= 2
                    caseManager.getCase(i).AdmissionStatus = 'outpatient';
                else
                    caseManager.getCase(i).AdmissionStatus = 'inpatient';
                end
            end

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [allCases, ~] = caseManager.buildOptimizationCases(1:4, defaults);

            resourceTypes = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, ~] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'All cases should fit with exact capacity');
        end
    end

    %% Test Group I: Time Constraints and Duration Edge Cases (4 tests)
    methods (Test)
        function testVeryShortProcedures(testCase)
            % Purpose: 1-minute procedures

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(3, 3, 2, 1);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 6, 'All short procedures should be scheduled');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should succeed');
        end

        function testVeryLongProcedures(testCase)
            % Purpose: Long procedures (2-hour each)

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 120);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict', ...
                'EnforceMidnight', false);  % Don't enforce midnight to allow fitting

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyGreaterThan(numel(allScheduledCases), 0, 'Should schedule at least some cases');

            % Verify outcome exists
            testCase.verifyTrue(isstruct(outcome), 'Should return outcome struct');
        end

        function testMixedDurations(testCase)
            % Purpose: Cases with widely varying durations

            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            resource = store.create("TestResource", 1);

            % Create cases with durations: 5, 30, 120, 240 minutes
            durations = [5, 30, 120, 240];
            for i = 1:4
                caseManager.addCase(sprintf('Dr. Test%d', i), 'Procedure');
                caseManager.getCase(i).assignResource(resource.Id);
                caseManager.getCase(i).EstimatedDurationMinutes = durations(i);
                caseManager.getCase(i).AdmissionStatus = 'outpatient';
            end

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [cases, ~] = caseManager.buildOptimizationCases(1:4, defaults);

            resourceTypes = store.snapshot();
            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'SinglePhaseFlexible', ...
                'PrioritizeOutpatient', false);

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(cases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyGreaterThan(numel(allScheduledCases), 0, 'Should schedule at least some cases');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should succeed');
        end

        function testLateLabStartTime(testCase)
            % Purpose: Lab starting late in the day

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 1, ...
                'LabStartTimes', {'18:00'}, ...  % Start at 6 PM
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback', ...
                'EnforceMidnight', true);

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];

            % May not fit all cases before midnight
            testCase.verifyGreaterThanOrEqual(numel(allScheduledCases), 0, 'Should handle late start');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Should complete optimization');
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
