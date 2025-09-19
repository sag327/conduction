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
            obj.Id = eprefactor.Procedure.canonicalId(obj.Name);
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
            setupDuration = eprefactor.Procedure.asDouble(row.in_room_to_induction_minutes(1));
            procedureDuration = eprefactor.Procedure.asDouble(row.procedure_minutes(1));
            postDuration = eprefactor.Procedure.asDouble(row.post_procedure_minutes(1));

            proc = eprefactor.Procedure(name, setupDuration, procedureDuration, postDuration);
        end

        function id = canonicalId(name)
            name = string(name);
            if strlength(name) == 0
                name = "procedure";
            end
            id = matlab.lang.makeValidName(lower(name));
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
