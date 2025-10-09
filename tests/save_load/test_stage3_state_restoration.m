function test_stage3_state_restoration()
    % TEST_STAGE3_STATE_RESTORATION Test state restoration (importAppState)
    % This tests Stage 3 of the save/load implementation

    fprintf('\n=== Stage 3: State Restoration Tests ===\n\n');

    testResults = struct();
    testResults.passed = 0;
    testResults.failed = 0;
    testResults.tests = {};

    % Test 1: Full roundtrip - empty app
    try
        fprintf('Test 1: Full roundtrip - empty app... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(app1.TargetDate == app2.TargetDate, 'Target dates should match');
        assert(app2.CaseManager.CaseCount == 0, 'Should have 0 cases');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Full roundtrip - empty app';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 2: Full roundtrip - app with cases
    try
        fprintf('Test 2: Full roundtrip - app with cases... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. Smith', 'Procedure A', 60);
        app1.CaseManager.addCase('Dr. Jones', 'Procedure B', 45);

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(app2.CaseManager.CaseCount == 2, 'Should have 2 cases');
        case1 = app2.CaseManager.getCase(1);
        case2 = app2.CaseManager.getCase(2);
        assert(case1.OperatorName == "Dr. Smith", 'First case operator mismatch');
        assert(case2.OperatorName == "Dr. Jones", 'Second case operator mismatch');
        assert(case1.EstimatedDurationMinutes == 60, 'First case duration mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Full roundtrip - app with cases';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 3: Restore case properties
    try
        fprintf('Test 3: Restore case properties... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. Adams', 'Procedure C', 90);
        case1 = app1.CaseManager.getCase(1);
        case1.AdmissionStatus = "inpatient";
        case1.IsFirstCaseOfDay = true;
        case1.SpecificLab = "Lab 3";
        case1.IsLocked = true;

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        case2 = app2.CaseManager.getCase(1);
        assert(case2.AdmissionStatus == "inpatient", 'Admission status mismatch');
        assert(case2.IsFirstCaseOfDay == true, 'First case flag mismatch');
        assert(case2.SpecificLab == "Lab 3", 'Specific lab mismatch');
        assert(case2.IsLocked == true, 'Locked flag mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore case properties';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 4: Restore target date
    try
        fprintf('Test 4: Restore target date... ');
        testDate = datetime('2025-03-15');
        app1 = conduction.gui.ProspectiveSchedulerApp(testDate);
        sessionData = app1.exportAppState();

        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(app2.TargetDate == testDate, 'Target date mismatch');
        assert(app2.DatePicker.Value == testDate, 'Date picker value mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore target date';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 5: Restore optimization state
    try
        fprintf('Test 5: Restore optimization state... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.Opts.metric = "makespan";
        app1.Opts.labs = 8;
        app1.Opts.turnover = 25;
        app1.IsOptimizationDirty = false;

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(app2.Opts.metric == "makespan", 'Optimization metric mismatch');
        assert(app2.Opts.labs == 8, 'Lab count mismatch');
        assert(app2.Opts.turnover == 25, 'Turnover mismatch');
        assert(app2.IsOptimizationDirty == false, 'Dirty flag mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore optimization state';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 6: Restore lab configuration
    try
        fprintf('Test 6: Restore lab configuration... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.LabIds = [1 2 3 4 5 6 7 8];
        app1.AvailableLabIds = [1 3 5 7];

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(isequal(app2.LabIds, [1 2 3 4 5 6 7 8]), 'Lab IDs mismatch');
        assert(isequal(app2.AvailableLabIds, [1 3 5 7]), 'Available lab IDs mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore lab configuration';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 7: Restore UI state
    try
        fprintf('Test 7: Restore UI state... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.LockedCaseIds = ["1", "2", "5"];

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(isequal(app2.LockedCaseIds, ["1", "2", "5"]), 'Locked case IDs mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore UI state';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 8: Restore time control state
    try
        fprintf('Test 8: Restore time control state... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.IsTimeControlActive = true;
        app1.TimeControlBaselineLockedIds = ["3", "4"];
        app1.TimeControlLockedCaseIds = ["6", "7"];
        app1.CaseManager.setCurrentTime(480); % 8:00 AM

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(app2.IsTimeControlActive == true, 'Time control active flag mismatch');
        assert(isequal(app2.TimeControlBaselineLockedIds, ["3", "4"]), ...
            'Baseline locked IDs mismatch');
        assert(isequal(app2.TimeControlLockedCaseIds, ["6", "7"]), ...
            'Time control locked IDs mismatch');
        assert(app2.CaseManager.getCurrentTime() == 480, 'Current time mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore time control state';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 9: Restore operator colors
    try
        fprintf('Test 9: Restore operator colors... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.OperatorColors('Dr. Smith') = [1, 0, 0];
        app1.OperatorColors('Dr. Jones') = [0, 1, 0];

        sessionData = app1.exportAppState();
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.importAppState(sessionData);

        assert(app2.OperatorColors.Count == 2, 'Operator colors count mismatch');
        assert(isequal(app2.OperatorColors('Dr. Smith'), [1, 0, 0]), ...
            'Dr. Smith color mismatch');
        assert(isequal(app2.OperatorColors('Dr. Jones'), [0, 1, 0]), ...
            'Dr. Jones color mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Restore operator colors';

        delete(app1);
        delete(app2);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 10: Handle partial/missing data gracefully
    try
        fprintf('Test 10: Handle partial/missing data gracefully... ');
        % Create minimal session data
        sessionData = struct();
        sessionData.version = '1.0.0';
        sessionData.targetDate = datetime('2025-01-15');
        sessionData.cases = [];

        app = conduction.gui.ProspectiveSchedulerApp();
        app.importAppState(sessionData);

        % Should not error, just use defaults for missing fields
        assert(app.TargetDate == datetime('2025-01-15'), 'Target date mismatch');
        assert(app.CaseManager.CaseCount == 0, 'Should have 0 cases');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Handle partial/missing data gracefully';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Summary
    fprintf('\n=== Test Summary ===\n');
    fprintf('Passed: %d\n', testResults.passed);
    fprintf('Failed: %d\n', testResults.failed);
    fprintf('Total:  %d\n', testResults.passed + testResults.failed);

    if testResults.failed == 0
        fprintf('\n✓ All Stage 3 tests passed!\n\n');
    else
        fprintf('\n✗ Some tests failed. Please review the errors above.\n\n');
        error('Stage 3 tests failed');
    end
end
