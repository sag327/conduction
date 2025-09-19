classdef Lab
    %LAB Represents a physical EP lab room and associated metadata.

    properties (SetAccess = immutable)
        Id string
        Room string
        Location string
    end

    methods
        function obj = Lab(room, location)
            arguments
                room (1,1) string
                location (1,1) string
            end

            obj.Room = strtrim(room);
            obj.Location = strtrim(location);
            obj.Id = conduction.Lab.canonicalId(obj.Room);
        end
    end

    methods (Static)
        function id = canonicalId(name)
            name = string(name);
            if strlength(name) == 0
                id = "lab_unknown";
                return;
            end
            sanitized = matlab.lang.makeValidName(lower(char(name)));
            id = string(lower(sanitized));
        end
    end
end
