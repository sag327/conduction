classdef testFirstCaseConflictDetection < matlab.unittest.TestCase
    %TESTFIRSTCASECONFLICTDETECTION Unit tests for first case conflict detection and error messages

    methods (Test)
        function testTooManyFirstCases(testCase)
            % Test: 10 first cases, 6 labs -> conflicts detected
            lockedConstraints = testCase.createFirstCaseLocks(1:10, 6);

            [hasConflicts, conflictReport] = conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);

            testCase.verifyTrue(hasConflicts, 'Should detect conflicts with 10 first cases and 6 labs');
            testCase.verifyTrue(contains(conflictReport.message, 'First Case'), 'Error should mention first case');
            testCase.verifyTrue(contains(conflictReport.message, '10 cases'), 'Error should mention 10 cases');
        end

        function testFirstCaseConflictWithExistingLock(testCase)
            % Test: First case conflicts with existing locked case at 08:00
            % Add existing locked case at Lab 1, 08:00
            existingLock = testCase.createLockAt(1, 480, 'existing_case');
            lockedConstraints = existingLock;

            % Add first case also at Lab 1, 08:00
            firstCaseLock = testCase.createLockAt(1, 480, 'first_case_001');
            lockedConstraints(2) = firstCaseLock;

            [hasConflicts, conflictReport] = conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);

            testCase.verifyTrue(hasConflicts, 'Should detect conflict between first case and existing lock');
            testCase.verifyTrue(contains(conflictReport.message, 'First Case'), 'Error should identify as first case conflict');
            testCase.verifyTrue(contains(conflictReport.message, 'Lab 1'), 'Error should mention Lab 1');
            testCase.verifyTrue(contains(conflictReport.message, '08:00'), 'Error should mention 08:00');
        end

        function testErrorMessageIncludesResolutionSteps(testCase)
            % Test: Error message includes actionable resolution steps
            lockedConstraints = testCase.createFirstCaseLocks(1:10, 6);

            [hasConflicts, conflictReport] = conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);

            testCase.verifyTrue(hasConflicts, 'Should have conflicts');
            testCase.verifyTrue(contains(conflictReport.message, 'To resolve:'), 'Should include resolution section');
            testCase.verifyTrue(contains(conflictReport.message, 'Remove "First Case" constraint'), 'Should suggest removing constraint');
        end

        function testMultipleLabsWithConflicts(testCase)
            % Test: Multiple labs have conflicts, error lists them
            % Lab 1: 2 first cases
            lockedConstraints = testCase.createLockAt(1, 480, 'case_001');
            lockedConstraints(2) = testCase.createLockAt(1, 480, 'case_002');

            % Lab 3: 2 first cases
            lockedConstraints(3) = testCase.createLockAt(3, 480, 'case_003');
            lockedConstraints(4) = testCase.createLockAt(3, 480, 'case_004');

            [hasConflicts, conflictReport] = conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);

            testCase.verifyTrue(hasConflicts, 'Should detect conflicts in multiple labs');
            testCase.verifyTrue(contains(conflictReport.message, 'Labs'), 'Should mention labs');
            % Should mention both Lab 1 and Lab 3 in conflicts
            testCase.verifyTrue(contains(conflictReport.message, 'Lab 1'), 'Should mention Lab 1');
            testCase.verifyTrue(contains(conflictReport.message, 'Lab 3'), 'Should mention Lab 3');
        end

        function testAnalyzeFirstCaseConflicts(testCase)
            % Test: analyzeFirstCaseConflicts helper method
            lockedConstraints = testCase.createFirstCaseLocks(1:7, 6);

            analysis = conduction.scheduling.LockedCaseConflictValidator.analyzeFirstCaseConflicts(lockedConstraints);

            testCase.verifyTrue(analysis.hasFirstCaseConflicts, 'Should detect first case conflicts');
            testCase.verifyEqual(analysis.totalFirstCases, 7, 'Should count 7 first cases');
            testCase.verifyEqual(analysis.totalLabs, 6, 'Should detect 6 labs');
        end

        function testNonFirstCaseConflictMessage(testCase)
            % Test: Non-first-case conflicts still get generic message
            % Create conflicts at 10:00, not at lab start time
            lockedConstraints = testCase.createLockAt(1, 600, 'case_001');  % 10:00
            lockedConstraints(2) = testCase.createLockAt(1, 600, 'case_002');  % 10:00

            [hasConflicts, conflictReport] = conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);

            testCase.verifyTrue(hasConflicts, 'Should detect conflicts');
            testCase.verifyTrue(contains(conflictReport.message, 'impossible conflicts'), 'Should use generic conflict message');
            % Should NOT have first case specific message
            testCase.verifyFalse(contains(conflictReport.message, 'First Case constraints'), 'Should not mention first case constraints');
        end
    end

    methods (Static)
        function locks = createFirstCaseLocks(caseIndices, totalLabs)
            % Helper: Create locked constraints for first cases
            % Distributes cases round-robin across labs, wrapping when exceeding totalLabs

            numCases = numel(caseIndices);
            locks = struct('caseID', {}, 'operator', {}, 'caseNumber', {}, ...
                          'startTime', {}, 'procStartTime', {}, 'procEndTime', {}, ...
                          'endTime', {}, 'assignedLab', {}, 'requiredResourceIds', {});

            for i = 1:numCases
                caseIdx = caseIndices(i);
                labIdx = mod(i-1, totalLabs) + 1;  % Round-robin

                locks(i).caseID = sprintf('case_%03d', caseIdx);
                locks(i).operator = 'Dr. Smith';
                locks(i).caseNumber = caseIdx;
                locks(i).startTime = 480;  % 08:00
                locks(i).procStartTime = 495;  % 08:15 (480 + 15 setup)
                locks(i).procEndTime = 555;  % 09:15 (495 + 60 proc)
                locks(i).endTime = 585;  % 09:45 (555 + 10 post + 20 turnover)
                locks(i).assignedLab = labIdx;
                locks(i).requiredResourceIds = {};
            end
        end

        function lock = createLockAt(labIdx, startTimeMinutes, caseId)
            % Helper: Create a single locked constraint at specified time
            lock = struct();
            lock.caseID = caseId;
            lock.operator = 'Dr. Jones';
            lock.caseNumber = NaN;
            lock.startTime = startTimeMinutes;
            lock.procStartTime = startTimeMinutes + 15;
            lock.procEndTime = startTimeMinutes + 75;  % 60 min procedure
            lock.endTime = startTimeMinutes + 105;  % + 10 post + 20 turnover
            lock.assignedLab = labIdx;
            lock.requiredResourceIds = {};
        end
    end
end
