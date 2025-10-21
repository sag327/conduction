classdef ResourceType < handle
    %RESOURCETYPE Represents a limited shared resource usable by cases.

    properties (SetAccess = private)
        Id string
    end

    properties
        Name string
        Capacity double
        Color double {mustBeFinite} = [0.5 0.5 0.5]
        Pattern string = "solid"
        Notes string = ""
        IsTracked logical = true
    end

    methods
        function obj = ResourceType(id, name, capacity, color, pattern, notes, isTracked)
            arguments
                id (1,1) string
                name (1,1) string
                capacity (1,1) double {mustBeNonnegative} = 1
                color (1,3) double {mustBeGreaterThanOrEqual(color,0), mustBeLessThanOrEqual(color,1)} = [0.5 0.5 0.5]
                pattern (1,1) string = "solid"
                notes (1,1) string = ""
                isTracked (1,1) logical = true
            end

            obj.Id = id;
            obj.Name = strtrim(name);
            obj.Capacity = capacity;
            obj.Color = color;
            obj.Pattern = pattern;
            obj.Notes = notes;
            obj.IsTracked = isTracked;
        end
    end
end
