classdef ProspectiveCase < handle
    %PROSPECTIVECASE Represents a case to be scheduled in the GUI.

    properties
        OperatorName string
        OperatorId string
        ProcedureName string
        ProcedureId string
        EstimatedDurationMinutes double
        IsCustomOperator logical
        IsCustomProcedure logical
        DateCreated datetime
        Notes string
        
        % Scheduling constraints
        SpecificLab string = ""  % Required lab (empty = any lab)
        IsFirstCaseOfDay logical = false  % Must be first case of the day
        AdmissionStatus string = "outpatient"  % Outpatient or inpatient
        IsLocked logical = false  % CASE-LOCKING: Lock case in place during re-optimization

        % REALTIME-SCHEDULING: Case status and actual time tracking
        CaseStatus string = "pending"  % "pending", "in_progress", "completed"
        AssignedLab double = NaN  % Which lab the case was assigned to (after optimization)

        % Actual times (minutes from midnight) - set when case progresses/completes
        ActualStartTime double = NaN  % Actual setup start time
        ActualProcStartTime double = NaN  % Actual procedure start time
        ActualProcEndTime double = NaN  % Actual procedure end time
        ActualEndTime double = NaN  % Actual post-procedure completion time

        % Scheduled times (minutes from midnight) - set after optimization for comparison
        ScheduledStartTime double = NaN  % Scheduled setup start time
        ScheduledProcStartTime double = NaN  % Scheduled procedure start time
        ScheduledEndTime double = NaN  % Scheduled end time (including post + turnover)
    end

    methods
        function obj = ProspectiveCase(operatorName, procedureName, admissionStatus)
            arguments
                operatorName (1,1) string = ""
                procedureName (1,1) string = ""
                admissionStatus (1,1) string = "outpatient"
            end

            obj.OperatorName = operatorName;
            obj.OperatorId = conduction.Operator.canonicalId(operatorName);
            obj.ProcedureName = procedureName;
            obj.ProcedureId = conduction.gui.models.ProspectiveCase.generateProcedureId(procedureName);
            obj.EstimatedDurationMinutes = 60; % Default estimate
            obj.IsCustomOperator = false;
            obj.IsCustomProcedure = false;
            obj.DateCreated = datetime('now');
            obj.Notes = "";
            obj.AdmissionStatus = admissionStatus;
        end

        function displayName = getDisplayName(obj)
            displayName = sprintf("%s - %s (%d min)", ...
                obj.OperatorName, obj.ProcedureName, obj.EstimatedDurationMinutes);
        end

        function updateDuration(obj, newDuration)
            arguments
                obj
                newDuration (1,1) double {mustBePositive}
            end
            obj.EstimatedDurationMinutes = newDuration;
        end

        % REALTIME-SCHEDULING: Status and timing methods
        function duration = getActualDuration(obj)
            %GETACTUALDURATION Return actual procedure duration in minutes
            %   Returns NaN if actual times not yet recorded
            if ~isnan(obj.ActualProcStartTime) && ~isnan(obj.ActualProcEndTime)
                duration = obj.ActualProcEndTime - obj.ActualProcStartTime;
            else
                duration = NaN;
            end
        end

        function variance = getTimeVariance(obj)
            %GETTIMEVARIANCE Return variance from scheduled end time (+/- minutes)
            %   Positive = case finished late, Negative = case finished early
            %   Returns NaN if scheduled or actual times not available
            if ~isnan(obj.ScheduledEndTime) && ~isnan(obj.ActualEndTime)
                variance = obj.ActualEndTime - obj.ScheduledEndTime;
            else
                variance = NaN;
            end
        end

        function tf = isPending(obj)
            %ISPENDING Check if case is in pending status
            tf = strcmpi(obj.CaseStatus, "pending");
        end

        function tf = isInProgress(obj)
            %ISINPROGRESS Check if case is in progress
            tf = strcmpi(obj.CaseStatus, "in_progress");
        end

        function tf = isCompleted(obj)
            %ISCOMPLETED Check if case is completed
            tf = strcmpi(obj.CaseStatus, "completed");
        end
    end

    methods (Static)
        function id = generateProcedureId(procedureName)
            if strlength(procedureName) == 0
                id = "procedure_unknown";
                return;
            end
            sanitized = matlab.lang.makeValidName(lower(char(procedureName)));
            id = string(lower(sanitized));
        end
    end
end
