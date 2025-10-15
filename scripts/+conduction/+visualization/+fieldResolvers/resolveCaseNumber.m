function caseNumber = resolveCaseNumber(caseItem, fallbackIndex)
%RESOLVECASENUMBER Extract user-facing case number for display
%   caseNumber = resolveCaseNumber(caseItem, fallbackIndex) extracts
%   the case number from the caseItem. Returns fallbackIndex if no
%   case number is found.
%
%   DUAL-ID: This extracts the user-facing display number, not the
%   internal persistent ID.

    candidates = {'caseNumber', 'CaseNumber', 'case_number'};
    for idx = 1:numel(candidates)
        name = candidates{idx};
        if isstruct(caseItem) && isfield(caseItem, name)
            candidate = caseItem.(name);
        elseif isobject(caseItem) && isprop(caseItem, name)
            candidate = caseItem.(name);
        else
            continue;
        end
        if isnumeric(candidate) && isscalar(candidate) && ~isnan(candidate)
            caseNumber = double(candidate);
            return;
        end
    end
    % Fallback: use sequence ID if no case number found
    caseNumber = fallbackIndex;
end
