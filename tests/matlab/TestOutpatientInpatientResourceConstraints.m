classdef TestOutpatientInpatientResourceConstraints < matlab.unittest.TestCase
    %TESTOUTPATIENTINPATIENTRESOURCECONSTRAINTS Unit tests for core outpatient/inpatient components
    %
    % Layer 1: Unit Tests - Core Components (10 tests)
    % Tests individual helper methods in HistoricalScheduler

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            scriptsPath = fullfile(rootDir, 'scripts');
            testCase.applyFixture(PathFixture(scriptsPath));

            % Add helpers directory
            helpersPath = fullfile(rootDir, 'tests', 'matlab', 'helpers');
            if exist(helpersPath, 'dir')
                testCase.applyFixture(PathFixture(helpersPath));
            end
        end
    end

    %% Test Group A: Locked Case Conversion (3 tests)
    methods (Test)
        function testConvertScheduleToLockedConstraints_BasicConversion(testCase)
            % Purpose: Verify phase 1 schedule converts to locked constraints correctly

            % Create test cases
            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            % Add 3 outpatient cases
            for i = 1:3
                caseManager.addCase(sprintf('Dr. Test%d', i), 'Test Procedure');
                caseObj = caseManager.getCase(i);
                caseObj.AdmissionStatus = 'outpatient';
            end

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [cases, ~] = caseManager.buildOptimizationCases(1:3, defaults);

            % Create mock schedule struct
            scheduleStruct = struct();
            scheduleStruct.labs = cell(2, 1);
            scheduleStruct.labs{1} = struct(...
                'caseID', {cases(1).caseID, cases(2).caseID}, ...
                'startTime', {480, 540}, ...
                'procStartTime', {480, 540}, ...
                'procEndTime', {540, 600});
            scheduleStruct.labs{2} = struct(...
                'caseID', {cases(3).caseID}, ...
                'startTime', {480}, ...
                'procStartTime', {480}, ...
                'procEndTime', {540});

            % Create scheduler and test conversion
            options = conduction.scheduling.SchedulingOptions();
            scheduler = conduction.scheduling.HistoricalScheduler(options);

            % Use private method (requires access)
            locked = scheduler.convertScheduleToLockedConstraints(scheduleStruct, cases, struct([]));

            % Verify
            testCase.verifyEqual(numel(locked), 3, 'Should have 3 locked constraints');
            testCase.verifyTrue(all(isfield(locked, 'caseID')), 'All constraints should have caseID');
            testCase.verifyTrue(all(isfield(locked, 'startTime')), 'All constraints should have startTime');
            testCase.verifyTrue(all(isfield(locked, 'assignedLab')), 'All constraints should have assignedLab');
        end

        function testConvertScheduleToLockedConstraints_PreservesExistingLocks(testCase)
            % Purpose: Ensure existing locked cases aren't lost

            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            caseManager.addCase('Dr. Test', 'Test Procedure');
            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [cases, ~] = caseManager.buildOptimizationCases(1, defaults);

            % Create schedule with 1 case
            scheduleStruct = struct();
            scheduleStruct.labs = {struct('caseID', cases(1).caseID, 'startTime', 480, 'assignedLab', 1)};

            % Create existing locked constraints with all required fields
            existingLocked = struct('caseID', 'EXISTING-1', 'startTime', 600, 'assignedLab', 2, 'requiredResourceIds', {{}});

            options = conduction.scheduling.SchedulingOptions();
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            locked = scheduler.convertScheduleToLockedConstraints(scheduleStruct, cases, existingLocked);

            % Verify both old and new locks present
            testCase.verifyEqual(numel(locked), 2, 'Should have 2 locked constraints total');
            caseIds = {locked.caseID};
            testCase.verifyTrue(any(strcmp(caseIds, 'EXISTING-1')), 'Existing lock should be preserved');
        end

        function testConvertScheduleToLockedConstraints_EmptySchedule(testCase)
            % Purpose: Handle edge case gracefully

            scheduleStruct = struct();
            scheduleStruct.labs = cell(2, 1);

            options = conduction.scheduling.SchedulingOptions();
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            locked = scheduler.convertScheduleToLockedConstraints(scheduleStruct, struct([]), struct([]));

            testCase.verifyEmpty(locked, 'Empty schedule should return empty array');
        end
    end

    %% Test Group B: Resource Violation Detection (4 tests)
    methods (Test)
        function testDetectResourceViolations_NoViolation(testCase)
            % Purpose: Verify clean schedules pass

            % Create sequential cases (no overlap)
            scheduleStruct = struct();
            scheduleStruct.labs = {[
                struct('caseID', 'CASE-1', 'procStartTime', 480, 'procEndTime', 540, 'requiredResourceIds', {{'RES-1'}}), ...
                struct('caseID', 'CASE-2', 'procStartTime', 540, 'procEndTime', 600, 'requiredResourceIds', {{'RES-1'}})
            ]};

            resourceTypes = struct('Id', 'RES-1', 'Name', 'TestResource', 'Capacity', 1, 'Color', [0.5 0.5 0.5]);

            options = conduction.scheduling.SchedulingOptions.fromArgs('ResourceTypes', resourceTypes);
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            violations = scheduler.detectResourceViolations(scheduleStruct, resourceTypes);

            testCase.verifyEmpty(violations, 'Sequential cases should not violate capacity');
        end

        function testDetectResourceViolations_SimpleOverlap(testCase)
            % Purpose: Detect basic overlap

            % Create overlapping cases
            scheduleStruct = struct();
            scheduleStruct.labs = {[
                struct('caseID', 'CASE-1', 'procStartTime', 480, 'procEndTime', 600, 'requiredResourceIds', {{'RES-1'}}), ...
                struct('caseID', 'CASE-2', 'procStartTime', 540, 'procEndTime', 630, 'requiredResourceIds', {{'RES-1'}})
            ]};

            resourceTypes = struct('Id', 'RES-1', 'Name', 'TestResource', 'Capacity', 1, 'Color', [0.5 0.5 0.5]);

            options = conduction.scheduling.SchedulingOptions.fromArgs('ResourceTypes', resourceTypes);
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            violations = scheduler.detectResourceViolations(scheduleStruct, resourceTypes);

            testCase.verifyNotEmpty(violations, 'Overlapping cases should violate capacity=1');
            testCase.verifyEqual(violations(1).ResourceId, "RES-1");
            testCase.verifyEqual(violations(1).Capacity, 1);
            testCase.verifyEqual(violations(1).ActualUsage, 2);
            testCase.verifyEqual(numel(violations(1).CaseIds), 2);
        end

        function testDetectResourceViolations_MultipleResources(testCase)
            % Purpose: Independent resource tracking

            scheduleStruct = struct();
            scheduleStruct.labs = {[
                struct('caseID', 'CASE-1', 'procStartTime', 480, 'procEndTime', 600, 'requiredResourceIds', {{'RES-A'}}), ...
                struct('caseID', 'CASE-2', 'procStartTime', 540, 'procEndTime', 630, 'requiredResourceIds', {{'RES-A'}}), ...
                struct('caseID', 'CASE-3', 'procStartTime', 480, 'procEndTime', 600, 'requiredResourceIds', {{'RES-B'}}), ...
                struct('caseID', 'CASE-4', 'procStartTime', 540, 'procEndTime', 630, 'requiredResourceIds', {{'RES-B'}})
            ]};

            resourceTypes = [
                struct('Id', 'RES-A', 'Name', 'ResourceA', 'Capacity', 1, 'Color', [0.5 0.5 0.5]), ...
                struct('Id', 'RES-B', 'Name', 'ResourceB', 'Capacity', 2, 'Color', [0.5 0.5 0.5])
            ];

            options = conduction.scheduling.SchedulingOptions.fromArgs('ResourceTypes', resourceTypes);
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            violations = scheduler.detectResourceViolations(scheduleStruct, resourceTypes);

            % Only Resource A should have violation (capacity=1, 2 cases overlap)
            testCase.verifyNotEmpty(violations, 'Should detect violation for Resource A');
            violationIds = string({violations.ResourceId});
            testCase.verifyTrue(any(violationIds == "RES-A"), 'Resource A should have violation');
            testCase.verifyFalse(any(violationIds == "RES-B"), 'Resource B should not have violation (capacity=2)');
        end

        function testDetectResourceViolations_ExactCapacityNoViolation(testCase)
            % Purpose: Boundary condition

            scheduleStruct = struct();
            scheduleStruct.labs = {[
                struct('caseID', 'CASE-1', 'procStartTime', 480, 'procEndTime', 600, 'requiredResourceIds', {{'RES-1'}}), ...
                struct('caseID', 'CASE-2', 'procStartTime', 540, 'procEndTime', 630, 'requiredResourceIds', {{'RES-1'}})
            ]};

            resourceTypes = struct('Id', 'RES-1', 'Name', 'TestResource', 'Capacity', 2, 'Color', [0.5 0.5 0.5]);

            options = conduction.scheduling.SchedulingOptions.fromArgs('ResourceTypes', resourceTypes);
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            violations = scheduler.detectResourceViolations(scheduleStruct, resourceTypes);

            testCase.verifyEmpty(violations, 'Capacity=2 should allow 2 overlapping cases');
        end
    end

    %% Test Group C: Fallback Decision Logic (3 tests)
    methods (Test)
        function testShouldFallback_InfeasiblePhase2(testCase)
            % Purpose: Trigger fallback on solver failure

            phase2Outcome = struct('exitflag', -1);
            combinedSchedule = struct('labs', {cell(1,1)});

            options = conduction.scheduling.SchedulingOptions();
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            needsFallback = scheduler.shouldFallback(phase2Outcome, combinedSchedule);

            testCase.verifyTrue(needsFallback, 'Should fallback when exitflag < 1');
        end

        function testShouldFallback_ResourceViolations(testCase)
            % Purpose: Trigger fallback on violations

            % Create schedule with violation
            scheduleStruct = struct();
            scheduleStruct.labs = {[
                struct('caseID', 'CASE-1', 'procStartTime', 480, 'procEndTime', 600, 'requiredResourceIds', {{'RES-1'}}), ...
                struct('caseID', 'CASE-2', 'procStartTime', 540, 'procEndTime', 630, 'requiredResourceIds', {{'RES-1'}})
            ]};

            resourceTypes = struct('Id', 'RES-1', 'Name', 'TestResource', 'Capacity', 1, 'Color', [0.5 0.5 0.5]);
            phase2Outcome = struct('exitflag', 1);

            options = conduction.scheduling.SchedulingOptions.fromArgs('ResourceTypes', resourceTypes);
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            needsFallback = scheduler.shouldFallback(phase2Outcome, scheduleStruct);

            testCase.verifyTrue(needsFallback, 'Should fallback when violations detected');
        end

        function testShouldFallback_Success(testCase)
            % Purpose: No fallback when successful

            scheduleStruct = struct();
            scheduleStruct.labs = {[
                struct('caseID', 'CASE-1', 'procStartTime', 480, 'procEndTime', 540, 'requiredResourceIds', {{'RES-1'}})
            ]};

            resourceTypes = struct('Id', 'RES-1', 'Name', 'TestResource', 'Capacity', 1, 'Color', [0.5 0.5 0.5]);
            phase2Outcome = struct('exitflag', 1);

            options = conduction.scheduling.SchedulingOptions.fromArgs('ResourceTypes', resourceTypes);
            scheduler = conduction.scheduling.HistoricalScheduler(options);
            needsFallback = scheduler.shouldFallback(phase2Outcome, scheduleStruct);

            testCase.verifyFalse(needsFallback, 'Should not fallback when successful');
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
