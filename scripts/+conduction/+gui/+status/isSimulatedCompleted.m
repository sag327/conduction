function tf = isSimulatedCompleted(caseObj)
%ISSIMULATEDCOMPLETED True when CaseStatus indicates completion but the
%case remains in the active list (i.e., not archived yet).
%
%   Only inspects the CaseStatus field; callers must avoid passing archived
%   cases because those are moved into CaseManager.CompletedCases.

if isempty(caseObj)
    tf = false;
    return;
end

status = "";
if isstruct(caseObj) && isfield(caseObj, 'CaseStatus')
    status = string(caseObj.CaseStatus);
elseif isprop(caseObj, 'CaseStatus')
    status = string(caseObj.CaseStatus);
end

tf = strcmpi(status, "completed");
end
