%% TEST_STAGE1_SERIALIZATION Test serialization layer roundtrips
%   This script tests all serialization functions from Stage 1

clear;
clc;
fprintf('=== Stage 1 Serialization Layer Tests ===\n\n');

% Add paths
addpath(genpath('tests/save_load/helpers'));
addpath(genpath('scripts'));

%% Test 1: ProspectiveCase serialization roundtrip
fprintf('Test 1: ProspectiveCase serialization roundtrip\n');
try
    testCase = createTestCase('Dr. Smith', 'Procedure A', 90);
    testCase.IsLocked = true;
    testCase.CaseStatus = "in_progress";
    testCase.SpecificLab = "Lab 3";

    % Serialize
    caseStruct = conduction.session.serializeProspectiveCase(testCase);

    % Deserialize
    reconstructed = conduction.session.deserializeProspectiveCase(caseStruct);

    % Verify
    assert(reconstructed.OperatorName == testCase.OperatorName, 'Operator name mismatch');
    assert(reconstructed.ProcedureName == testCase.ProcedureName, 'Procedure name mismatch');
    assert(reconstructed.EstimatedDurationMinutes == testCase.EstimatedDurationMinutes, 'Duration mismatch');
    assert(reconstructed.IsLocked == testCase.IsLocked, 'IsLocked mismatch');
    assert(reconstructed.CaseStatus == testCase.CaseStatus, 'CaseStatus mismatch');
    assert(reconstructed.SpecificLab == testCase.SpecificLab, 'SpecificLab mismatch');

    fprintf('  ✓ ProspectiveCase roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 1 failed');
end

%% Test 2: Array of ProspectiveCases serialization
fprintf('Test 2: Array of ProspectiveCases serialization\n');
try
    cases = [
        createTestCase('Dr. A', 'Proc 1', 60);
        createTestCase('Dr. B', 'Proc 2', 90);
        createTestCase('Dr. C', 'Proc 3', 120)
    ];

    % Serialize
    casesStruct = conduction.session.serializeProspectiveCase(cases);

    % Deserialize
    reconstructed = conduction.session.deserializeProspectiveCase(casesStruct);

    % Verify
    assert(numel(reconstructed) == 3, 'Should have 3 cases');
    assert(reconstructed(1).OperatorName == "Dr. A", 'First operator name mismatch');
    assert(reconstructed(2).EstimatedDurationMinutes == 90, 'Second duration mismatch');
    assert(reconstructed(3).ProcedureName == "Proc 3", 'Third procedure name mismatch');

    fprintf('  ✓ Case array roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 2 failed');
end

%% Test 3: Empty ProspectiveCase array
fprintf('Test 3: Empty ProspectiveCase array\n');
try
    emptyCases = conduction.gui.models.ProspectiveCase.empty;

    % Serialize
    casesStruct = conduction.session.serializeProspectiveCase(emptyCases);

    % Deserialize
    reconstructed = conduction.session.deserializeProspectiveCase(casesStruct);

    % Verify
    assert(isempty(reconstructed), 'Should be empty');

    fprintf('  ✓ Empty case array roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 3 failed');
end

%% Test 4: Lab serialization roundtrip
fprintf('Test 4: Lab serialization roundtrip\n');
try
    testLab = conduction.Lab('Lab 1', 'Building A');

    % Serialize
    labStruct = conduction.session.serializeLab(testLab);

    % Deserialize
    reconstructed = conduction.session.deserializeLab(labStruct);

    % Verify
    assert(reconstructed.Room == testLab.Room, 'Room mismatch');
    assert(reconstructed.Location == testLab.Location, 'Location mismatch');
    assert(reconstructed.Id == testLab.Id, 'ID mismatch');

    fprintf('  ✓ Lab roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 4 failed');
end

%% Test 5: Array of Labs serialization
fprintf('Test 5: Array of Labs serialization\n');
try
    labs = [
        conduction.Lab('Lab 1', 'Location A');
        conduction.Lab('Lab 2', 'Location B');
        conduction.Lab('Lab 3', 'Location C')
    ];

    % Serialize
    labsStruct = conduction.session.serializeLab(labs);

    % Deserialize
    reconstructed = conduction.session.deserializeLab(labsStruct);

    % Verify
    assert(numel(reconstructed) == 3, 'Should have 3 labs');
    assert(reconstructed(1).Room == "Lab 1", 'First lab room mismatch');
    assert(reconstructed(2).Location == "Location B", 'Second lab location mismatch');
    assert(reconstructed(3).Room == "Lab 3", 'Third lab room mismatch');

    fprintf('  ✓ Lab array roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 5 failed');
end

%% Test 6: OperatorColors Map serialization
fprintf('Test 6: OperatorColors Map serialization\n');
try
    colorMap = createTestOperatorColors();

    % Serialize
    colorStruct = conduction.session.serializeOperatorColors(colorMap);

    % Deserialize
    reconstructed = conduction.session.deserializeOperatorColors(colorStruct);

    % Verify
    assert(reconstructed.Count == colorMap.Count, 'Map size mismatch');
    assert(isequal(reconstructed('Dr. Smith'), colorMap('Dr. Smith')), 'Color mismatch for Dr. Smith');
    assert(isequal(reconstructed('Dr. Jones'), colorMap('Dr. Jones')), 'Color mismatch for Dr. Jones');

    fprintf('  ✓ OperatorColors roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 6 failed');
end

%% Test 7: Empty OperatorColors Map
fprintf('Test 7: Empty OperatorColors Map\n');
try
    emptyMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    % Serialize
    colorStruct = conduction.session.serializeOperatorColors(emptyMap);

    % Deserialize
    reconstructed = conduction.session.deserializeOperatorColors(colorStruct);

    % Verify
    assert(reconstructed.Count == 0, 'Should be empty');

    fprintf('  ✓ Empty map roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 7 failed');
end

%% Test 8: DailySchedule serialization roundtrip
fprintf('Test 8: DailySchedule serialization roundtrip\n');
try
    testSchedule = createTestSchedule(datetime('2025-01-15'), 3);

    % Serialize
    scheduleStruct = conduction.session.serializeDailySchedule(testSchedule);

    % Deserialize
    reconstructed = conduction.session.deserializeDailySchedule(scheduleStruct);

    % Verify
    assert(reconstructed.Date == testSchedule.Date, 'Date mismatch');
    assert(numel(reconstructed.Labs) == numel(testSchedule.Labs), 'Lab count mismatch');
    assert(reconstructed.Labs(1).Room == testSchedule.Labs(1).Room, 'Lab room mismatch');

    fprintf('  ✓ DailySchedule roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 8 failed');
end

%% Test 9: Empty DailySchedule
fprintf('Test 9: Empty DailySchedule\n');
try
    emptySchedule = conduction.DailySchedule.empty;

    % Serialize
    scheduleStruct = conduction.session.serializeDailySchedule(emptySchedule);

    % Deserialize
    reconstructed = conduction.session.deserializeDailySchedule(scheduleStruct);

    % Verify
    assert(isempty(reconstructed), 'Should be empty');

    fprintf('  ✓ Empty schedule roundtrip works\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 9 failed');
end

%% Test 10: Missing optional fields handling
fprintf('Test 10: Missing optional fields handling\n');
try
    % Create minimal case struct (missing optional fields)
    minimalStruct = struct(...
        'operatorName', 'Dr. Test', ...
        'procedureName', 'Test Proc', ...
        'estimatedDurationMinutes', 60);

    % Deserialize should use defaults
    testCase = conduction.session.deserializeProspectiveCase(minimalStruct);

    % Verify defaults
    assert(testCase.CaseStatus == "pending", 'Should default to pending status');
    assert(~testCase.IsLocked, 'Should default to not locked');
    assert(testCase.SpecificLab == "", 'Should default to empty lab');

    fprintf('  ✓ Missing fields handled with defaults\n');
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    error('Test 10 failed');
end

%% Summary
fprintf('\n=== All Stage 1 Tests Passed! ===\n');
fprintf('Serialization layer is ready for Stage 2\n');
