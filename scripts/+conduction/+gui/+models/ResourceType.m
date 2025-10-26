classdef ResourceType < handle
    %RESOURCETYPE Represents a limited shared resource usable by cases.

    properties (SetAccess = private)
        Id string
    end

    properties
        Name string
        Capacity double
        Color double {mustBeFinite} = [0.5 0.5 0.5]
        Notes string = ""
        IsDefault logical = false
    end

    methods
        function obj = ResourceType(id, name, capacity, color, isDefault)
            arguments
                id (1,1) string
                name (1,1) string
                capacity (1,1) double {mustBeNonnegative} = 1
                color (1,3) double {mustBeGreaterThanOrEqual(color,0), mustBeLessThanOrEqual(color,1)} = [0.5 0.5 0.5]
                isDefault (1,1) logical = false
            end

            obj.Id = id;
            obj.Name = strtrim(name);
            obj.Capacity = capacity;
            obj.Color = color;
            obj.IsDefault = isDefault;
        end
    end
end
