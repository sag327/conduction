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
    end

    methods
        function obj = ProspectiveCase(operatorName, procedureName)
            arguments
                operatorName (1,1) string = ""
                procedureName (1,1) string = ""
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