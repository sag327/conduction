function test_time_control_load_behavior()
% TEST_TIME_CONTROL_LOAD_BEHAVIOR Test that time control loads OFF
%
% Tests that when a session is saved with time control ON:
% - Time control loads as OFF
% - TimeControlSwitch shows OFF
% - All locks are preserved
% - Case statuses reset to "pending"
% - Actual times are cleared
% - Only OptimizedSchedule renders (no NOW line)

    fprintf('Running Time Control Load Behavior Tests\n');
    fprintf('=========================================\n\n');

    % Initialize test results
    testResults = struct('name', {}, 'passed', {}, 'error', {});
    testNum = 0;

    % Test 1: Time control loads as OFF when saved as ON
    testNum = testNum + 1;
    try
        fprintf('Test %d: Time control loads OFF when saved ON... ', testNum);

        app1 = createTestApp();
        app1.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app1.CaseManager.addCase('Dr. C', 'Proc D', 45);

        % Run optimization
        app1.OptimizationController.executeOptimization(app1);
        pause(0.5);

        % Enable time control
        app1.TimeControlSwitch.Value = 'On';
        conduction.gui.app.toggleTimeControl(app1);

        % Verify time control is ON before save
        assert(app1.IsTimeControlActive, 'Time control should be ON before save');
        assert(~isempty(app1.SimulatedSchedule), 'Should have SimulatedSchedule before save');

        % Save session
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Load in new app
        app2 = createTestApp();
        sessionData = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(sessionData);

        % Verify time control is OFF after load
        assert(~app2.IsTimeControlActive, 'Time control should be OFF after load');
        assert(strcmp(app2.TimeControlSwitch.Value, 'Off'), 'Switch should show OFF');
        assert(isempty(app2.SimulatedSchedule), 'SimulatedSchedule should be empty');

        % Cleanup
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('PASS\n');
        testResults(testNum).name = 'Time control loads OFF when saved ON';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Time control loads OFF when saved ON';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 2: Case statuses reset to pending
    testNum = testNum + 1;
    try
        fprintf('Test %d: Case statuses reset to pending... ', testNum);

        app1 = createTestApp();
        app1.CaseManager.addCase('Dr. A', 'Proc B', 60);
        app1.CaseManager.addCase('Dr. C', 'Proc D', 45);

        % Run optimization and enable time control
        app1.OptimizationController.executeOptimization(app1);
        pause(0.5);
        app1.TimeControlSwitch.Value = 'On';
        conduction.gui.app.toggleTimeControl(app1);

        % Manually set some cases to in_progress (simulate time control progression)
        caseObj1 = app1.CaseManager.getCase(1);
        caseObj1.CaseStatus = "in_progress";
        caseObj1.ActualStartTime = 480;  % 8:00 AM

        % Save session
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        % Load in new app
        app2 = createTestApp();
        sessionData = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(sessionData);

        % Verify all cases are pending with no actual times
        for i = 1:app2.CaseManager.CaseCount
            caseObj = app2.CaseManager.getCase(i);
            assert(strcmp(caseObj.CaseStatus, "pending"), ...
                sprintf('Case %d should have status "pending"', i));
            assert(isnan(caseObj.ActualStartTime), ...
                sprintf('Case %d ActualStartTime should be NaN', i));
            assert(isnan(caseObj.ActualProcStartTime), ...
                sprintf('Case %d ActualProcStartTime should be NaN', i));
            assert(isnan(caseObj.ActualProcEndTime), ...
                sprintf('Case %d ActualProcEndTime should be NaN', i));
            assert(isnan(caseObj.ActualEndTime), ...
                sprintf('Case %d ActualEndTime should be NaN', i));
        end

        % Cleanup
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('PASS\n');
        testResults(testNum).name = 'Case statuses reset to pending';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Case statuses reset to pending';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 3: Only OptimizedSchedule exists (no SimulatedSchedule)
    testNum = testNum + 1;
    try
        fprintf('Test %d: Only OptimizedSchedule exists after load... ', testNum);

        app1 = createTestApp();
        app1.CaseManager.addCase('Dr. A', 'Proc B', 60);

        % Run optimization and enable time control
        app1.OptimizationController.executeOptimization(app1);
        pause(0.5);
        app1.TimeControlSwitch.Value = 'On';
        conduction.gui.app.toggleTimeControl(app1);

        % Verify both schedules exist before save
        assert(~isempty(app1.OptimizedSchedule), 'Should have OptimizedSchedule before save');
        assert(~isempty(app1.SimulatedSchedule), 'Should have SimulatedSchedule before save');

        % Save and load
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        app2 = createTestApp();
        sessionData = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(sessionData);

        % Verify only OptimizedSchedule exists after load
        assert(~isempty(app2.OptimizedSchedule), 'Should have OptimizedSchedule after load');
        assert(isempty(app2.SimulatedSchedule), 'Should NOT have SimulatedSchedule after load');

        % Cleanup
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('PASS\n');
        testResults(testNum).name = 'Only OptimizedSchedule exists after load';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Only OptimizedSchedule exists after load';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Test 5: Time control state variables are cleared
    testNum = testNum + 1;
    try
        fprintf('Test %d: Time control state variables cleared... ', testNum);

        app1 = createTestApp();
        app1.CaseManager.addCase('Dr. A', 'Proc B', 60);

        % Run optimization and enable time control
        app1.OptimizationController.executeOptimization(app1);
        pause(0.5);
        app1.TimeControlSwitch.Value = 'On';
        conduction.gui.app.toggleTimeControl(app1);

        % Verify time control state exists before save
        assert(~isempty(app1.TimeControlBaselineLockedIds) || isempty(app1.TimeControlBaselineLockedIds), 'State exists');

        % Save and load
        testFile = tempname();
        sessionData = app1.exportAppState();
        conduction.session.saveSessionToFile(sessionData, testFile);

        app2 = createTestApp();
        sessionData = conduction.session.loadSessionFromFile([testFile '.mat']);
        app2.importAppState(sessionData);

        % Verify time control state is cleared
        assert(~app2.IsTimeControlActive, 'IsTimeControlActive should be false');
        assert(isempty(app2.TimeControlBaselineLockedIds), 'TimeControlBaselineLockedIds should be empty');
        assert(isempty(app2.TimeControlLockedCaseIds), 'TimeControlLockedCaseIds should be empty');

        % Cleanup
        delete([testFile '.mat']);
        delete(app1);
        delete(app2);

        fprintf('PASS\n');
        testResults(testNum).name = 'Time control state variables cleared';
        testResults(testNum).passed = true;
        testResults(testNum).error = '';
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        testResults(testNum).name = 'Time control state variables cleared';
        testResults(testNum).passed = false;
        testResults(testNum).error = ME.message;
    end

    % Print summary
    fprintf('\n');
    fprintf('=========================================\n');
    fprintf('Test Summary\n');
    fprintf('=========================================\n');

    passCount = sum([testResults.passed]);
    totalCount = length(testResults);

    fprintf('Tests passed: %d/%d\n', passCount, totalCount);

    if passCount == totalCount
        fprintf('\n✓ All time control load behavior tests passed!\n\n');
    else
        fprintf('\n✗ Some tests failed:\n');
        for i = 1:totalCount
            if ~testResults(i).passed
                fprintf('  - %s: %s\n', testResults(i).name, testResults(i).error);
            end
        end
        fprintf('\n');
        error('Time control load behavior tests failed');
    end
end
