function [historicalTable, historicalEntities] = loadHistoricalData(filePath)
%LOADHISTORICALDATA Normalize EP lab procedure data from Excel exports.
%   historicalTable = LOADHISTORICALDATA(filePath) reads the Excel workbook
%   produced for the EP scheduling project, normalizes column names, cleans
%   case identifiers, and removes empty rows. This refactors the first phase
%   of loadHistoricalDataFromFile.m into composable helper functions.
%
%   Example:
%       [tableData, entities] = loadHistoricalData('clinicalData/testProcedureDurations-7day.xlsx');
%
%   See also: readRawHistoricalTable, normaliseHistoricalTable.

arguments
    filePath (1,1) string = "clinicalData/testProcedureDurations-7day.xlsx"
end

rawTable = readRawHistoricalTable(filePath);
historicalTable = normaliseHistoricalTable(rawTable);

if nargout > 1
    historicalEntities = buildHistoricalEntities(historicalTable);
end
end

function tbl = readRawHistoricalTable(filePath)
%READRAWHISTORICALTABLE Read the Excel file using the documented header row.

if ~isfile(filePath)
    error('loadHistoricalData:FileNotFound', ...
        'Historical data file not found: %s', filePath);
end

opts = detectImportOptions(filePath, 'NumHeaderLines', 9);
opts.VariableNamingRule = 'preserve';
tbl = readtable(filePath, opts);
end

function normalised = normaliseHistoricalTable(rawTable)
%NORMALISEHISTORICALTABLE Rename columns and clean critical fields.

canonicalMap = getCanonicalColumnMap();
columnNames = rawTable.Properties.VariableNames;
renames = containers.Map('KeyType', 'char', 'ValueType', 'char');

for idx = 1:numel(canonicalMap)
    canonical = canonicalMap(idx).canonical;
    aliases = canonicalMap(idx).aliases;
    match = findMatchingColumn(columnNames, aliases);
    if isempty(match)
        error('loadHistoricalData:MissingColumn', ...
            'Missing expected column for "%s". Checked aliases: %s', ...
            canonical, strjoin(aliases, ', '));
    end
    renames(match) = canonical;
end

normalised = rawTable;
renameKeys = renames.keys;
for i = 1:numel(renameKeys)
    normalised.Properties.VariableNames{strcmp(columnNames, renameKeys{i})} = renames(renameKeys{i});
end

normalised.case_id = cleanCaseIds(normalised.case_id);

keyColumns = {'case_id', 'date', 'procedure'};
normalised = dropEmptyRows(normalised, keyColumns);
end

function mapping = getCanonicalColumnMap()
%GETCANONICALCOLUMNMAP Canonical columns and their acceptable aliases.

mapping = struct('canonical', {}, 'aliases', {});
index = 1;
addCanonical('case_id', {'Case_ID', 'CaseID', 'Case ID', 'CaseId'});
addCanonical('date', {'Date', 'CaseDate', 'Case Date'});
addCanonical('surgeon', {'Primary_Surgeon', 'PrimarySurgeon', 'Primary Surgeon'});
addCanonical('procedure', {'Procedure_Primary', 'Procedure (Primary)', 'ProcedurePrimary'});
addCanonical('service', {'Service'});
addCanonical('location', {'Case_Location', 'Case Location'});
addCanonical('room', {'Room'});
addCanonical('admission_status', {'Admission_Patient_Class', 'AdmissionPatientClass', 'Admission Patient Class', 'Admission Status'});
addCanonical('in_room_to_induction_minutes', {'In Room to Anesthesia Induction (Minutes)', 'In Room to Induction (Minutes)'});
addCanonical('procedure_minutes', {'Procedure Start to Procedure Complete (Minutes)', 'Procedure Duration (Minutes)'});
addCanonical('post_procedure_minutes', {'Procedure Complete to Out of Room (Minutes)', 'Procedure Complete to Exit (Minutes)'});

    function addCanonical(name, aliases)
        mapping(index).canonical = name; %#ok<AGROW>
        mapping(index).aliases = aliases;
        index = index + 1;
    end
end

function match = findMatchingColumn(columns, aliases)
%FINDMATCHINGCOLUMN Find the first column that matches one of the aliases.

lowerColumns = lower(string(columns));
match = '';

for alias = string(aliases)
    exactIdx = find(lowerColumns == lower(alias), 1);
    if ~isempty(exactIdx)
        match = columns{exactIdx};
        return;
    end
end

for alias = string(aliases)
    partialIdx = find(contains(lowerColumns, lower(alias)), 1);
    if ~isempty(partialIdx)
        match = columns{partialIdx};
        return;
    end
end
end

function tbl = dropEmptyRows(tbl, keyColumns)
%DROPEMPTYROWS Remove rows where all key columns are missing.

mask = false(height(tbl), 1);
for idx = 1:numel(keyColumns)
    colName = keyColumns{idx};
    if ismember(colName, tbl.Properties.VariableNames)
        mask = mask | ~ismissing(tbl.(colName));
    end
end

tbl = tbl(mask, :);
end

function values = cleanCaseIds(values)
%CLEANCASEIDS Ensure case identifiers are printable strings.

values = string(values);
for idx = 1:numel(values)
    value = strtrim(values(idx));
    if strlength(value) == 0 || value == "<missing>"
        value = "";
    end
    value = regexprep(value, '[^\x20-\x7E]', '');
    if strlength(value) == 0
        value = "Case_" + string(idx);
    end
    values(idx) = value;
end
values = values(:);
end

function entities = buildHistoricalEntities(dataTable)
%BUILDHISTORICALENTITIES Construct typed domain objects from historical data table.

procedures = buildProcedures(dataTable);
operators = buildOperators(dataTable);
labs = buildLabs(dataTable);
caseRequests = buildCaseRequests(dataTable, procedures, operators, labs);

entities = struct();
entities.procedures = procedures;
entities.operators = operators;
entities.labs = labs;
entities.caseRequests = caseRequests;
end

function procedures = buildProcedures(dataTable)
procedureNames = unique(string(dataTable.procedure));
procedureNames = procedureNames(~ismissing(procedureNames));
procedures = containers.Map('KeyType', 'char', 'ValueType', 'any');

for name = procedureNames(:)'
    mask = string(dataTable.procedure) == name;
    idx = find(mask, 1, 'first');
    if isempty(idx)
        continue;
    end
    row = dataTable(idx, :);
    proc = eprefactor.Procedure.fromRow(row);
    procedures(char(proc.Id)) = proc;
end
end

function operators = buildOperators(dataTable)
operatorNames = unique(string(dataTable.surgeon));
operatorNames = operatorNames(~ismissing(operatorNames));
operators = containers.Map('KeyType', 'char', 'ValueType', 'any');

for name = operatorNames(:)'
    operator = eprefactor.Operator(name);
    operators(char(operator.Id)) = operator;
end

if ~operators.isKey('operator_unknown')
    operators('operator_unknown') = eprefactor.Operator("Unknown Operator");
end
end

function labs = buildLabs(dataTable)
roomNames = unique(string(dataTable.room));
labs = containers.Map('KeyType', 'char', 'ValueType', 'any');

for room = roomNames(:)'
    if ismissing(room) || strlength(room) == 0
        continue;
    end
    mask = string(dataTable.room) == room;
    idx = find(mask, 1, 'first');
    location = "";
    if ~isempty(idx) && ismember('location', dataTable.Properties.VariableNames)
        location = string(dataTable.location(idx));
    end
    lab = eprefactor.Lab(room, location);
    labs(char(lab.Id)) = lab;
end
end

function caseRequests = buildCaseRequests(dataTable, procedures, operators, labs)
caseCells = cell(height(dataTable), 1);

procedureNames = string(dataTable.procedure);
surgeonNames = string(dataTable.surgeon);
roomNames = string(dataTable.room);

for idx = 1:height(dataTable)
    row = dataTable(idx, :);

    procedureId = char(eprefactor.Procedure.canonicalId(procedureNames(idx)));
    if ~procedures.isKey(procedureId)
        proc = eprefactor.Procedure.fromRow(row);
        procedures(procedureId) = proc;
    end
    procedure = procedures(procedureId);

    operatorId = char(eprefactor.Operator.canonicalId(surgeonNames(idx)));
    if ~operators.isKey(operatorId)
        operators(operatorId) = eprefactor.Operator(surgeonNames(idx));
    end
    operator = operators(operatorId);

    lab = eprefactor.Lab.empty;
    if ~ismissing(roomNames(idx)) && strlength(roomNames(idx)) > 0
        labId = char(eprefactor.Lab.canonicalId(roomNames(idx)));
        if ~labs.isKey(labId)
            location = "";
            if ismember('location', dataTable.Properties.VariableNames)
                location = string(dataTable.location(idx));
            end
            labs(labId) = eprefactor.Lab(roomNames(idx), location);
        end
        lab = labs(labId);
    end

    caseCells{idx, 1} = eprefactor.CaseRequest(row, procedure, operator, lab);
end

if isempty(caseCells)
    caseRequests = eprefactor.CaseRequest.empty;
else
    caseRequests = vertcat(caseCells{:});
end
end
