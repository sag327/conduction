classdef TestLockedCaseConstraints < matlab.unittest.TestCase
    %TESTLOCKEDCASECONSTRAINTS Validate handling of locked-case feasibility scenarios.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            scriptsPath = fullfile(rootDir, 'scripts');
            testCase.applyFixture(PathFixture(scriptsPath));
        end
    end

    methods (Test)
        function testInvalidLockedStartThrowsInformativeError(testCase)
            targetDate = datetime('2025-02-01');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanupManager = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            caseManager.addCase("Dr. Stone", "Ablation");

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [casesStruct, ~] = caseManager.buildOptimizationCases(1, defaults);

            % Locking to 7:30 AM (< lab start) should be infeasible
            lockedConstraint = struct( ...
                'caseID', casesStruct(1).caseID, ...
                'startTime', 450, ...
                'assignedLab', 1);

            options = conduction.scheduling.SchedulingOptions.fromArgs( ...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'CaseFilter', 'all', ...
                'MaxOperatorTime', 480, ...
                'TurnoverTime', 0, ...
                'EnforceMidnight', true, ...
                'PrioritizeOutpatient', false, ...
                'AvailableLabs', 1, ...
                'LockedCaseConstraints', lockedConstraint, ...
                'Verbose', false);

            prepared = conduction.scheduling.SchedulingPreprocessor.prepareDataset(casesStruct, options);

            testCase.verifyError(@() conduction.scheduling.OptimizationModelBuilder.build(prepared, options), ...
                'OptimizationModelBuilder:InvalidLockedConstraint');
        end

        function testValidLockedStartRunsSuccessfully(testCase)
            targetDate = datetime('2025-02-02');
            caseManager = conduction.gui.controllers.CaseManager(targetDate);
            cleanupManager = onCleanup(@() deleteIfValid(caseManager)); %#ok<NASGU>

            caseManager.addCase("Dr. Li", "Device Implant");

            defaults = struct('SetupMinutes', 0, 'PostMinutes', 0, 'TurnoverMinutes', 0, 'AdmissionStatus', 'outpatient');
            [casesStruct, ~] = caseManager.buildOptimizationCases(1, defaults);

            % Lock exactly to lab start (8:00 AM)
            lockedConstraint = struct( ...
                'caseID', casesStruct(1).caseID, ...
                'startTime', 480, ...
                'assignedLab', 1);

            options = conduction.scheduling.SchedulingOptions.fromArgs( ...
                'NumLabs', 1, ...
                'LabStartTimes', {'08:00'}, ...
                'OptimizationMetric', 'makespan', ...
                'CaseFilter', 'all', ...
                'MaxOperatorTime', 480, ...
                'TurnoverTime', 0, ...
                'EnforceMidnight', true, ...
                'PrioritizeOutpatient', false, ...
                'AvailableLabs', 1, ...
                'LockedCaseConstraints', lockedConstraint, ...
                'Verbose', false);

            [dailySchedule, outcome] = conduction.scheduling.HistoricalScheduler.runPhase(casesStruct, options);

            testCase.verifyGreaterThanOrEqual(outcome.exitflag, 1, 'Expected feasible solution for valid lock.');
            labs = outcome.scheduleStruct.labs;
            scheduledCases = [labs{:}];
            testCase.verifyEqual(numel(scheduledCases), 1, 'Exactly one case should be scheduled.');
            testCase.verifyEqual(scheduledCases(1).startTime, 480, 'Locked start time should be honored.');
            testCase.verifyClass(dailySchedule, 'conduction.DailySchedule');
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
