function test_stage2_state_extraction()
    % TEST_STAGE2_STATE_EXTRACTION Test state extraction (exportAppState)
    % This tests Stage 2 of the save/load implementation

    fprintf('\n=== Stage 2: State Extraction Tests ===\n\n');

    testResults = struct();
    testResults.passed = 0;
    testResults.failed = 0;
    testResults.tests = {};

    % Test 1: Extract state from empty app
    try
        fprintf('Test 1: Extract state from empty app... ');
        app = conduction.gui.ProspectiveSchedulerApp();
        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'version'), 'Missing version field');
        assert(isfield(sessionData, 'targetDate'), 'Missing targetDate field');
        assert(isfield(sessionData, 'cases'), 'Missing cases field');
        assert(isempty(sessionData.cases), 'Cases should be empty');
        assert(sessionData.version == "1.0.0", 'Version should be 1.0.0');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract state from empty app';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 2: Extract state with cases
    try
        fprintf('Test 2: Extract state with cases... ');
        app = conduction.gui.ProspectiveSchedulerApp();
        app.CaseManager.addCase('Dr. Smith', 'Procedure A', 60);
        app.CaseManager.addCase('Dr. Jones', 'Procedure B', 45);

        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'cases'), 'Missing cases field');
        assert(length(sessionData.cases) == 2, 'Should have 2 cases');
        assert(sessionData.cases(1).operatorName == "Dr. Smith", 'First case operator mismatch');
        assert(sessionData.cases(2).operatorName == "Dr. Jones", 'Second case operator mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract state with cases';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 3: Extract state with various case properties
    try
        fprintf('Test 3: Extract state with various case properties... ');
        app = conduction.gui.ProspectiveSchedulerApp();

        % Add case with specific properties
        app.CaseManager.addCase('Dr. Adams', 'Procedure C', 90);
        caseObj = app.CaseManager.getCase(1);
        caseObj.AdmissionStatus = "inpatient";
        caseObj.IsFirstCaseOfDay = true;
        caseObj.SpecificLab = "Lab 3";

        sessionData = app.exportAppState();

        assert(sessionData.cases(1).admissionStatus == "inpatient", 'Admission status mismatch');
        assert(sessionData.cases(1).isFirstCaseOfDay == true, 'First case flag mismatch');
        assert(sessionData.cases(1).specificLab == "Lab 3", 'Specific lab mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract state with various case properties';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 4: Extract optimization state
    try
        fprintf('Test 4: Extract optimization state... ');
        app = conduction.gui.ProspectiveSchedulerApp();

        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'opts'), 'Missing opts field');
        assert(isfield(sessionData, 'labIds'), 'Missing labIds field');
        assert(isfield(sessionData, 'availableLabIds'), 'Missing availableLabIds field');
        assert(isfield(sessionData, 'optimizationOutcome'), 'Missing optimizationOutcome field');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract optimization state';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 5: Extract UI state
    try
        fprintf('Test 5: Extract UI state... ');
        app = conduction.gui.ProspectiveSchedulerApp();

        % Set some UI state
        app.LockedCaseIds = ["1", "3"];
        app.IsOptimizationDirty = false;

        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'lockedCaseIds'), 'Missing lockedCaseIds field');
        assert(isfield(sessionData, 'isOptimizationDirty'), 'Missing isOptimizationDirty field');
        assert(isequal(sessionData.lockedCaseIds, ["1", "3"]), 'Locked case IDs mismatch');
        assert(sessionData.isOptimizationDirty == false, 'Dirty flag mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract UI state';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 6: Extract time control state
    try
        fprintf('Test 6: Extract time control state... ');
        app = conduction.gui.ProspectiveSchedulerApp();

        % Set time control state
        app.IsTimeControlActive = true;
        app.TimeControlBaselineLockedIds = ["2", "4"];
        app.TimeControlLockedCaseIds = ["5", "6"];

        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'timeControlState'), 'Missing timeControlState field');
        assert(sessionData.timeControlState.isActive == true, 'Time control active flag mismatch');
        assert(isequal(sessionData.timeControlState.baselineLockedIds, ["2", "4"]), ...
            'Baseline locked IDs mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract time control state';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 7: Extract operator colors
    try
        fprintf('Test 7: Extract operator colors... ');
        app = conduction.gui.ProspectiveSchedulerApp();

        % Set some operator colors
        app.OperatorColors('Dr. Smith') = [1, 0, 0];
        app.OperatorColors('Dr. Jones') = [0, 1, 0];

        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'operatorColors'), 'Missing operatorColors field');
        assert(isfield(sessionData.operatorColors, 'keys'), 'Missing keys in operatorColors');
        assert(isfield(sessionData.operatorColors, 'values'), 'Missing values in operatorColors');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract operator colors';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 8: Extract metadata fields
    try
        fprintf('Test 8: Extract metadata fields... ');
        app = conduction.gui.ProspectiveSchedulerApp();

        sessionData = app.exportAppState();

        assert(isfield(sessionData, 'version'), 'Missing version field');
        assert(isfield(sessionData, 'appVersion'), 'Missing appVersion field');
        assert(isfield(sessionData, 'savedDate'), 'Missing savedDate field');
        assert(isfield(sessionData, 'userNotes'), 'Missing userNotes field');
        assert(isa(sessionData.savedDate, 'datetime'), 'savedDate should be datetime');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract metadata fields';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 9: Extract target date
    try
        fprintf('Test 9: Extract target date... ');
        testDate = datetime('2025-02-15');
        app = conduction.gui.ProspectiveSchedulerApp(testDate);

        sessionData = app.exportAppState();

        assert(sessionData.targetDate == testDate, 'Target date mismatch');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Extract target date';

        delete(app);
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 10: Verify all required fields present
    try
        fprintf('Test 10: Verify all required fields present... ');
        app = conduction.gui.ProspectiveSchedulerApp();
        sessionData = app.exportAppState();

        requiredFields = {'version', 'appVersion', 'savedDate', 'targetDate', 'userNotes', ...
            'cases', 'completedCases', 'optimizedSchedule', 'simulatedSchedule', ...
            'optimizationOutcome', 'opts', 'labIds', 'availableLabIds', ...
            'lockedCaseIds', 'isOptimizationDirty', 'timeControlState', ...
            'operatorColors', 'historicalDataPath'};

        for i = 1:length(requiredFields)
            assert(isfield(sessionData, requiredFields{i}), ...
                sprintf('Missing required field: %s', requiredFields{i}));
        end

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Verify all required fields present';

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
        fprintf('\n✓ All Stage 2 tests passed!\n\n');
    else
        fprintf('\n✗ Some tests failed. Please review the errors above.\n\n');
        error('Stage 2 tests failed');
    end
end
