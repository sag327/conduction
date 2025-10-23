classdef TestRegressionPerformanceDiagnostics < matlab.unittest.TestCase
    %TESTREGRESSIONPERFORMANCEDIAGNOSTICS Final test layers for comprehensive coverage
    %
    % Layer 4: Regression Tests (5 tests) - Ensure backward compatibility
    % Layer 5: Performance Tests (3 tests) - Verify scalability
    % Layer 6: Diagnostic Tests (5 tests) - Test reporting accuracy

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

    %% Layer 4: Regression Tests (5 tests)
    methods (Test, TestTags = {'Regression'})
        function testLegacyPrioritizeOutpatientStillWorks(testCase)
            % Purpose: Verify old PrioritizeOutpatient=true still works

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            % Use legacy flag instead of OutpatientInpatientMode
            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'PrioritizeOutpatient', true);  % Legacy mode

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'Legacy mode should still work');
            testCase.verifyGreaterThanOrEqual(outcome.exitflag(1), 1, 'Should succeed');
        end

        function testNoResourceTypes_StillOptimizes(testCase)
            % Purpose: Verify scheduling works without resource constraints (legacy behavior)

            [outpatients, inpatients, ~] = createResourceConflictScenario(2, 2, 1, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');
                % No ResourceTypes specified

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'Should work without resources');
        end

        function testSinglePhase_NoModeSpecified(testCase)
            % Purpose: Default behavior when OutpatientInpatientMode not set

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'PrioritizeOutpatient', false);  % Single-phase by default

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'Default behavior should work');
        end

        function testCaseFilterAll_BothTypes(testCase)
            % Purpose: CaseFilter='all' includes both outpatients and inpatients

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'CaseFilter', 'all', ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, outcome] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 4, 'CaseFilter=all should include both types');
        end

        function testCaseFilterInpatient_OnlyInpatients(testCase)
            % Purpose: CaseFilter='inpatient' should skip two-phase

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'CaseFilter', 'inpatient', ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [dailySchedule, ~] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];

            % Should only schedule inpatients
            inpatientCount = sum(arrayfun(@(c) strcmpi(c.admissionStatus, 'inpatient'), allScheduledCases));
            testCase.verifyEqual(inpatientCount, numel(allScheduledCases), ...
                'CaseFilter=inpatient should only schedule inpatients');
        end
    end

    %% Layer 5: Performance Tests (3 tests)
    methods (Test, TestTags = {'Performance'})
        function testScalability_10Cases(testCase)
            % Purpose: Reasonable performance with 10 cases

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(5, 5, 3, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 3, ...
                'LabStartTimes', {'08:00', '08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);

            tic;
            [dailySchedule, outcome] = scheduler.schedule(allCases);
            elapsed = toc;

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 10, 'All 10 cases should be scheduled');
            testCase.verifyLessThan(elapsed, 30, 'Should complete in under 30 seconds');
        end

        function testScalability_MultipleResources(testCase)
            % Purpose: Handle multiple resource types efficiently

            targetDate = datetime('2025-01-15');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanup = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            store = caseManager.getResourceStore();
            res1 = store.create("Resource1", 2);
            res2 = store.create("Resource2", 2);
            res3 = store.create("Resource3", 2);

            % Create 6 cases using different resources
            for i = 1:6
                caseManager.addCase(sprintf('Dr. Test%d', i), 'Procedure');
                caseManager.getCase(i).EstimatedDurationMinutes = 60;

                % Distribute across resources
                if mod(i, 3) == 1
                    caseManager.getCase(i).assignResource(res1.Id);
                elseif mod(i, 3) == 2
                    caseManager.getCase(i).assignResource(res2.Id);
                else
                    caseManager.getCase(i).assignResource(res3.Id);
                end

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
            [dailySchedule, ~] = scheduler.schedule(allCases);

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 6, 'Should handle multiple resources');
        end

        function testFallback_PerformanceAcceptable(testCase)
            % Purpose: Fallback doesn't cause excessive slowdown

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(4, 4, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);

            tic;
            [dailySchedule, ~] = scheduler.schedule(allCases);
            elapsed = toc;

            labAssignments = dailySchedule.labAssignments();
            allScheduledCases = [labAssignments{:}];
            testCase.verifyEqual(numel(allScheduledCases), 8, 'All cases should be scheduled');
            testCase.verifyLessThan(elapsed, 60, 'Fallback should complete in under 60 seconds');
        end
    end

    %% Layer 6: Diagnostic Tests (5 tests)
    methods (Test, TestTags = {'Diagnostic'})
        function testOutcome_ContainsPhase1Info(testCase)
            % Purpose: Verify outcome struct has phase 1 data

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [~, outcome] = scheduler.schedule(allCases);

            testCase.verifyTrue(isfield(outcome, 'phase1'), 'Outcome should contain phase1 data');
            testCase.verifyTrue(isstruct(outcome.phase1), 'phase1 should be a struct');
        end

        function testOutcome_ContainsPhase2Info(testCase)
            % Purpose: Verify outcome struct has phase 2 data

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseStrict');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [~, outcome] = scheduler.schedule(allCases);

            testCase.verifyTrue(isfield(outcome, 'phase2'), 'Outcome should contain phase2 data');
            testCase.verifyTrue(isstruct(outcome.phase2), 'phase2 should be a struct');
        end

        function testOutcome_ExitFlagsPresent(testCase)
            % Purpose: Verify exitflag array exists

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [~, outcome] = scheduler.schedule(allCases);

            testCase.verifyTrue(isfield(outcome, 'exitflag'), 'Outcome should contain exitflag');
            testCase.verifyGreaterThan(numel(outcome.exitflag), 0, 'exitflag should not be empty');
        end

        function testOutcome_ObjectiveValue(testCase)
            % Purpose: Verify objective value is present and numeric

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [~, outcome] = scheduler.schedule(allCases);

            testCase.verifyTrue(isfield(outcome, 'objectiveValue'), 'Outcome should contain objectiveValue');
            testCase.verifyTrue(isnumeric(outcome.objectiveValue), 'objectiveValue should be numeric');
        end

        function testDiagnostic_FallbackFlag(testCase)
            % Purpose: Verify usedFallback flag is boolean when present

            [outpatients, inpatients, resourceTypes] = createResourceConflictScenario(2, 2, 2, 60);
            allCases = [outpatients, inpatients];

            options = conduction.scheduling.SchedulingOptions.fromArgs(...
                'NumLabs', 2, ...
                'LabStartTimes', {'08:00', '08:00'}, ...
                'ResourceTypes', resourceTypes, ...
                'OutpatientInpatientMode', 'TwoPhaseAutoFallback');

            scheduler = conduction.scheduling.HistoricalScheduler(options);
            [~, outcome] = scheduler.schedule(allCases);

            if isfield(outcome, 'usedFallback')
                testCase.verifyTrue(islogical(outcome.usedFallback) || isnumeric(outcome.usedFallback), ...
                    'usedFallback should be boolean or numeric');
            end
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
