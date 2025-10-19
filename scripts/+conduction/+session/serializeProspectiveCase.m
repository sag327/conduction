function caseStruct = serializeProspectiveCase(caseObj)
    %SERIALIZEPROSPECTIVECASE Convert ProspectiveCase object to struct
    %   caseStruct = serializeProspectiveCase(caseObj)
    %
    %   Converts a ProspectiveCase object (or array) to a struct array
    %   suitable for saving to file.

    if isempty(caseObj)
        caseStruct = struct([]);
        return;
    end

    % Handle array of cases
    numCases = numel(caseObj);
    caseStruct = struct([]);

    for i = 1:numCases
        c = caseObj(i);

        caseStruct(i).operatorName = char(c.OperatorName);
        caseStruct(i).operatorId = char(c.OperatorId);
        caseStruct(i).procedureName = char(c.ProcedureName);
        caseStruct(i).procedureId = char(c.ProcedureId);
        caseStruct(i).estimatedDurationMinutes = c.EstimatedDurationMinutes;
        caseStruct(i).isCustomOperator = c.IsCustomOperator;
        caseStruct(i).isCustomProcedure = c.IsCustomProcedure;
        caseStruct(i).dateCreated = c.DateCreated;
        caseStruct(i).notes = char(c.Notes);

        % Scheduling constraints
        caseStruct(i).specificLab = char(c.SpecificLab);
        caseStruct(i).isFirstCaseOfDay = c.IsFirstCaseOfDay;
        caseStruct(i).admissionStatus = char(c.AdmissionStatus);
        caseStruct(i).isLocked = c.IsLocked;

        % Case status
        caseStruct(i).caseStatus = char(c.CaseStatus);
        caseStruct(i).assignedLab = c.AssignedLab;

        % Actual times
        caseStruct(i).actualStartTime = c.ActualStartTime;
        caseStruct(i).actualProcStartTime = c.ActualProcStartTime;
        caseStruct(i).actualProcEndTime = c.ActualProcEndTime;
        caseStruct(i).actualEndTime = c.ActualEndTime;

        % Scheduled times
        caseStruct(i).scheduledStartTime = c.ScheduledStartTime;
        caseStruct(i).scheduledProcStartTime = c.ScheduledProcStartTime;
        caseStruct(i).scheduledEndTime = c.ScheduledEndTime;

        if strlength(c.CaseId) > 0
            caseStruct(i).caseId = char(c.CaseId);
        end
        if ~isnan(c.CaseNumber)
            caseStruct(i).caseNumber = c.CaseNumber;
        end

        caseStruct(i).requiredResourceIds = cellstr(c.RequiredResourceIds);
    end
end
