function test_locked_case_conflict_detection()
    %TEST_LOCKED_CASE_CONFLICT_DETECTION Test the LockedCaseConflictValidator
    %   Tests operator and lab conflict detection with various scenarios

    fprintf('\n=== Testing Locked Case Conflict Detection ===\n\n');

    timeStep = 10;  % minutes

    % Test 1: No conflicts (different operators, different labs, different times)
    fprintf('Test 1: No conflicts (should pass)...\n');
    constraints1 = createNoConflictConstraints();
    [hasConflicts1, report1] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints1, timeStep);
    if ~hasConflicts1
        fprintf('✓ PASSED: No conflicts detected\n\n');
    else
        fprintf('✗ FAILED: Unexpected conflicts detected\n');
        fprintf('%s\n\n', report1.message);
    end

    % Test 2: Operator conflict (same operator, overlapping times)
    fprintf('Test 2: Operator conflict (should detect conflict)...\n');
    constraints2 = createOperatorConflictConstraints();
    [hasConflicts2, report2] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints2, timeStep);
    if hasConflicts2
        fprintf('✓ PASSED: Operator conflict detected\n');
        fprintf('Message:\n%s\n\n', report2.message);
    else
        fprintf('✗ FAILED: Operator conflict not detected\n\n');
    end

    % Test 3: Lab conflict (same lab, overlapping times)
    fprintf('Test 3: Lab conflict (should detect conflict)...\n');
    constraints3 = createLabConflictConstraints();
    [hasConflicts3, report3] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints3, timeStep);
    if hasConflicts3
        fprintf('✓ PASSED: Lab conflict detected\n');
        fprintf('Message:\n%s\n\n', report3.message);
    else
        fprintf('✗ FAILED: Lab conflict not detected\n\n');
    end

    % Test 4: Both operator and lab conflicts
    fprintf('Test 4: Both operator and lab conflicts (should detect both)...\n');
    constraints4 = createMultipleConflictConstraints();
    [hasConflicts4, report4] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints4, timeStep);
    if hasConflicts4
        fprintf('✓ PASSED: Multiple conflicts detected\n');
        fprintf('Message:\n%s\n\n', report4.message);
    else
        fprintf('✗ FAILED: Multiple conflicts not detected\n\n');
    end

    % Test 5: Empty constraints (should pass)
    fprintf('Test 5: Empty constraints (should pass)...\n');
    constraints5 = struct([]);
    [hasConflicts5, report5] = conduction.scheduling.LockedCaseConflictValidator.validate(constraints5, timeStep);
    if ~hasConflicts5
        fprintf('✓ PASSED: No conflicts with empty constraints\n\n');
    else
        fprintf('✗ FAILED: Unexpected conflicts with empty constraints\n\n');
    end

    fprintf('=== All Tests Complete ===\n\n');
end

function constraints = createNoConflictConstraints()
    % Create two locked cases with no conflicts
    constraint1 = struct();
    constraint1.caseID = 'case_001';
    constraint1.caseNumber = 1;
    constraint1.operator = 'Dr. Smith';
    constraint1.assignedLab = 1;
    constraint1.startTime = 480;      % 08:00
    constraint1.procStartTime = 495;  % 08:15
    constraint1.procEndTime = 555;    % 09:15
    constraint1.endTime = 585;        % 09:45

    constraint2 = struct();
    constraint2.caseID = 'case_002';
    constraint2.caseNumber = 2;
    constraint2.operator = 'Dr. Jones';
    constraint2.assignedLab = 2;
    constraint2.startTime = 600;      % 10:00
    constraint2.procStartTime = 615;  % 10:15
    constraint2.procEndTime = 675;    % 11:15
    constraint2.endTime = 705;        % 11:45

    constraints = [constraint1, constraint2];
end

function constraints = createOperatorConflictConstraints()
    % Create two locked cases with same operator at overlapping times
    constraint1 = struct();
    constraint1.caseID = 'case_003';
    constraint1.caseNumber = 3;
    constraint1.operator = 'Dr. Smith';
    constraint1.assignedLab = 1;
    constraint1.startTime = 480;      % 08:00
    constraint1.procStartTime = 495;  % 08:15
    constraint1.procEndTime = 555;    % 09:15
    constraint1.endTime = 585;        % 09:45

    constraint2 = struct();
    constraint2.caseID = 'case_004';
    constraint2.caseNumber = 4;
    constraint2.operator = 'Dr. Smith';  % SAME OPERATOR
    constraint2.assignedLab = 2;
    constraint2.startTime = 540;      % 09:00 (overlaps with case_003)
    constraint2.procStartTime = 550;  % 09:10 (OVERLAPS: 09:10 < 09:15)
    constraint2.procEndTime = 610;    % 10:10
    constraint2.endTime = 640;        % 10:40

    constraints = [constraint1, constraint2];
end

function constraints = createLabConflictConstraints()
    % Create two locked cases on same lab at overlapping times
    constraint1 = struct();
    constraint1.caseID = 'case_005';
    constraint1.caseNumber = 5;
    constraint1.operator = 'Dr. Smith';
    constraint1.assignedLab = 1;
    constraint1.startTime = 480;      % 08:00
    constraint1.procStartTime = 495;  % 08:15
    constraint1.procEndTime = 555;    % 09:15
    constraint1.endTime = 585;        % 09:45

    constraint2 = struct();
    constraint2.caseID = 'case_006';
    constraint2.caseNumber = 6;
    constraint2.operator = 'Dr. Jones';
    constraint2.assignedLab = 1;      % SAME LAB
    constraint2.startTime = 540;      % 09:00 (overlaps with case_005)
    constraint2.procStartTime = 555;  % 09:15
    constraint2.procEndTime = 615;    % 10:15
    constraint2.endTime = 645;        % 10:45

    constraints = [constraint1, constraint2];
end

function constraints = createMultipleConflictConstraints()
    % Create multiple conflicts: operator conflict and lab conflict
    constraint1 = struct();
    constraint1.caseID = 'case_007';
    constraint1.caseNumber = 7;
    constraint1.operator = 'Dr. Smith';
    constraint1.assignedLab = 1;
    constraint1.startTime = 480;      % 08:00
    constraint1.procStartTime = 495;  % 08:15
    constraint1.procEndTime = 555;    % 09:15
    constraint1.endTime = 585;        % 09:45

    constraint2 = struct();
    constraint2.caseID = 'case_008';
    constraint2.caseNumber = 8;
    constraint2.operator = 'Dr. Smith';  % OPERATOR CONFLICT
    constraint2.assignedLab = 1;         % LAB CONFLICT
    constraint2.startTime = 540;      % 09:00 (overlaps lab window)
    constraint2.procStartTime = 550;  % 09:10 (overlaps operator time)
    constraint2.procEndTime = 610;    % 10:10
    constraint2.endTime = 640;        % 10:40

    constraint3 = struct();
    constraint3.caseID = 'case_009';
    constraint3.caseNumber = 9;
    constraint3.operator = 'Dr. Jones';
    constraint3.assignedLab = 2;
    constraint3.startTime = 600;      % 10:00
    constraint3.procStartTime = 615;  % 10:15
    constraint3.procEndTime = 675;    % 11:15
    constraint3.endTime = 705;        % 11:45

    constraints = [constraint1, constraint2, constraint3];
end
