classdef testFirstCaseLockedConversion < matlab.unittest.TestCase
    %TESTFIRSTCASELOCKEDCONVERSION Unit tests for first case to locked constraint conversion

    methods (Test)
        function testBasicConversion(testCase)
            % Test: Single first case -> locked at lab 1, start time 08:00
            cases = testCase.createMockCases([1], {'Dr. Smith'}, [60]);
            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);
            existingLocked = struct([]);

            % Create mock OptimizationController
            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            testCase.verifyEqual(length(lockedConstraints), 1, 'Should create 1 locked constraint');
            testCase.verifyEqual(lockedConstraints(1).caseID, 'case_001', 'Should have correct case ID');
            testCase.verifyEqual(lockedConstraints(1).startTime, 480, 'Should start at 08:00 (480 min)');
            testCase.verifyEqual(lockedConstraints(1).assignedLab, 1, 'Should be assigned to lab 1');
        end

        function testMultipleFirstCases(testCase)
            % Test: 3 first cases, 6 labs -> locked at labs 1,2,3
            cases = testCase.createMockCases([1 1 1], {'Dr. Smith', 'Dr. Jones', 'Dr. Brown'}, [60 45 90]);
            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);
            existingLocked = struct([]);

            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            testCase.verifyEqual(length(lockedConstraints), 3, 'Should create 3 locked constraints');

            % Verify all start at 08:00
            for i = 1:3
                testCase.verifyEqual(lockedConstraints(i).startTime, 480, ...
                    sprintf('Case %d should start at 08:00', i));
            end

            % Verify different labs (round-robin)
            assignedLabs = [lockedConstraints.assignedLab];
            testCase.verifyEqual(assignedLabs, [1 2 3], 'Should be assigned to labs 1, 2, 3');
        end

        function testSpecificLabRespected(testCase)
            % Test: First case with preferredLab=3 -> locked at lab 3
            cases = testCase.createMockCases([1], {'Dr. Smith'}, [60]);
            cases(1).preferredLab = 3;  % Specific lab constraint
            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);
            existingLocked = struct([]);

            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            testCase.verifyEqual(length(lockedConstraints), 1, 'Should create 1 locked constraint');
            testCase.verifyEqual(lockedConstraints(1).assignedLab, 3, 'Should be assigned to lab 3');
            testCase.verifyEqual(lockedConstraints(1).startTime, 480, 'Should start at 08:00');
        end

        function testTimingCalculation(testCase)
            % Test: Verify procStartTime, procEndTime calculated correctly
            cases = testCase.createMockCases([1], {'Dr. Smith'}, [60]);
            cases(1).setupTime = 15;
            cases(1).procTime = 60;
            cases(1).postTime = 10;
            cases(1).turnoverTime = 20;

            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);
            existingLocked = struct([]);

            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            testCase.verifyEqual(lockedConstraints(1).startTime, 480, 'startTime = 08:00 (480 min)');
            testCase.verifyEqual(lockedConstraints(1).procStartTime, 495, 'procStartTime = 08:15 (480+15)');
            testCase.verifyEqual(lockedConstraints(1).procEndTime, 555, 'procEndTime = 09:15 (495+60)');
            testCase.verifyEqual(lockedConstraints(1).endTime, 585, 'endTime = 09:45 (555+10+20)');
        end

        function testNoFirstCases(testCase)
            % Test: Cases with priority=0 -> no locked constraints created
            cases = testCase.createMockCases([0 0 0], {'Dr. Smith', 'Dr. Jones', 'Dr. Brown'}, [60 45 90]);
            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);
            existingLocked = struct([]);

            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            testCase.verifyEmpty(lockedConstraints, 'Should create no locked constraints');
        end

        function testMergeWithExistingLocked(testCase)
            % Test: Merge with existing locked constraints
            cases = testCase.createMockCases([1], {'Dr. Smith'}, [60]);
            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);

            % Create existing locked constraint at lab 3
            existingLocked = struct();
            existingLocked.caseID = 'locked_case';
            existingLocked.operator = 'Dr. Jones';
            existingLocked.startTime = 480;
            existingLocked.procStartTime = 495;
            existingLocked.procEndTime = 555;
            existingLocked.endTime = 585;
            existingLocked.assignedLab = 3;
            existingLocked.requiredResourceIds = {};

            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            testCase.verifyEqual(length(lockedConstraints), 2, 'Should have 2 locked constraints (1 existing + 1 new)');

            % Verify new first case assigned to different lab (lab 3 is occupied)
            newConstraint = [];
            for i = 1:length(lockedConstraints)
                if strcmp(lockedConstraints(i).caseID, 'case_001')
                    newConstraint = lockedConstraints(i);
                    break;
                end
            end

            testCase.verifyNotEmpty(newConstraint, 'Should find new constraint');
            testCase.verifyNotEqual(newConstraint.assignedLab, 3, ...
                'New first case should avoid lab 3 (occupied by existing locked case)');
        end

        function testRoundRobinAssignment(testCase)
            % Test: Multiple first cases distributed round-robin across labs
            cases = testCase.createMockCases([1 1 1 1], {'A', 'B', 'C', 'D'}, [60 60 60 60]);
            numLabs = 6;
            labStartTimes = repmat({'08:00'}, 1, numLabs);
            existingLocked = struct([]);

            controller = conduction.gui.controllers.OptimizationController();
            lockedConstraints = controller.convertFirstCasesToLockedConstraints(...
                cases, numLabs, labStartTimes, existingLocked);

            assignedLabs = [lockedConstraints.assignedLab];
            testCase.verifyEqual(sort(assignedLabs), [1 2 3 4], 'Should assign to labs 1-4 in order');
        end
    end

    methods (Static)
        function cases = createMockCases(priorities, operators, procTimes)
            % Helper: Create mock case struct array
            numCases = length(priorities);
            cases = struct('caseID', {}, 'priority', {}, 'operator', {}, 'procedure', {}, ...
                          'setupTime', {}, 'procTime', {}, 'postTime', {}, 'turnoverTime', {}, ...
                          'preferredLab', {}, 'requiredResourceIds', {});

            for i = 1:numCases
                cases(i).caseID = sprintf('case_%03d', i);
                cases(i).priority = priorities(i);
                cases(i).operator = operators{i};
                cases(i).procedure = 'Test Procedure';
                cases(i).setupTime = 15;
                cases(i).procTime = procTimes(i);
                cases(i).postTime = 10;
                cases(i).turnoverTime = 20;
                cases(i).preferredLab = [];
                cases(i).requiredResourceIds = {};
            end
        end
    end
end
