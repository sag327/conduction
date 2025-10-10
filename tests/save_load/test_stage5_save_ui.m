% test_stage5_save_ui.m
% Test Stage 5: UI Integration - Save functionality
%
% This test verifies that the save session workflow works correctly
% by testing the underlying functionality (without opening the actual UI dialog)

function test_stage5_save_ui()
    fprintf('=== Testing Stage 5: Save Session UI Integration ===\n\n');

    testsPassed = 0;
    testsTotal = 0;

    % Test 1: Programmatic save workflow (simulates button click)
    testsTotal = testsTotal + 1;
    fprintf('Test 1: Programmatic save workflow...\n');
    try
        % Create test app with some data
        app = conduction.gui.ProspectiveSchedulerApp();
        app.CaseManager.addCase('Dr. Smith', 'Procedure A', 60);
        app.CaseManager.addCase('Dr. Jones', 'Procedure B', 45);
        app.TargetDate = datetime('2025-01-15');

        % Generate filename (simulating what SaveSessionButtonPushed does)
        testFile = tempname();

        % Export and save (this is what the button callback does)
        sessionData = app.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Verify file was created
        assert(isfile([testFile '.mat']), 'Session file should be created');

        % Verify we can load it back
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        assert(isequal(loaded.version, '1.0.0'), 'Version should be 1.0.0');
        assert(loaded.targetDate == datetime('2025-01-15'), 'Target date should match');
        assert(length(loaded.cases) == 2, 'Should have 2 cases');

        % Clean up
        delete([testFile '.mat']);
        delete(app);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 2: Default filename generation
    testsTotal = testsTotal + 1;
    fprintf('Test 2: Default filename generation...\n');
    try
        targetDate = datetime('2025-02-20');
        defaultPath = conduction.session.generateSessionFilename(targetDate);
        [~, defaultFile, ~] = fileparts(defaultPath);

        % Verify filename contains the date
        assert(contains(defaultFile, '2025-02-20'), 'Filename should contain date');
        assert(contains(defaultFile, 'session_'), 'Filename should start with session_');

        fprintf('   Generated filename: %s\n', defaultFile);
        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 3: Save with empty app
    testsTotal = testsTotal + 1;
    fprintf('Test 3: Save with empty app...\n');
    try
        app = conduction.gui.ProspectiveSchedulerApp();
        testFile = tempname();

        % Export and save
        sessionData = app.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Verify file was created
        assert(isfile([testFile '.mat']), 'Session file should be created');

        % Load and verify
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        assert(isempty(loaded.cases), 'Empty app should have no cases');

        % Clean up
        delete([testFile '.mat']);
        delete(app);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 4: Full save/load roundtrip
    testsTotal = testsTotal + 1;
    fprintf('Test 4: Full save/load roundtrip...\n');
    try
        % Create app with data
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. A', 'Proc X', 60);
        app1.TargetDate = datetime('2025-03-10');

        % Save
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Create new app and load
        app2 = conduction.gui.ProspectiveSchedulerApp();
        loaded = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(loaded);

        % Verify data matches
        assert(app2.CaseManager.CaseCount == 1, 'Should have 1 case');
        assert(app2.TargetDate == datetime('2025-03-10'), 'Target date should match');
        caseObj = app2.CaseManager.getCase(1);
        assert(strcmp(caseObj.OperatorName, 'Dr. A'), 'Operator name should match');

        % Clean up
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Test 5: Error handling for invalid path
    testsTotal = testsTotal + 1;
    fprintf('Test 5: Error handling for invalid path...\n');
    try
        app = conduction.gui.ProspectiveSchedulerApp();
        sessionData = app.exportAppState();

        % Try to save to invalid path (should throw error)
        invalidPath = '/nonexistent/directory/session.mat';
        errorThrown = false;
        try
            conduction.session.saveSessionToFile(sessionData, invalidPath);
        catch
            errorThrown = true;
        end

        assert(errorThrown, 'Should throw error for invalid path');

        delete(app);

        fprintf('   ✓ PASSED\n\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('   ✗ FAILED: %s\n\n', ME.message);
    end

    % Summary
    fprintf('========================================\n');
    fprintf('Stage 5 Tests Complete: %d/%d passed\n', testsPassed, testsTotal);
    fprintf('========================================\n\n');

    if testsPassed == testsTotal
        fprintf('✓ ALL TESTS PASSED - Stage 5 implementation is working!\n\n');
    else
        error('Some tests failed. Please review the output above.');
    end
end
