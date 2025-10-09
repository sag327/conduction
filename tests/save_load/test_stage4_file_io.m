function test_stage4_file_io()
    % TEST_STAGE4_FILE_IO Test file I/O (save/load/generate filename)
    % This tests Stage 4 of the save/load implementation

    fprintf('\n=== Stage 4: File I/O Tests ===\n\n');

    testResults = struct();
    testResults.passed = 0;
    testResults.failed = 0;
    testResults.tests = {};

    % Test 1: Save and load basic file
    try
        fprintf('Test 1: Save and load basic file... ');
        sessionData = struct('version', '1.0.0', 'targetDate', datetime('2025-01-15'));
        filepath = tempname();

        conduction.session.saveSessionToFile(sessionData, filepath);
        assert(isfile([filepath '.mat']), 'File should be created');

        loaded = conduction.session.loadSessionFromFile([filepath '.mat']);
        assert(isequal(loaded.version, sessionData.version), 'Version should match');
        assert(loaded.targetDate == sessionData.targetDate, 'Target date should match');

        delete([filepath '.mat']);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Save and load basic file';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 2: Save with .mat extension auto-append
    try
        fprintf('Test 2: Save with .mat extension auto-append... ');
        sessionData = struct('version', '1.0.0', 'targetDate', datetime('2025-01-15'));
        filepath = tempname(); % No extension

        conduction.session.saveSessionToFile(sessionData, filepath);
        assert(isfile([filepath '.mat']), 'File with .mat extension should exist');

        delete([filepath '.mat']);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Save with .mat extension auto-append';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 3: Backup on overwrite
    try
        fprintf('Test 3: Backup on overwrite... ');
        sessionData1 = struct('version', '1.0.0', 'data', 1);
        filepath = [tempname() '.mat'];

        conduction.session.saveSessionToFile(sessionData1, filepath);

        sessionData2 = struct('version', '1.0.0', 'data', 2);
        conduction.session.saveSessionToFile(sessionData2, filepath);

        assert(isfile([filepath '.backup']), 'Backup file should exist');

        delete(filepath);
        delete([filepath '.backup']);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Backup on overwrite';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 4: Load nonexistent file error
    try
        fprintf('Test 4: Load nonexistent file error... ');
        try
            loaded = conduction.session.loadSessionFromFile('nonexistent_file_xyz.mat');
            error('Should have thrown error');
        catch ME
            assert(contains(ME.identifier, 'FileNotFound'), 'Should be FileNotFound error');
        end

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Load nonexistent file error';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 5: Load corrupt file error
    try
        fprintf('Test 5: Load corrupt file error... ');
        corruptFile = [tempname() '.mat'];
        fid = fopen(corruptFile, 'w');
        fwrite(fid, 'This is not a MAT file');
        fclose(fid);

        try
            loaded = conduction.session.loadSessionFromFile(corruptFile);
            delete(corruptFile);
            error('Should have thrown error');
        catch ME
            delete(corruptFile);
            assert(contains(ME.identifier, 'CorruptFile') || contains(ME.identifier, 'LoadFailed'), ...
                'Should be CorruptFile or LoadFailed error');
        end

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Load corrupt file error';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 6: Generate session filename format
    try
        fprintf('Test 6: Generate session filename format... ');
        filepath = conduction.session.generateSessionFilename(datetime('2025-01-15'));

        assert(contains(filepath, 'session_2025-01-15'), 'Filename should contain date');
        assert(contains(filepath, '.mat'), 'Filename should have .mat extension');
        assert(contains(filepath, 'sessions'), 'Path should contain sessions directory');

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Generate session filename format';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 7: Generate session filename with custom base path
    try
        fprintf('Test 7: Generate session filename with custom base path... ');
        customPath = tempname();
        filepath = conduction.session.generateSessionFilename(datetime('2025-01-15'), customPath);

        assert(contains(filepath, customPath), 'Path should contain custom base path');
        assert(isfolder(customPath), 'Custom directory should be created');

        rmdir(customPath);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Generate session filename with custom base path';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 8: Full roundtrip with real app data
    try
        fprintf('Test 8: Full roundtrip with real app data... ');
        app = conduction.gui.ProspectiveSchedulerApp();
        app.CaseManager.addCase('Dr. Smith', 'Procedure A', 60);
        app.CaseManager.addCase('Dr. Jones', 'Procedure B', 45);

        sessionData = app.exportAppState();
        filepath = [tempname() '.mat'];

        conduction.session.saveSessionToFile(sessionData, filepath);
        loadedData = conduction.session.loadSessionFromFile(filepath);

        assert(length(loadedData.cases) == 2, 'Should have 2 cases');
        assert(loadedData.cases(1).operatorName == "Dr. Smith", 'First case operator should match');

        delete(filepath);
        delete(app);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Full roundtrip with real app data';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 9: Complete save/load/import workflow
    try
        fprintf('Test 9: Complete save/load/import workflow... ');
        app1 = conduction.gui.ProspectiveSchedulerApp();
        app1.CaseManager.addCase('Dr. Adams', 'Procedure C', 90);
        app1.TargetDate = datetime('2025-02-20');

        % Export and save
        sessionData = app1.exportAppState();
        filepath = [tempname() '.mat'];
        conduction.session.saveSessionToFile(sessionData, filepath);

        % Load and import into new app
        app2 = conduction.gui.ProspectiveSchedulerApp();
        loadedData = conduction.session.loadSessionFromFile(filepath);
        app2.importAppState(loadedData);

        assert(app2.CaseManager.CaseCount == 1, 'Should have 1 case');
        assert(app2.TargetDate == datetime('2025-02-20'), 'Target date should match');

        delete(filepath);
        delete(app1);
        delete(app2);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Complete save/load/import workflow';
    catch ME
        fprintf('FAILED ✗\n');
        fprintf('  Error: %s\n', ME.message);
        testResults.failed = testResults.failed + 1;
    end

    % Test 10: Version warning on mismatch
    try
        fprintf('Test 10: Version warning on mismatch... ');
        sessionData = struct('version', '0.9.0', 'targetDate', datetime('2025-01-15'));
        filepath = [tempname() '.mat'];

        conduction.session.saveSessionToFile(sessionData, filepath);

        % Should warn about version mismatch
        lastwarn(''); % Clear last warning
        loaded = conduction.session.loadSessionFromFile(filepath);
        [warnMsg, warnId] = lastwarn();

        assert(contains(warnId, 'VersionMismatch'), 'Should issue version mismatch warning');

        delete(filepath);

        fprintf('PASSED ✓\n');
        testResults.passed = testResults.passed + 1;
        testResults.tests{end+1} = 'Version warning on mismatch';
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
        fprintf('\n✓ All Stage 4 tests passed!\n\n');
    else
        fprintf('\n✗ Some tests failed. Please review the errors above.\n\n');
        error('Stage 4 tests failed');
    end
end
