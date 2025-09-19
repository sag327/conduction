classdef Procedure
    %PROCEDURE Encapsulates procedure template durations and identity.

    properties (SetAccess = immutable)
        Id string
        Name string
        SetupDuration double
        ProcedureDuration double
        PostDuration double
    end

    methods
        function obj = Procedure(name, setupDuration, procedureDuration, postDuration)
            arguments
                name (1,1) string
                setupDuration (1,1) double
                procedureDuration (1,1) double
                postDuration (1,1) double
            end

            obj.Name = strtrim(name);
            obj.Id = conduction.Procedure.canonicalId(obj.Name);
            obj.SetupDuration = setupDuration;
            obj.ProcedureDuration = procedureDuration;
            obj.PostDuration = postDuration;
        end

        function total = totalDuration(obj)
            total = obj.SetupDuration + obj.ProcedureDuration + obj.PostDuration;
        end
    end

    methods (Static)
        function proc = fromRow(row)
            name = string(row.procedure(1));
            if ismember('setup_minutes', row.Properties.VariableNames)
                setupDuration = conduction.Procedure.asDouble(row.setup_minutes(1));
            elseif ismember('in_room_to_procedure_start_minutes', row.Properties.VariableNames)
                setupDuration = conduction.Procedure.asDouble(row.in_room_to_procedure_start_minutes(1));
            else
                setupDuration = conduction.Procedure.asDouble(row.in_room_to_induction_minutes(1));
            end
            procedureDuration = conduction.Procedure.asDouble(row.procedure_minutes(1));
            postDuration = conduction.Procedure.asDouble(row.post_procedure_minutes(1));

            proc = conduction.Procedure(name, setupDuration, procedureDuration, postDuration);
        end

        function id = canonicalId(name)
            name = string(name);
            if strlength(name) == 0
                name = "procedure";
            end
            sanitized = matlab.lang.makeValidName(lower(char(name)));
            id = string(lower(sanitized));
        end

        function value = asDouble(rawValue)
            if ismissing(rawValue)
                value = NaN;
                return;
            end
            if iscell(rawValue)
                rawValue = rawValue{1};
            end
            if isstring(rawValue) || ischar(rawValue)
                num = str2double(rawValue);
            else
                num = double(rawValue);
            end
            if isnan(num)
                value = NaN;
            else
                value = num;
            end
        end
    end
end
