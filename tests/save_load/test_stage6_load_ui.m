% test_stage6_load_ui.m
% Test Stage 6: UI Integration - Load functionality
%
% This test verifies that the load session workflow works correctly
% by testing the underlying functionality (without opening the actual UI dialog)

function test_stage6_load_ui()
    fprintf('=== Testing Stage 6: Load Session UI Integration ===\n\n');

    testsPassed = 0;
    testsTotal = 0;

    % Test 1: Full save/load workflow
    testsTotal = testsTotal + 1;
    fprintf('Test 1: Full save/load workflow...\n');
    try
        % Create and populate app1
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. Smith', 'Procedure A', 60);
        app1.CaseManager.addCase('Dr. Jones', 'Procedure B', 45);
        app1.TargetDate = datetime('2025-02-15');

        % Save session
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Create new app and load session (simulating LoadSessionButtonPushed)
        app2 = conduction.gui.ProspectiveSchedulerApp();
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);

        % Verify data
        assert(app2.CaseManager.CaseCount == 2, 'Should have 2 cases');
        assert(app2.TargetDate == datetime('2025-02-15'), 'Target date should match');

        case1 = app2.CaseManager.getCase(1);
        assert(strcmp(case1.OperatorName, 'Dr. Smith'), 'First case operator should match');
        assert(case1.EstimatedDurationMinutes == 60, 'First case duration should match');

        % Clean up
        delete([testFile '.mat']);
        if isfile([testFile '.mat.backup'])
            delete([testFile '.mat.backup']);
        end
        delete(app1);
        delete(app2);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 2: Load with different target dates
    testsTotal = testsTotal + 1;
    fprintf('Test 2: Load with different target dates...\n');
    try
        % Create app with specific date
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.TargetDate = datetime('2025-12-25');
        app1.CaseManager.addCase('Dr. Holiday', 'Special Procedure', 90);

        % Save
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Load into new app
        app2 = conduction.gui.ProspectiveSchedulerApp();
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);

        % Verify date was restored
        assert(app2.TargetDate == datetime('2025-12-25'), 'Target date should be restored');
        assert(app2.CaseManager.CaseCount == 1, 'Should have 1 case');

        % Clean up
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 3: Load clears existing data
    testsTotal = testsTotal + 1;
    fprintf('Test 3: Load clears existing data...\n');
    try
        % Create app with data to save
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. A', 'Proc X', 30);
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Create app with different data
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.CaseManager.addCase('Dr. B', 'Proc Y', 45);
        app2.CaseManager.addCase('Dr. C', 'Proc Z', 60);
        assert(app2.CaseManager.CaseCount == 2, 'Should start with 2 cases');

        % Load saved session - should clear existing data
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);

        % Verify only loaded data remains
        assert(app2.CaseManager.CaseCount == 1, 'Should have only 1 case after load');
        case1 = app2.CaseManager.getCase(1);
        assert(strcmp(case1.OperatorName, 'Dr. A'), 'Should have loaded case, not existing case');

        % Clean up
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 4: Load with case properties
    testsTotal = testsTotal + 1;
    fprintf('Test 4: Load with case properties (locked, admission status, etc.)...\n');
    try
        % Create app with cases having various properties
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. Smith', 'Procedure A', 60, '', false, 'inpatient');
        case1 = app1.CaseManager.getCase(1);
        case1.IsLocked = true;

        % Save
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Load into new app
        app2 = conduction.gui.ProspectiveSchedulerApp();
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);

        % Verify properties were restored
        case2 = app2.CaseManager.getCase(1);
        assert(case2.IsLocked == true, 'Locked state should be restored');
        assert(strcmp(case2.AdmissionStatus, 'inpatient'), 'Admission status should be restored');

        % Clean up
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 5: Error handling for invalid file
    testsTotal = testsTotal + 1;
    fprintf('Test 5: Error handling for invalid file...\n');
    try
        app = conduction.gui.ProspectiveSchedulerApp();

        % Try to load non-existent file (should throw error)
        errorThrown = false;
        try
            loaded = conduction.session.loadSessionFromFile('nonexistent_session.mat');
            app.importAppState(loaded);
        catch
            errorThrown = true;
        end

        assert(errorThrown, 'Should throw error for non-existent file');

        delete(app);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 6: Load empty session
    testsTotal = testsTotal + 1;
    fprintf('Test 6: Load empty session...\n');
    try
        % Create empty app and save
        app1 = conduction.gui.ProspectiveSchedulerApp();
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Create app with some data, then load empty session
        app2 = conduction.gui.ProspectiveSchedulerApp();
        app2.CaseManager.addCase('Dr. X', 'Proc Y', 30);

        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);

        % Verify app is now empty
        assert(app2.CaseManager.CaseCount == 0, 'Should have no cases after loading empty session');

        % Clean up
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 7: Multiple save/load cycles
    testsTotal = testsTotal + 1;
    fprintf('Test 7: Multiple save/load cycles...\n');
    try
        % Cycle 1: Save with 1 case
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. A', 'Proc 1', 30);
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Cycle 2: Load, add case, save again
        app2 = conduction.gui.ProspectiveSchedulerApp();
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);
        app2.CaseManager.addCase('Dr. B', 'Proc 2', 45);
        sessionData = app2.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Cycle 3: Load final version
        app3 = conduction.gui.ProspectiveSchedulerApp();
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app3.importAppState(loaded);

        % Verify final state
        assert(app3.CaseManager.CaseCount == 2, 'Should have 2 cases after multiple cycles');

        % Clean up
        delete([testFile '.mat']);
        if isfile([testFile '.mat.backup'])
            delete([testFile '.mat.backup']);
        end
        delete(app1);
        delete(app2);
        delete(app3);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Summary
    fprintf('========================================\n');
    fprintf('Stage 6 Tests Complete: %d/%d passed\n', testsPassed, testsTotal);
    fprintf('========================================\n\n');

    if testsPassed == testsTotal
        fprintf('✓ ALL TESTS PASSED - Stage 6 implementation is working!\n\n');
    else
        error('Some tests failed. Please review the output above.');
    end
end
