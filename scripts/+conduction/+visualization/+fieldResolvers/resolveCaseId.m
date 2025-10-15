function caseId = resolveCaseId(caseItem, fallbackIndex)
%RESOLVECASEID Extract case ID from case item with fallback
%   caseId = resolveCaseId(caseItem, fallbackIndex) attempts to extract
%   a case ID from the caseItem struct or object. If no ID is found,
%   returns a generated ID using the fallbackIndex.

    candidates = {'caseID', 'CaseId', 'caseId', 'id', 'CaseID'};
    for idx = 1:numel(candidates)
        name = candidates{idx};
        if isstruct(caseItem) && isfield(caseItem, name)
            candidate = conduction.utils.conversion.asString(caseItem.(name));
        elseif isobject(caseItem) && isprop(caseItem, name)
            candidate = conduction.utils.conversion.asString(caseItem.(name));
        else
            continue;
        end
        if strlength(candidate) > 0
            caseId = candidate;
            return;
        end
    end
    caseId = string(sprintf('Case %d', fallbackIndex));
end
