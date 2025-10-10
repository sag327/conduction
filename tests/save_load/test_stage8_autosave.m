function test_stage8_autosave()
% TEST_STAGE8_AUTOSAVE Test auto-save functionality (Stage 8)
%
% Tests that auto-save properly saves sessions at configured intervals,
% rotates old files, and integrates with the dirty flag system.

    fprintf('Running Stage 8: Auto-save Tests\n');
    fprintf('=================================\n\n');

    % Initialize test results
    testResults = struct('name', {}, 'passed', {}, 'error', {});
    testNum = 0;

    % Cleanup function to ensure auto-save directory is cleaned up
    autoSaveDir = './sessions/autosave';
    cleanupAutoSaves = @() cleanupAutoSaveDir(autoSaveDir);

    % Test 1: Enable auto-save sets properties correctly
    testNum = testNum + 1;
    try
        fprintf('Test %d: Enable auto-save sets properties... ', testNum);
        app = createTestApp();

        assert(~app.AutoSaveEnabled, 'Auto-save should be disabled initially');
        assert(isempty(app.AutoSaveTimer), 'Timer should be empty initially');

        app.enableAutoSave(true, 5);

        assert(app.AutoSaveEnabled, 'Auto-save should be enabled');
        assert(app.AutoSaveInterval == 5, 'Interval should be 5 minutes');
        assert(~isempty(app.AutoSaveTimer), 'Timer should be created');
        assert(isvalid(app.AutoSaveTimer), 'Timer should be valid');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Enable auto-save sets properties';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Enable auto-save sets properties';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 2: Disable auto-save stops timer
    testNum = testNum + 1;
    try
        fprintf('Test %d: Disable auto-save stops timer... ', testNum);
        app = createTestApp();

        app.enableAutoSave(true, 5);
        assert(~isempty(app.AutoSaveTimer), 'Timer should be created');

        app.enableAutoSave(false);

        assert(~app.AutoSaveEnabled, 'Auto-save should be disabled');
        assert(isempty(app.AutoSaveTimer), 'Timer should be stopped and deleted');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Disable auto-save stops timer';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Disable auto-save stops timer';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 3: Auto-save creates file when dirty
    testNum = testNum + 1;
    try
        fprintf('Test %d: Auto-save creates file when dirty... ', testNum);
        app = createTestApp();

        % Add a case and mark dirty
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();

        % Enable auto-save with very short interval for testing
        app.enableAutoSave(true, 0.1);  % 0.1 min = 6 seconds

        % Wait for auto-save to trigger
        pause(7);

        % Check that auto-save file was created
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(~isempty(files), 'Auto-save file should be created');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Auto-save creates file when dirty';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Auto-save creates file when dirty';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 4: Auto-save does not create file when clean
    testNum = testNum + 1;
    try
        fprintf('Test %d: Auto-save skips when not dirty... ', testNum);
        cleanupAutoSaves();  % Clean slate

        app = createTestApp();

        % Enable auto-save but don't mark dirty
        app.enableAutoSave(true, 0.1);

        % Wait for auto-save to trigger
        pause(7);

        % Check that no auto-save file was created
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(isempty(files), 'Auto-save file should not be created when not dirty');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Auto-save skips when not dirty';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Auto-save skips when not dirty';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 5: Auto-save directory is created automatically
    testNum = testNum + 1;
    try
        fprintf('Test %d: Auto-save directory creation... ', testNum);
        cleanupAutoSaves();  % Remove directory

        app = createTestApp();
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();

        % Manually trigger auto-save callback
        app.autoSaveCallback();

        assert(isfolder(autoSaveDir), 'Auto-save directory should be created');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Auto-save directory creation';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Auto-save directory creation';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 6: File rotation keeps only max files
    testNum = testNum + 1;
    try
        fprintf('Test %d: File rotation limits auto-saves... ', testNum);
        cleanupAutoSaves();

        app = createTestApp();
        app.AutoSaveMaxFiles = 3;  % Keep only 3 files
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();

        % Create auto-save directory
        if ~isfolder(autoSaveDir)
            mkdir(autoSaveDir);
        end

        % Create 5 auto-save files
        for i = 1:5
            timestamp = datestr(datetime('now') + seconds(i), 'yyyy-mm-dd_HHMMSS');
            filename = sprintf('autosave_%s.mat', timestamp);
            filepath = fullfile(autoSaveDir, filename);
            sessionData = app.exportAppState();
            conduction.session.saveSessionToFile(sessionData, filepath);
            pause(0.1);  % Ensure different timestamps
        end

        % Verify 5 files exist
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(length(files) == 5, 'Should have 5 files before rotation');

        % Trigger rotation
        app.rotateAutoSaves(autoSaveDir);

        % Check that only 3 files remain
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(length(files) == 3, 'Should have only 3 files after rotation');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'File rotation limits auto-saves';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'File rotation limits auto-saves';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 7: Auto-saved session can be loaded
    testNum = testNum + 1;
    try
        fprintf('Test %d: Auto-saved session can be loaded... ', testNum);
        cleanupAutoSaves();

        app1 = createTestApp();
        app1.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app1.CaseManager.addCase('Dr. C', 'Proc D', 45);
        app1.TargetDate = datetime('2025-03-15');
        app1.markDirty();

        % Manually trigger auto-save
        app1.autoSaveCallback();

        % Get the auto-save file
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(~isempty(files), 'Auto-save file should exist');

        autoSaveFile = fullfile(autoSaveDir, files(1).name);

        % Load in new app
        app2 = createTestApp();
        sessionData = conduction.session.loadSessionFromFile(autoSaveFile);
        app2.importAppState(sessionData);

        assert(app2.CaseManager.CaseCount == 2, 'Should have 2 cases');
        assert(app2.TargetDate == datetime('2025-03-15'), 'Target date should match');

        delete(app1);
        delete(app2);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Auto-saved session can be loaded';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Auto-saved session can be loaded';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 8: Timer is properly cleaned up on app delete
    testNum = testNum + 1;
    try
        fprintf('Test %d: Timer cleanup on app delete... ', testNum);
        app = createTestApp();
        app.enableAutoSave(true, 5);

        timerName = 'ConductionAutoSaveTimer';
        timers = timerfindall('Name', timerName);
        assert(~isempty(timers), 'Timer should exist');

        delete(app);

        % Check timer is gone
        timers = timerfindall('Name', timerName);
        assert(isempty(timers), 'Timer should be cleaned up after app delete');

        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Timer cleanup on app delete';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Timer cleanup on app delete';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 9: Manual auto-save callback respects dirty flag
    testNum = testNum + 1;
    try
        fprintf('Test %d: Manual callback respects dirty flag... ', testNum);
        cleanupAutoSaves();

        app = createTestApp();

        % Not dirty - should not save
        app.autoSaveCallback();
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(isempty(files), 'Should not create file when not dirty');

        % Mark dirty - should save
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();
        app.autoSaveCallback();

        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(~isempty(files), 'Should create file when dirty');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Manual callback respects dirty flag';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Manual callback respects dirty flag';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Test 10: Auto-save filename format is correct
    testNum = testNum + 1;
    try
        fprintf('Test %d: Auto-save filename format... ', testNum);
        cleanupAutoSaves();

        app = createTestApp();
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();

        app.autoSaveCallback();

        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        assert(~isempty(files), 'Auto-save file should exist');

        filename = files(1).name;
        % Should match format: autosave_YYYY-MM-DD_HHmmss.mat
        assert(startsWith(filename, 'autosave_'), 'Filename should start with "autosave_"');
        assert(endsWith(filename, '.mat'), 'Filename should end with ".mat"');
        assert(contains(filename, datestr(datetime('now'), 'yyyy-mm-dd')), ...
            'Filename should contain today''s date');

        delete(app);
        cleanupAutoSaves();
        fprintf('PASS\n');
        testResults(testNum).name = 'Auto-save filename format';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Auto-save filename format';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
        cleanupAutoSaves();
    end

    % Print summary
    fprintf('\n');
    fprintf('=================================\n');
    fprintf('Test Summary\n');
    fprintf('=================================\n');

    passCount = sum([testResults.passed]);
    totalCount = length(testResults);

    fprintf('Tests passed: %d/%d\n', passCount, totalCount);

    if passCount == totalCount
        fprintf('\n✓ All Stage 8 auto-save tests passed!\n\n');
    else
        fprintf('\n✗ Some tests failed:\n');
        for i = 1:totalCount
            if ~testResults(i).passed
                fprintf('  - %s: %s\n', testResults(i).name, testResults(i).error);
            end
        end
        fprintf('\n');
        error('Stage 8 auto-save tests failed');
    end
end

function cleanupAutoSaveDir(autoSaveDir)
    % Clean up auto-save directory and files
    if isfolder(autoSaveDir)
        files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));
        for i = 1:length(files)
            delete(fullfile(autoSaveDir, files(i).name));
        end
        rmdir(autoSaveDir);
    end
end
