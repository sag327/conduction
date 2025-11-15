classdef ProspectiveCase < handle
    %PROSPECTIVECASE Represents a case to be scheduled in the GUI.

    properties
        % PERSISTENT-ID: Unique, permanent identifier for this case
        % This ID never changes, even when array position changes due to deletion
        % Format: "case_YYYYMMDD_HHMMSS_XXX" (timestamp + counter for uniqueness)
        CaseId string = ""

        % DUAL-ID: User-facing sequential case number for display
        % Simple integer (1, 2, 3...) shown in table, schedule, and drawer
        % Persistent across sessions, gaps allowed after deletion
        CaseNumber double = NaN

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
        IsLocked logical = false  % DEPRECATED: Use IsUserLocked + auto-lock computation instead

        % REALTIME-SCHEDULING: Case status and actual time tracking
        CaseStatus string = "pending"  % "pending", "in_progress", "completed"
        ManuallyCompleted logical = false  % UNIFIED-TIMELINE: Manual completion override (for marking complete without advancing NOW)
        IsUserLocked logical = false  % UNIFIED-TIMELINE: Manual user lock (persists across NOW movements)
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

        % RESOURCE-CONSTRAINTS: Required shared resources by id
        RequiredResourceIds string = string.empty(0, 1)
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

        % UNIFIED-TIMELINE: Computed status and lock methods
        function status = getComputedStatus(obj, nowMinutes)
            % Get case status derived from NOW position and schedule times
            %
            % Args:
            %   nowMinutes (double): Current NOW position in minutes
            %
            % Returns:
            %   status (string): "completed", "in_progress", or "pending"

            status = conduction.gui.utils.StatusComputer.computeStatus(...
                obj.ScheduledStartTime, obj.ScheduledEndTime, nowMinutes, obj.ManuallyCompleted);
        end

        function shouldBeLocked = shouldBeAutoLocked(obj, nowMinutes)
            % Determine if case should be auto-locked at given NOW position
            %
            % Args:
            %   nowMinutes (double): Current NOW position
            %
            % Returns:
            %   shouldBeLocked (logical): True if case is in-progress or completed

            status = obj.getComputedStatus(nowMinutes);
            shouldBeLocked = conduction.gui.utils.StatusComputer.computeAutoLock(status);
        end

        function isLocked = getComputedLock(obj, nowMinutes)
            % Get effective lock state (user lock OR auto-lock)
            %
            % Args:
            %   nowMinutes (double): Current NOW position
            %
            % Returns:
            %   isLocked (logical): True if user locked OR auto-locked

            isLocked = obj.IsUserLocked || obj.shouldBeAutoLocked(nowMinutes);
        end

        function ids = listRequiredResources(obj)
            ids = obj.RequiredResourceIds;
        end

        function assignResource(obj, resourceId)
            arguments
                obj
                resourceId (1,1) string
            end
            resourceId = string(strtrim(resourceId));
            if strlength(resourceId) == 0
                return;
            end
            if ~any(obj.RequiredResourceIds == resourceId)
                obj.RequiredResourceIds(end+1, 1) = resourceId;
            end
        end

        function removeResource(obj, resourceId)
            arguments
                obj
                resourceId (1,1) string
            end
            resourceId = string(strtrim(resourceId));
            if isempty(obj.RequiredResourceIds)
                return;
            end
            mask = obj.RequiredResourceIds ~= resourceId;
            obj.RequiredResourceIds = obj.RequiredResourceIds(mask);
        end

        function clearResources(obj)
            obj.RequiredResourceIds = string.empty(0, 1);
        end

        function tf = requiresResource(obj, resourceId)
            arguments
                obj
                resourceId (1,1) string
            end
            if isempty(obj.RequiredResourceIds)
                tf = false;
            else
                tf = any(obj.RequiredResourceIds == resourceId);
            end
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

        function caseId = generateUniqueCaseId()
            %GENERATEUNIQUECASEID Generate a unique persistent ID for a case
            %   Returns a string in format: "case_YYYYMMDD_HHMMSS_XXX"
            %   Uses current timestamp + random suffix for uniqueness

            % Use persistent variable to track counter within same MATLAB session
            persistent idCounter;
            if isempty(idCounter)
                idCounter = 0;
            end

            idCounter = idCounter + 1;

            % Format: case_20250110_143025_001
            timestamp = datetime('now');
            dateStr = char(datetime(timestamp, 'Format', 'yyyyMMdd_HHmmss'));
            counterStr = sprintf('%03d', mod(idCounter, 1000));

            caseId = sprintf("case_%s_%s", dateStr, counterStr);
        end
    end
end
