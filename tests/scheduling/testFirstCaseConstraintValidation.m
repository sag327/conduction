classdef testFirstCaseConstraintValidation < matlab.unittest.TestCase
    %TESTFIRSTCASECONSTRAINTVALIDATION Unit tests for first case constraint validation

    methods (Test)
        function testFewFirstCases(testCase)
            % Test: 2 first cases, 6 labs -> should pass
            cases = testCase.createMockCases([1 1 0 0 0 0]);  % 2 first cases
            numLabs = 6;

            [isImpossible, warningMsg, adjustedCases] = ...
                conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(cases, numLabs);

            testCase.verifyFalse(isImpossible, 'Should not be impossible with 2 first cases and 6 labs');
            testCase.verifyEmpty(warningMsg, 'Should not have warning message');
            testCase.verifyEqual(length(adjustedCases), length(cases), 'Should return same number of cases');
            testCase.verifyEqual([adjustedCases.priority], [1 1 0 0 0 0], 'Priorities should be unchanged');
        end

        function testExactlyEnoughLabs(testCase)
            % Test: 6 first cases, 6 labs -> should pass
            cases = testCase.createMockCases([1 1 1 1 1 1]);  % 6 first cases
            numLabs = 6;

            [isImpossible, warningMsg, adjustedCases] = ...
                conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(cases, numLabs);

            testCase.verifyFalse(isImpossible, 'Should not be impossible with 6 first cases and 6 labs');
            testCase.verifyEmpty(warningMsg, 'Should not have warning message');
            testCase.verifyEqual([adjustedCases.priority], [1 1 1 1 1 1], 'All priorities should remain 1');
        end

        function testTooManyFirstCases(testCase)
            % Test: 10 first cases, 6 labs -> should warn and demote 4 cases
            cases = testCase.createMockCases([1 1 1 1 1 1 1 1 1 1]);  % 10 first cases
            numLabs = 6;

            [isImpossible, warningMsg, adjustedCases] = ...
                conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(cases, numLabs);

            testCase.verifyTrue(isImpossible, 'Should be impossible with 10 first cases and 6 labs');
            testCase.verifyNotEmpty(warningMsg, 'Should have warning message');
            testCase.verifySubstring(warningMsg, '10 cases', 'Warning should mention 10 cases');
            testCase.verifySubstring(warningMsg, '6 labs', 'Warning should mention 6 labs');

            % Verify first 6 cases remain priority 1, last 4 become priority 0
            expectedPriorities = [1 1 1 1 1 1 0 0 0 0];
            testCase.verifyEqual([adjustedCases.priority], expectedPriorities, ...
                'First 6 should be priority 1, remaining 4 should be demoted to 0');
        end

        function testNoFirstCases(testCase)
            % Test: 0 first cases -> should pass
            cases = testCase.createMockCases([0 0 0 0]);  % No first cases
            numLabs = 6;

            [isImpossible, warningMsg, adjustedCases] = ...
                conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(cases, numLabs);

            testCase.verifyFalse(isImpossible, 'Should not be impossible with no first cases');
            testCase.verifyEmpty(warningMsg, 'Should not have warning message');
            testCase.verifyEqual([adjustedCases.priority], [0 0 0 0], 'Priorities should remain 0');
        end

        function testEmptyCases(testCase)
            % Test: Empty case array -> should pass
            cases = struct('caseID', {}, 'priority', {});
            numLabs = 6;

            [isImpossible, warningMsg, adjustedCases] = ...
                conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(cases, numLabs);

            testCase.verifyFalse(isImpossible, 'Should not be impossible with empty cases');
            testCase.verifyEmpty(warningMsg, 'Should not have warning message');
            testCase.verifyEmpty(adjustedCases, 'Should return empty array');
        end

        function testExcessByOne(testCase)
            % Test: 7 first cases, 6 labs -> should demote exactly 1
            cases = testCase.createMockCases([1 1 1 1 1 1 1]);  % 7 first cases
            numLabs = 6;

            [isImpossible, warningMsg, adjustedCases] = ...
                conduction.scheduling.LockedCaseConflictValidator.validateFirstCaseConstraints(cases, numLabs);

            testCase.verifyTrue(isImpossible, 'Should be impossible with 7 first cases and 6 labs');
            testCase.verifyNotEmpty(warningMsg, 'Should have warning message');

            % Verify exactly 1 case demoted
            expectedPriorities = [1 1 1 1 1 1 0];
            testCase.verifyEqual([adjustedCases.priority], expectedPriorities, ...
                'First 6 should be priority 1, last 1 should be demoted');
        end
    end

    methods (Static)
        function cases = createMockCases(priorities)
            % Helper: Create mock case struct array with given priorities
            numCases = length(priorities);
            cases = struct('caseID', {}, 'priority', {}, 'operator', {}, 'procedure', {}, ...
                          'setupTime', {}, 'procTime', {}, 'postTime', {}, 'turnoverTime', {});

            for i = 1:numCases
                cases(i).caseID = sprintf('case_%03d', i);
                cases(i).priority = priorities(i);
                cases(i).operator = 'Dr. Smith';
                cases(i).procedure = 'Test Procedure';
                cases(i).setupTime = 15;
                cases(i).procTime = 60;
                cases(i).postTime = 15;
                cases(i).turnoverTime = 30;
            end
        end
    end
end
