function caseObj = deserializeProspectiveCase(caseStruct)
    %DESERIALIZEPROSPECTIVECASE Convert struct to ProspectiveCase object
    %   caseObj = deserializeProspectiveCase(caseStruct)
    %
    %   Converts a struct array (from saved file) to ProspectiveCase objects.

    if isempty(caseStruct)
        caseObj = conduction.gui.models.ProspectiveCase.empty;
        return;
    end

    % Handle array of case structs
    numCases = numel(caseStruct);
    caseObj = conduction.gui.models.ProspectiveCase.empty(0, numCases);

    for i = 1:numCases
        s = caseStruct(i);

        % Create case with operator, procedure, and admission status
        admissionStatus = getFieldSafe(s, 'admissionStatus', 'outpatient');
        c = conduction.gui.models.ProspectiveCase(...
            string(s.operatorName), ...
            string(s.procedureName), ...
            string(admissionStatus));

        % Set duration
        if isfield(s, 'estimatedDurationMinutes')
            c.updateDuration(s.estimatedDurationMinutes);
        end

        % Restore IDs (may have been computed differently)
        if isfield(s, 'operatorId')
            c.OperatorId = string(s.operatorId);
        end
        if isfield(s, 'procedureId')
            c.ProcedureId = string(s.procedureId);
        end

        % Custom flags
        c.IsCustomOperator = getFieldSafe(s, 'isCustomOperator', false);
        c.IsCustomProcedure = getFieldSafe(s, 'isCustomProcedure', false);

        % Metadata
        if isfield(s, 'dateCreated')
            c.DateCreated = s.dateCreated;
        end
        if isfield(s, 'notes')
            c.Notes = string(s.notes);
        end

        % Scheduling constraints
        c.SpecificLab = string(getFieldSafe(s, 'specificLab', ''));
        c.IsFirstCaseOfDay = getFieldSafe(s, 'isFirstCaseOfDay', false);
        c.IsLocked = getFieldSafe(s, 'isLocked', false);

        % Case status
        c.CaseStatus = string(getFieldSafe(s, 'caseStatus', 'pending'));
        c.AssignedLab = getFieldSafe(s, 'assignedLab', NaN);

        % Actual times
        c.ActualStartTime = getFieldSafe(s, 'actualStartTime', NaN);
        c.ActualProcStartTime = getFieldSafe(s, 'actualProcStartTime', NaN);
        c.ActualProcEndTime = getFieldSafe(s, 'actualProcEndTime', NaN);
        c.ActualEndTime = getFieldSafe(s, 'actualEndTime', NaN);

        % Scheduled times
        c.ScheduledStartTime = getFieldSafe(s, 'scheduledStartTime', NaN);
        c.ScheduledProcStartTime = getFieldSafe(s, 'scheduledProcStartTime', NaN);
        c.ScheduledEndTime = getFieldSafe(s, 'scheduledEndTime', NaN);

        if isfield(s, 'caseId') && strlength(string(s.caseId)) > 0
            c.CaseId = string(s.caseId);
        end
        if isfield(s, 'caseNumber') && ~isnan(s.caseNumber)
            c.CaseNumber = s.caseNumber;
        end

        if isfield(s, 'requiredResourceIds') && ~isempty(s.requiredResourceIds)
            reqIds = string(s.requiredResourceIds);
            reqIds = reqIds(strlength(reqIds) > 0);
            c.RequiredResourceIds = reqIds(:);
        else
            c.RequiredResourceIds = string.empty(0, 1);
        end

        caseObj(i) = c;
    end
end

function value = getFieldSafe(s, fieldName, defaultValue)
    %GETFIELDSAFE Safely get field from struct with default
    if isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
