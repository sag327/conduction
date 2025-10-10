function test_removeCasesByIds()
    %TEST_REMOVECASESBYIDS Verify case removal from DailySchedule works correctly

    fprintf('Testing DailySchedule.removeCasesByIds()...\n');

    % Setup: Create a mock schedule with known cases
    testDate = datetime('2025-01-15');
    labs = [conduction.Lab('Lab 1', ''), conduction.Lab('Lab 2', '')];

    % Lab 1: Cases 1, 2
    lab1Case1 = struct('caseID', 1, 'operator', 'Dr. Smith', 'procedure', 'Ablation', ...
                       'startTime', 480, 'procStartTime', 495, 'procEndTime', 585, ...
                       'endTime', 600, 'admissionStatus', 'outpatient');
    lab1Case2 = struct('caseID', 2, 'operator', 'Dr. Jones', 'procedure', 'PCI', ...
                       'startTime', 610, 'procStartTime', 625, 'procEndTime', 685, ...
                       'endTime', 700, 'admissionStatus', 'inpatient');

    % Lab 2: Case 3
    lab2Case3 = struct('caseID', 3, 'operator', 'Dr. Brown', 'procedure', 'Device', ...
                       'startTime', 480, 'procStartTime', 495, 'procEndTime', 615, ...
                       'endTime', 630, 'admissionStatus', 'outpatient');

    labAssignments = {[lab1Case1; lab1Case2], lab2Case3};
    metrics = struct('makespan', 220);

    originalSchedule = conduction.DailySchedule(testDate, labs, labAssignments, metrics);

    % Test 1: Remove single case (case 2 from Lab 1)
    fprintf('  Test 1: Remove single case (ID=2)...\n');
    updatedSchedule = originalSchedule.removeCasesByIds(2);

    % Verify case 2 is removed
    allCases = updatedSchedule.cases();
    caseIds = arrayfun(@(c) c.caseID, allCases);
    assert(~ismember(2, caseIds), 'Case 2 should be removed');

    % Verify cases 1 and 3 remain
    assert(ismember(1, caseIds), 'Case 1 should remain');
    assert(ismember(3, caseIds), 'Case 3 should remain');
    assert(numel(allCases) == 2, 'Should have 2 cases after removal');

    % Verify Lab 1 has only case 1
    lab1Assignments = updatedSchedule.labAssignments();
    assert(numel(lab1Assignments{1}) == 1, 'Lab 1 should have 1 case');
    assert(lab1Assignments{1}(1).caseID == 1, 'Lab 1 should have case 1');

    % Verify Lab 2 still has case 3
    assert(numel(lab1Assignments{2}) == 1, 'Lab 2 should have 1 case');
    assert(lab1Assignments{2}(1).caseID == 3, 'Lab 2 should have case 3');

    % Verify schedule properties preserved
    assert(updatedSchedule.Date == testDate, 'Date should be preserved');
    assert(numel(updatedSchedule.Labs) == 2, 'Lab count should be preserved');
    assert(isequal(updatedSchedule.metrics(), metrics), 'Metrics should be preserved');

    fprintf('    ✓ Single case removal passed\n');

    % Test 2: Remove multiple cases
    fprintf('  Test 2: Remove multiple cases (IDs=[1,3])...\n');
    updatedSchedule2 = originalSchedule.removeCasesByIds([1, 3]);

    allCases2 = updatedSchedule2.cases();
    caseIds2 = arrayfun(@(c) c.caseID, allCases2);
    assert(~ismember(1, caseIds2), 'Case 1 should be removed');
    assert(~ismember(3, caseIds2), 'Case 3 should be removed');
    assert(ismember(2, caseIds2), 'Case 2 should remain');
    assert(numel(allCases2) == 1, 'Should have 1 case after removal');

    fprintf('    ✓ Multiple case removal passed\n');

    % Test 3: Remove non-existent case (should not error)
    fprintf('  Test 3: Remove non-existent case (ID=999)...\n');
    updatedSchedule3 = originalSchedule.removeCasesByIds(999);

    allCases3 = updatedSchedule3.cases();
    assert(numel(allCases3) == 3, 'All cases should remain if ID not found');

    fprintf('    ✓ Non-existent case removal passed\n');

    % Test 4: Remove all cases
    fprintf('  Test 4: Remove all cases...\n');
    updatedSchedule4 = originalSchedule.removeCasesByIds([1, 2, 3]);

    allCases4 = updatedSchedule4.cases();
    assert(isempty(allCases4), 'All cases should be removed');

    lab4Assignments = updatedSchedule4.labAssignments();
    assert(isempty(lab4Assignments{1}), 'Lab 1 should be empty');
    assert(isempty(lab4Assignments{2}), 'Lab 2 should be empty');

    fprintf('    ✓ Remove all cases passed\n');

    % Test 5: Original schedule unchanged (immutability)
    fprintf('  Test 5: Original schedule immutability...\n');
    originalCases = originalSchedule.cases();
    assert(numel(originalCases) == 3, 'Original schedule should be unchanged');

    fprintf('    ✓ Immutability preserved\n');

    fprintf('\n✓ All tests passed!\n\n');
end
