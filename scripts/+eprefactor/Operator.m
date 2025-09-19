classdef Operator
    %OPERATOR Represents a surgeon/operator participating in EP lab schedules.

    properties (SetAccess = immutable)
        Id string
        Name string
    end

    methods
        function obj = Operator(name)
            arguments
                name (1,1) string
            end

            obj.Name = strtrim(name);
            obj.Id = eprefactor.Operator.canonicalId(obj.Name);
        end
    end

    methods (Static)
        function id = canonicalId(name)
            name = string(name);
            if strlength(name) == 0
                id = "operator_unknown";
                return;
            end
            id = matlab.lang.makeValidName(lower(name));
        end
    end
end
