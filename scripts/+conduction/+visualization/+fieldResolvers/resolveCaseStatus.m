function caseStatus = resolveCaseStatus(caseItem)
%RESOLVECASESTATUS Extract case status from case item
%   caseStatus = resolveCaseStatus(caseItem) extracts the case
%   execution status (pending/in_progress/completed) from the caseItem.
%   Returns 'pending' as default if not found.
%
%   REALTIME-SCHEDULING: Used to display case progress indicators.

    if isstruct(caseItem)
        fields = {'caseStatus', 'CaseStatus', 'status', 'Status'};
        for idx = 1:numel(fields)
            name = fields{idx};
            if isfield(caseItem, name)
                candidate = conduction.utils.conversion.asString(caseItem.(name));
                if strlength(candidate) > 0
                    caseStatus = lower(candidate);
                    return;
                end
            end
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'CaseStatus')
            candidate = conduction.utils.conversion.asString(caseItem.CaseStatus);
            if strlength(candidate) > 0
                caseStatus = lower(candidate);
                return;
            end
        end
    end
    caseStatus = string('pending');  % Default to pending
end
