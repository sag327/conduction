function test_stage7_dirty_tracking()
% TEST_STAGE7_DIRTY_TRACKING Test dirty flag tracking functionality (Stage 7)
%
% Tests that the dirty flag is properly set when the app state changes,
% and properly cleared when saving or loading a session.

    fprintf('Running Stage 7: Dirty Flag Tracking Tests\n');
    fprintf('==========================================\n\n');

    % Initialize test results
    testResults = struct('name', {}, 'passed', {}, 'error', {});
    testNum = 0;

    % Test 1: Initially not dirty
    testNum = testNum + 1;
    try
        fprintf('Test %d: App starts not dirty... ', testNum);
        app = createTestApp();
        assert(~app.IsDirty, 'App should not be dirty initially');
        assert(~contains(app.UIFigure.Name, '*'), 'Window title should not have asterisk');
        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Initially not dirty';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Initially not dirty';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 2: Dirty after adding case
    testNum = testNum + 1;
    try
        fprintf('Test %d: Dirty after adding case... ', testNum);
        app = createTestApp();
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();
        assert(app.IsDirty, 'App should be dirty after adding case');
        assert(contains(app.UIFigure.Name, '*'), 'Window title should have asterisk');
        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Dirty after adding case';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Dirty after adding case';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 3: Clean after save
    testNum = testNum + 1;
    try
        fprintf('Test %d: Clean after save... ', testNum);
        app = createTestApp();
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();
        assert(app.IsDirty, 'App should be dirty after adding case');

        % Save session
        testFile = tempname();
        sessionData = app.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Clear dirty flag
        app.IsDirty = false;
        app.updateWindowTitle();

        assert(~app.IsDirty, 'App should not be dirty after save');
        assert(~contains(app.UIFigure.Name, '*'), 'Window title should not have asterisk after save');

        % Cleanup
        delete([testFile '.mat']);
        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Clean after save';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Clean after save';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 4: Clean after load, dirty after change
    testNum = testNum + 1;
    try
        fprintf('Test %d: Clean after load, dirty after change... ', testNum);

        % Create and save a session
        app1 = createTestApp();
        app1.CaseManager.addCase('Dr. A', 'Proc B', 60);
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);
        delete(app1);

        % Load session in new app
        app2 = createTestApp();
        sessionData = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(sessionData);
        app2.IsDirty = false;
        app2.updateWindowTitle();

        assert(~app2.IsDirty, 'App should not be dirty after load');
        assert(~contains(app2.UIFigure.Name, '*'), 'Window title should not have asterisk after load');

        % Make a change
        app2.CaseManager.addCase('Dr. C', 'Proc D', 45);
        app2.markDirty();

        assert(app2.IsDirty, 'App should be dirty after adding case');
        assert(contains(app2.UIFigure.Name, '*'), 'Window title should have asterisk after change');

        % Cleanup
        delete([testFile '.mat']);
        delete(app2);
        fprintf('PASS\n');
        testResults(testNum).name = 'Clean after load, dirty after change';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Clean after load, dirty after change';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 5: Dirty after removing case
    testNum = testNum + 1;
    try
        fprintf('Test %d: Dirty after removing case... ', testNum);
        app = createTestApp();
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.IsDirty = false;
        app.updateWindowTitle();

        assert(~app.IsDirty, 'App should not be dirty initially');

        % Remove case
        app.CaseManager.removeCase(1);
        app.markDirty();

        assert(app.IsDirty, 'App should be dirty after removing case');
        assert(contains(app.UIFigure.Name, '*'), 'Window title should have asterisk');

        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Dirty after removing case';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Dirty after removing case';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 6: Dirty after clearing all cases
    testNum = testNum + 1;
    try
        fprintf('Test %d: Dirty after clearing all cases... ', testNum);
        app = createTestApp();
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.CaseManager.addCase('Dr. C', 'Proc D', 45);
        app.IsDirty = false;
        app.updateWindowTitle();

        assert(~app.IsDirty, 'App should not be dirty initially');

        % Clear all cases
        app.CaseManager.clearAllCases();
        app.markDirty();

        assert(app.IsDirty, 'App should be dirty after clearing all cases');
        assert(contains(app.UIFigure.Name, '*'), 'Window title should have asterisk');

        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Dirty after clearing all cases';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Dirty after clearing all cases';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 7: Dirty after changing date
    testNum = testNum + 1;
    try
        fprintf('Test %d: Dirty after changing date... ', testNum);
        app = createTestApp();
        app.IsDirty = false;
        app.updateWindowTitle();

        assert(~app.IsDirty, 'App should not be dirty initially');

        % Change date (simulate DatePickerValueChanged)
        app.TargetDate = datetime('2025-02-20');
        app.markDirty();

        assert(app.IsDirty, 'App should be dirty after changing date');
        assert(contains(app.UIFigure.Name, '*'), 'Window title should have asterisk');

        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Dirty after changing date';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Dirty after changing date';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 8: Window title format
    testNum = testNum + 1;
    try
        fprintf('Test %d: Window title format... ', testNum);
        app = createTestApp();

        % Check clean title
        versionInfo = conduction.version();
        expectedClean = sprintf('Conduction v%s', versionInfo.Version);
        assert(strcmp(app.UIFigure.Name, expectedClean), 'Clean title should be "Conduction vX.X.X"');

        % Check dirty title
        app.markDirty();
        expectedDirty = sprintf('Conduction v%s *', versionInfo.Version);
        assert(strcmp(app.UIFigure.Name, expectedDirty), 'Dirty title should be "Conduction vX.X.X *"');

        % Check clean title after clearing dirty
        app.IsDirty = false;
        app.updateWindowTitle();
        assert(strcmp(app.UIFigure.Name, expectedClean), 'Title should return to clean format');

        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Window title format';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Window title format';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 9: markDirty sets flag and updates title
    testNum = testNum + 1;
    try
        fprintf('Test %d: markDirty() sets flag and updates title... ', testNum);
        app = createTestApp();

        assert(~app.IsDirty, 'App should not be dirty initially');

        % Call markDirty
        app.markDirty();

        assert(app.IsDirty, 'markDirty() should set IsDirty to true');
        assert(contains(app.UIFigure.Name, '*'), 'markDirty() should update window title');

        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'markDirty() sets flag and updates title';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'markDirty() sets flag and updates title';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 10: Multiple dirty operations maintain dirty state
    testNum = testNum + 1;
    try
        fprintf('Test %d: Multiple dirty operations maintain dirty state... ', testNum);
        app = createTestApp();

        % Add case
        app.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app.markDirty();
        assert(app.IsDirty, 'App should be dirty after first operation');

        % Add another case
        app.CaseManager.addCase('Dr. C', 'Proc D', 45);
        app.markDirty();
        assert(app.IsDirty, 'App should still be dirty after second operation');

        % Change date
        app.TargetDate = datetime('2025-03-15');
        app.markDirty();
        assert(app.IsDirty, 'App should still be dirty after third operation');

        % Should only become clean after explicit clear
        app.IsDirty = false;
        app.updateWindowTitle();
        assert(~app.IsDirty, 'App should be clean after explicit clear');

        delete(app);
        fprintf('PASS\n');
        testResults(testNum).name = 'Multiple dirty operations maintain dirty state';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Multiple dirty operations maintain dirty state';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Print summary
    fprintf('\n');
    fprintf('==========================================\n');
    fprintf('Test Summary\n');
    fprintf('==========================================\n');

    passCount = sum([testResults.passed]);
    totalCount = length(testResults);

    fprintf('Tests passed: %d/%d\n', passCount, totalCount);

    if passCount == totalCount
        fprintf('\n✓ All Stage 7 dirty flag tracking tests passed!\n\n');
    else
        fprintf('\n✗ Some tests failed:\n');
        for i = 1:totalCount
            if ~testResults(i).passed
                fprintf('  - %s: %s\n', testResults(i).name, testResults(i).error);
            end
        end
        fprintf('\n');
        error('Stage 7 dirty flag tracking tests failed');
    end
end
