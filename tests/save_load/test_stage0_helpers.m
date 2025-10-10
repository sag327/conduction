%% TEST_STAGE0_HELPERS Verify Stage 0 test infrastructure
%   This script tests all helper functions created in Stage 0
%   to ensure they work correctly before proceeding to Stage 1

clear;
clc;
fprintf('=== Stage 0 Test Infrastructure Verification ===\n\n');

% Add paths
addpath(genpath('tests/save_load/helpers'));
addpath(genpath('scripts'));

%% Test 1: createTestApp()
fprintf('Test 1: createTestApp()\n');
try
    app = createTestApp();
    assert(~isempty(app), 'App should not be empty');
    assert(isa(app, 'conduction.gui.ProspectiveSchedulerApp'), 'Should be ProspectiveSchedulerApp');
    assert(~isempty(app.TargetDate), 'Should have target date');
    delete(app);
    fprintf('  ✓ createTestApp() works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 1 failed');
end

%% Test 2: createTestApp() with custom date
fprintf('Test 2: createTestApp(customDate)\n');
try
    testDate = datetime('2025-02-15');
    app = createTestApp(testDate);
    assert(app.TargetDate == testDate, 'Should use custom date');
    delete(app);
    fprintf('  ✓ createTestApp(customDate) works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 2 failed');
end

%% Test 3: createTestAppWithCases()
fprintf('Test 3: createTestAppWithCases()\n');
try
    app = createTestAppWithCases(3);
    assert(app.CaseManager.CaseCount == 3, 'Should have 3 cases');
    % Test that we can access cases via public interface
    case1 = app.CaseManager.getCase(1);
    assert(~isempty(case1), 'Should be able to get first case');
    delete(app);
    fprintf('  ✓ createTestAppWithCases() works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 3 failed');
end

%% Test 4: createTestCase()
fprintf('Test 4: createTestCase()\n');
try
    testCase = createTestCase();
    assert(~isempty(testCase), 'Case should not be empty');
    assert(isa(testCase, 'conduction.gui.models.ProspectiveCase'), 'Should be ProspectiveCase');
    assert(testCase.OperatorName == "Dr. Test", 'Should have default operator');
    assert(testCase.ProcedureName == "Test Procedure", 'Should have default procedure');
    assert(testCase.EstimatedDurationMinutes == 60, 'Should have default duration');
    fprintf('  ✓ createTestCase() works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 4 failed');
end

%% Test 5: createTestCase() with custom parameters
fprintf('Test 5: createTestCase(custom params)\n');
try
    testCase = createTestCase('Dr. Smith', 'Procedure A', 90);
    assert(testCase.OperatorName == "Dr. Smith", 'Should use custom operator');
    assert(testCase.ProcedureName == "Procedure A", 'Should use custom procedure');
    assert(testCase.EstimatedDurationMinutes == 90, 'Should use custom duration');
    fprintf('  ✓ createTestCase(custom) works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 5 failed');
end

%% Test 6: createTestSchedule()
fprintf('Test 6: createTestSchedule()\n');
try
    schedule = createTestSchedule();
    assert(~isempty(schedule), 'Schedule should not be empty');
    assert(isa(schedule, 'conduction.DailySchedule'), 'Should be DailySchedule');
    assert(~isempty(schedule.Date), 'Should have date');
    assert(numel(schedule.Labs) == 6, 'Should have 6 labs by default');
    fprintf('  ✓ createTestSchedule() works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 6 failed');
end

%% Test 7: createTestSchedule() with custom parameters
fprintf('Test 7: createTestSchedule(custom params)\n');
try
    testDate = datetime('2025-03-20');
    schedule = createTestSchedule(testDate, 4);
    assert(schedule.Date == testDate, 'Should use custom date');
    assert(numel(schedule.Labs) == 4, 'Should have 4 labs');
    fprintf('  ✓ createTestSchedule(custom) works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 7 failed');
end

%% Test 8: createTestSessionData()
fprintf('Test 8: createTestSessionData()\n');
try
    sessionData = createTestSessionData();
    assert(isstruct(sessionData), 'Should be a struct');

    % Check required fields
    requiredFields = {'version', 'targetDate', 'cases', 'labIds'};
    for i = 1:length(requiredFields)
        assert(isfield(sessionData, requiredFields{i}), ...
            sprintf('Should have field: %s', requiredFields{i}));
    end

    % Check field types
    assert(isstring(sessionData.version) || ischar(sessionData.version), 'version should be string');
    assert(isa(sessionData.targetDate, 'datetime'), 'targetDate should be datetime');
    assert(isnumeric(sessionData.labIds), 'labIds should be numeric');

    fprintf('  ✓ createTestSessionData() works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 8 failed');
end

%% Test 9: createTestSessionData() with custom date
fprintf('Test 9: createTestSessionData(custom date)\n');
try
    testDate = datetime('2025-04-10');
    sessionData = createTestSessionData(testDate);
    assert(sessionData.targetDate == testDate, 'Should use custom date');
    fprintf('  ✓ createTestSessionData(custom) works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 9 failed');
end

%% Test 10: createTestOperatorColors()
fprintf('Test 10: createTestOperatorColors()\n');
try
    colorMap = createTestOperatorColors();
    assert(~isempty(colorMap), 'Map should not be empty');
    assert(isa(colorMap, 'containers.Map'), 'Should be containers.Map');
    assert(colorMap.Count > 0, 'Should have at least one entry');

    % Test that colors are valid RGB triplets
    keys = colorMap.keys;
    for i = 1:length(keys)
        color = colorMap(keys{i});
        assert(isnumeric(color), 'Color should be numeric');
        assert(numel(color) == 3, 'Color should be RGB triplet');
        assert(all(color >= 0) && all(color <= 1), 'Color values should be in [0,1]');
    end

    fprintf('  ✓ createTestOperatorColors() works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 10 failed');
end

%% Summary
fprintf('\n=== All Stage 0 Tests Passed! ===\n');
fprintf('Test infrastructure is ready for Stage 1\n');
