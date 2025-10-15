function label = composeCaseLabel(caseNumber, operatorName, admissionStatus)
%COMPOSECASELABEL Create formatted case label for display
%   label = composeCaseLabel(caseNumber, operatorName, admissionStatus)
%   creates a multi-line label showing case number, admission status,
%   and operator last name.
%
%   DUAL-ID: Uses case number for display (simple integer like "1", "2")
%
%   Example output:
%       "3 (IP)\nSmith"    % Case 3, inpatient, operator Smith

    info = conduction.visualization.labels.parseOperatorName(operatorName);
    lastName = char(info.lastName);
    if isempty(lastName)
        lastName = 'Unknown';
    end

    % Format case number as simple integer string
    if isnumeric(caseNumber) && ~isnan(caseNumber)
        caseNumStr = sprintf('%d', round(caseNumber));
    else
        caseNumStr = '?';
    end

    % Add admission status suffix
    if nargin >= 3 && ~isempty(admissionStatus)
        isInpatient = strcmpi(admissionStatus, 'inpatient') || strcmpi(admissionStatus, 'ip');
        if isInpatient
            suffix = ' (IP)';
        else
            suffix = ' (OP)';
        end
        label = sprintf('%s%s\n%s', caseNumStr, suffix, lastName);
    else
        label = sprintf('%s\n%s', caseNumStr, lastName);
    end
end
