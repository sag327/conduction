function admissionStatus = resolveAdmissionStatus(caseItem)
%RESOLVEADMISSIONSTATUS Extract admission status from case item
%   admissionStatus = resolveAdmissionStatus(caseItem) attempts to
%   extract admission status (inpatient/outpatient) from the caseItem.
%   Returns 'outpatient' as default if not found.

    if isstruct(caseItem)
        fields = {'admissionStatus', 'admission_status', 'AdmissionStatus'};
        for idx = 1:numel(fields)
            name = fields{idx};
            if isfield(caseItem, name)
                candidate = conduction.utils.conversion.asString(caseItem.(name));
                if strlength(candidate) > 0
                    admissionStatus = lower(candidate);
                    return;
                end
            end
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'AdmissionStatus')
            candidate = conduction.utils.conversion.asString(caseItem.AdmissionStatus);
            if strlength(candidate) > 0
                admissionStatus = lower(candidate);
                return;
            end
        end
    end
    admissionStatus = string('outpatient');  % Default to outpatient
end
