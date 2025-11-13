function row = buildCaseTableRow(caseObj, resourceStore)
%BUILDCASETABLEROW Format a ProspectiveCase into table row data.
%   row = buildCaseTableRow(caseObj, resourceStore) returns a 1x9 cell array
%   matching the Cases table schema.

if nargin < 2
    resourceStore = conduction.gui.stores.ResourceStore.empty;
end

row = cell(1, 9);
statusIcon = "";

if isprop(caseObj, 'IsLocked') && caseObj.IsLocked
    statusIcon = statusIcon + "🔒";
end
if caseObj.isCompleted()
    statusIcon = statusIcon + "✓";
elseif caseObj.isInProgress()
    statusIcon = statusIcon + "▶";
end
row{1} = char(statusIcon);

row{2} = caseObj.CaseNumber;
row{3} = char(caseObj.OperatorName);
row{4} = char(caseObj.ProcedureName);
row{5} = round(caseObj.EstimatedDurationMinutes);
row{6} = char(caseObj.AdmissionStatus);

if caseObj.SpecificLab == "" || strcmpi(caseObj.SpecificLab, "Any Lab")
    row{7} = 'Any';
else
    row{7} = char(caseObj.SpecificLab);
end

resourceNames = string.empty(0, 1);
if ~isempty(resourceStore) && isa(resourceStore, 'conduction.gui.stores.ResourceStore') && isvalid(resourceStore)
    try
        resourceNames = resourceStore.namesForIds(caseObj.RequiredResourceIds);
    catch
        resourceNames = string.empty(0, 1);
    end
end
if isempty(resourceNames)
    row{8} = '--';
else
    row{8} = char(strjoin(resourceNames, ', '));
end

if caseObj.IsFirstCaseOfDay
    row{9} = 'Yes';
else
    row{9} = 'No';
end
end
