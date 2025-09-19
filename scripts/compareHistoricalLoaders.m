function compareHistoricalLoaders(varargin)
%COMPAREHISTORICALLOADERS Compare refactored loader output to legacy script.
%   compareHistoricalLoaders('FilePath', path) loads the specified Excel
%   workbook using both the new eprefactor loader and the legacy
%   loadHistoricalDataFromFile.m script (located in ../epScheduling/scripts).
%   The script prints summary differences and raises an error if key metrics
%   diverge.

p = inputParser;
addParameter(p, 'FilePath', 'clinicalData/testProcedureDurations-7day.xlsx', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

filePath = string(p.Results.FilePath);

% Add both project paths
legacyPath = fullfile('..', 'epScheduling', 'scripts');
if ~any(strcmp(path, legacyPath))
    addpath(legacyPath);
end
if ~any(strcmp(path, 'scripts'))
    addpath('scripts');
end

[newTableRaw, newEntities] = conduction.loadHistoricalData(filePath);
[legacyData, legacySchedules] = loadHistoricalDataFromFile(filePath); %#ok<ASGLU>
legacyTable = struct2table(legacyData);

newTable = filterMissingStartTimes(newTableRaw);


fprintf('--- Comparing loaders for %s ---%s', filePath, newline);

compareRowCounts(newTable, legacyTable);
compareColumnNames(newTable, legacyTable);
compareProcedures(newEntities, legacyTable);
compareOperators(newEntities, legacyTable);
compareDurations(newTable, legacyTable);
compareSetupTimes(newTable, legacyTable);

fprintf('Parity comparison complete.%s', newline);
end

function filtered = filterMissingStartTimes(tableData)
if ismember("Procedure Start Date and Time", tableData.Properties.VariableNames)
    mask = ~ismissing(tableData.("Procedure Start Date and Time"));
    filtered = tableData(mask, :);
else
    filtered = tableData;
end
end

function compareRowCounts(newTable, legacyTable)
if height(newTable) ~= height(legacyTable)
    error('Row count mismatch: new=%d legacy=%d', height(newTable), height(legacyTable));
end
fprintf('Row count: %d (match)%s', height(newTable), newline);
end

function compareColumnNames(newTable, legacyTable)
newCols = string(newTable.Properties.VariableNames);
legacyCols = string(legacyTable.Properties.VariableNames);
missingInNew = setdiff(legacyCols, newCols);
missingInLegacy = setdiff(newCols, legacyCols);

if ~isempty(missingInNew)
    warning('Columns missing in new loader: %s', strjoin(missingInNew, ', '));
end
if ~isempty(missingInLegacy)
    warning('Columns missing in legacy loader: %s', strjoin(missingInLegacy, ', '));
end
fprintf('Shared columns: %d%s', numel(intersect(newCols, legacyCols)), newline);
end

function compareProcedures(newEntities, legacyTable)
procedureValues = values(newEntities.procedures);
newProcedures = sort(string(cellfun(@(p) p.Name, procedureValues, 'UniformOutput', false)));
legacyProcedures = sort(unique(string(legacyTable.procedure)));
legacyProcedures = arrayfun(@conduction.Procedure.canonicalId, legacyProcedures);
newProcedures = arrayfun(@conduction.Procedure.canonicalId, newProcedures);
legacyProcedures = sort(legacyProcedures);
newProcedures = sort(newProcedures);

if ~isequal(newProcedures, legacyProcedures)
    warning('Procedure sets differ between loaders.');
else
    fprintf('Procedure count: %d (match)%s', numel(newProcedures), newline);
end
end

function compareOperators(newEntities, legacyTable)
operatorValues = values(newEntities.operators);
newOperators = sort(string(cellfun(@(o) o.Name, operatorValues, 'UniformOutput', false)));
legacyOperators = sort(unique(string(legacyTable.surgeon)));
legacyOperators = arrayfun(@conduction.Operator.canonicalId, legacyOperators);
newOperators = arrayfun(@conduction.Operator.canonicalId, newOperators);
legacyOperators = sort(legacyOperators);
newOperators = sort(newOperators);

if ~isequal(newOperators, legacyOperators)
    warning('Operator sets differ between loaders.');
else
    fprintf('Operator count: %d (match)%s', numel(newOperators), newline);
end
end

function compareDurations(newTable, legacyTable)
if ~ismember('procedure_minutes', newTable.Properties.VariableNames)
    warning('New table missing procedure_minutes column for duration comparison.');
    return;
end

if ~ismember('procedureTime', legacyTable.Properties.VariableNames)
    warning('Legacy table missing procedureTime column for duration comparison.');
    return;
end

diffTable = abs(newTable.procedure_minutes - legacyTable.procedureTime);
if any(diffTable > 1e-6, 'all')
    warning('Procedure duration differences detected.');
else
    fprintf('Procedure durations match.%s', newline);
end
end

function compareSetupTimes(newTable, legacyTable)
if ~ismember('setup_minutes', newTable.Properties.VariableNames)
    warning('New table missing setup_minutes column for setup comparison.');
    return;
end

if ~ismember('setupTime', legacyTable.Properties.VariableNames)
    warning('Legacy table missing setupTime column for setup comparison.');
    return;
end

diffTable = abs(newTable.setup_minutes - legacyTable.setupTime);
if any(diffTable > 1e-6, 'all')
    warning('Setup duration differences detected.');
else
    fprintf('Setup durations match.%s', newline);
end
end
