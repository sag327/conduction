classdef TestLockedCaseConflictTolerance < matlab.unittest.TestCase
    %TESTLOCKEDCASECONFLICTTOLERANCE Ensure minor rounding overlaps do not trigger conflicts.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            scriptsPath = fullfile(rootDir, 'scripts');
            testCase.applyFixture(PathFixture(scriptsPath));
        end
    end

    methods (Test)
        function testOneMinuteOverlapIgnored(testCase)
            case1 = createConstraint('caseA', 'Dr. Alpha', 1, 480, 480, 590, 600);
            case2 = createConstraint('caseB', 'Dr. Alpha', 1, 599, 599, 680, 690);

            constraints = [case1, case2];
            [hasConflicts, report] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints);

            testCase.verifyFalse(hasConflicts, "Expected 1-minute rounding overlap to be tolerated");
            testCase.verifyEmpty(report.operatorConflicts);
            testCase.verifyEmpty(report.labConflicts);
        end

        function testLongerOverlapStillDetected(testCase)
            case1 = createConstraint('caseA', 'Dr. Alpha', 1, 480, 480, 590, 600);
            case2 = createConstraint('caseB', 'Dr. Alpha', 1, 598, 598, 680, 690);

            constraints = [case1, case2];
            [hasConflicts, report] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints);

            testCase.verifyTrue(hasConflicts, 'Expected extended overlap to be detected');
            testCase.verifyNotEmpty(report.labConflicts);
        end
    end
end

function constraint = createConstraint(caseId, operatorName, labIdx, startTime, procStart, procEnd, endTime)
    constraint = struct();
    constraint.caseID = caseId;
    constraint.caseNumber = NaN;
    constraint.operator = operatorName;
    constraint.assignedLab = labIdx;
    constraint.startTime = startTime;
    constraint.procStartTime = procStart;
    constraint.procEndTime = procEnd;
    constraint.endTime = endTime;
end
