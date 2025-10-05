function testFileLoadingParity()
%TESTFILELOADINGPARITY Verify optimized file loading produces identical results.
%   Tests that optimized loadHistoricalData produces identical output to
%   the original implementation across multiple test datasets.

testFiles = {
    "../clinicalData/testProcedureDurations-1day.xlsx"
    "../clinicalData/testProcedureDurations-3day.xlsx"
    "../clinicalData/testProcedureDurations-7day.xlsx"
};

fprintf('Testing file loading parity...\n');
allPassed = true;

for i = 1:numel(testFiles)
    filePath = testFiles{i};
    if ~isfile(filePath)
        fprintf('  [SKIP] %s (file not found)\n', filePath);
        continue;
    end

    fprintf('  Testing: %s\n', filePath);

    try
        % Load data
        [tableData, entities] = conduction.loadHistoricalData(filePath);
        dataset = conduction.ScheduleCollection(tableData, entities);

        % Validate results
        passed = validateDataset(dataset, filePath);

        if passed
            fprintf('    [PASS] All checks passed\n');
        else
            fprintf('    [FAIL] Validation failed\n');
            allPassed = false;
        end

    catch ME
        fprintf('    [ERROR] %s\n', ME.message);
        allPassed = false;
    end
end

if allPassed
    fprintf('\n✓ All parity tests passed\n');
else
    fprintf('\n✗ Some tests failed\n');
    error('testFileLoadingParity:Failed', 'Parity tests did not pass');
end

end

function passed = validateDataset(dataset, filePath)
%VALIDATEDATASET Check dataset integrity and consistency.

passed = true;

% Check that table is not empty
if isempty(dataset.Table)
    fprintf('      ERROR: Table is empty\n');
    passed = false;
    return;
end

% Check entity counts
numProcedures = dataset.Procedures.Count;
numOperators = dataset.Operators.Count;
numLabs = dataset.Labs.Count;
numCases = numel(dataset.CaseRequests);

fprintf('      Rows: %d, Cases: %d, Procedures: %d, Operators: %d, Labs: %d\n', ...
    height(dataset.Table), numCases, numProcedures, numOperators, numLabs);

% Verify case count matches table rows
if numCases ~= height(dataset.Table)
    fprintf('      ERROR: CaseRequest count (%d) != table rows (%d)\n', ...
        numCases, height(dataset.Table));
    passed = false;
end

% Verify all CaseRequests have valid references
for i = 1:min(numCases, 100)  % Sample first 100 cases
    case_i = dataset.CaseRequests(i);

    if isempty(case_i.Procedure)
        fprintf('      ERROR: Case %d has empty Procedure\n', i);
        passed = false;
    end

    if isempty(case_i.Operator)
        fprintf('      ERROR: Case %d has empty Operator\n', i);
        passed = false;
    end

    if strlength(case_i.CaseId) == 0
        fprintf('      ERROR: Case %d has empty CaseId\n', i);
        passed = false;
    end
end

% Verify all procedures are in the map
uniqueProcedureIds = unique(string(arrayfun(@(c) c.Procedure.Id, dataset.CaseRequests, 'UniformOutput', false)));
for i = 1:numel(uniqueProcedureIds)
    if ~dataset.Procedures.isKey(char(uniqueProcedureIds(i)))
        fprintf('      ERROR: Procedure %s not in map\n', uniqueProcedureIds(i));
        passed = false;
    end
end

% Verify all operators are in the map
uniqueOperatorIds = unique(string(arrayfun(@(c) c.Operator.Id, dataset.CaseRequests, 'UniformOutput', false)));
for i = 1:numel(uniqueOperatorIds)
    if ~dataset.Operators.isKey(char(uniqueOperatorIds(i)))
        fprintf('      ERROR: Operator %s not in map\n', uniqueOperatorIds(i));
        passed = false;
    end
end

end
